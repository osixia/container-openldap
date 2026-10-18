package tests

import (
	"context"
	_ "embed"
	"fmt"
	"strings"

	"dagger.io/dagger"
)

// replicationPassword contains characters that must be quoted or escaped in olcSyncRepl,
// double quotes are rejected.
const replicationPassword = `Repl passw0rd 'single' \ $HOME`

const defaultSchemas = "core.ldif cosine.ldif inetorgperson.ldif rfc2307bis.ldif"

// allSchemas can be loaded together. Excluded:
//   - nis.ldif and virtualMail.ldif conflict with rfc2307bis.ldif and postfix-book.ldif,
//     they are tested by AlternativeSchemas;
//   - msuser.ldif conflicts with inetorgperson.ldif and contains duplicated attribute types
//     (OpenLDAP ships it "for informational purposes only").
var allSchemas = []string{
	"core.ldif", "cosine.ldif", "inetorgperson.ldif", "rfc2307bis.ldif",
	// OpenLDAP
	"collective.ldif", "corba.ldif", "dsee.ldif", "duaconf.ldif", "dyngroup.ldif", "java.ldif",
	"misc.ldif", "namedobject.ldif", "openldap.ldif", "pmi.ldif",
	// osixia/openldap
	"eduperson.ldif", "kerberos.ldif", "openssh-lpk.ldif", "postfix-book.ldif", "samba.ldif",
	"sudo.ldif", "totp.ldif",
}

// allModules can be loaded together. Excluded: dyngroup.so conflicts with dynlist.so and
// mqtt.so conflicts with lastbind.so.
var allModules = []string{
	"back_mdb.so", "argon2.so", "ppolicy.so", "unique.so", "refint.so", "memberof.so", "syncprov.so",
	"accesslog.so", "auditlog.so", "autoca.so", "back_asyncmeta.so", "back_dnssrv.so", "back_ldap.so",
	"back_meta.so", "back_null.so", "back_passwd.so", "back_relay.so", "back_sock.so", "back_sql.so",
	"collect.so", "constraint.so", "dds.so", "deref.so", "dynlist.so", "homedir.so", "lastbind.so",
	"lloadd.so", "nestgroup.so", "otp.so", "pcache.so", "pw-pbkdf2.so", "pw-sha2.so", "remoteauth.so",
	"retcode.so", "rwm.so", "seqmod.so", "sssvlv.so", "translucent.so", "valsort.so",
}

// rootPasswords sets the config and database root passwords to the test password.
func rootPasswords(ctx context.Context, image *dagger.Container) (env, error) {

	hash, err := hashPassword(ctx, image)
	if err != nil {
		return nil, err
	}

	return env{
		"OPENLDAP_BOOTSTRAP_CONFIG_ROOT_PASSWORD_HASHED": hash,
		"OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED":   hash,
	}, nil
}

// Default starts the image with its default configuration.
func Default(ctx context.Context, client *dagger.Client, image *dagger.Container) error {

	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}

	const node = "ldap"

	service, err := startNode(ctx, image, node, passwords, nil, nil)
	if err != nil {
		return err
	}
	defer stopNodes(ctx, []*dagger.Service{service})

	return check(ctx, image, nil, env{"TEST_NODES": node, "TEST_SCHEMAS": defaultSchemas}, defaultCheck)
}

// AlternativeSchemas bootstraps with the schemas that conflict with the default ones.
func AlternativeSchemas(ctx context.Context, client *dagger.Client, image *dagger.Container) error {

	schemas := "core.ldif cosine.ldif inetorgperson.ldif nis.ldif virtualMail.ldif"

	r, err := expect(ctx, withEnv(image, env{"OPENLDAP_BOOTSTRAP_SCHEMAS": schemas}), true,
		[]string{"config file testing succeeded"}, "container", "--skip-process")
	if err != nil {
		return err
	}

	_, err = expect(ctx, r.container, true, []string{"cn: {3}nis", "cn: {4}virtualMail"},
		"container", "run", "--", "slapcat", "-n", "0", "-a", "(objectClass=olcSchemaConfig)")
	return err
}

// AllFeatures enables every bootstrap feature, all compatible modules and schemas, on a
// 3 nodes multi-provider cluster with TLS required.
func AllFeatures(ctx context.Context, client *dagger.Client, image *dagger.Container) error {

	hash, err := hashPassword(ctx, image)
	if err != nil {
		return err
	}

	nodes := []string{"ldap1", "ldap2", "ldap3"}
	certs := certificates(client, nodes)

	hosts := make([]string, 0, len(nodes))
	for _, n := range nodes {
		hosts = append(hosts, fmt.Sprintf("ldap://%s:3890", n))
	}

	features := env{
		"OPENLDAP_BOOTSTRAP_MODULES": strings.Join(allModules, " "),
		"OPENLDAP_BOOTSTRAP_SCHEMAS": strings.Join(allSchemas, " "),

		"OPENLDAP_BOOTSTRAP_CONFIG_ROOT_PASSWORD_HASHED": hash,
		"OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED":   hash,

		"OPENLDAP_BOOTSTRAP_DATA_READONLY":                 "true",
		"OPENLDAP_BOOTSTRAP_DATA_READONLY_PASSWORD_HASHED": hash,

		"OPENLDAP_BOOTSTRAP_MONITOR_ENABLED":                  "true",
		"OPENLDAP_BOOTSTRAP_MONITOR_READONLY":                 "true",
		"OPENLDAP_BOOTSTRAP_MONITOR_READONLY_PASSWORD_HASHED": hash,

		"OPENLDAP_BOOTSTRAP_TLS":          "true",
		"OPENLDAP_BOOTSTRAP_TLS_REQUIRED": "true",

		"OPENLDAP_BOOTSTRAP_AUDITLOG_ENABLED": "true",
		"OPENLDAP_BOOTSTRAP_REFINT":           "true",
		"OPENLDAP_BOOTSTRAP_PPOLICY":          "true",
		"OPENLDAP_BOOTSTRAP_UNIQUE":           "true",
		"OPENLDAP_BOOTSTRAP_MEMBEROF":         "true",

		"OPENLDAP_BOOTSTRAP_REPLICATION":                        "true",
		"OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS":                  strings.Join(hosts, " "),
		"OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD": replicationPassword,
	}

	if _, err := expect(ctx, withEnv(image, merge(features, env{"OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD": `pass"word`})), false,
		[]string{"must not contain double quotes"}, "container", "--skip-process"); err != nil {
		return fmt.Errorf("replication password with double quotes: %w", err)
	}

	services := make([]*dagger.Service, 0, len(nodes))
	defer func() { stopNodes(ctx, services) }()

	for _, n := range nodes {
		urls := env{"OPENLDAP_URLS": fmt.Sprintf("ldap://%s:3890 ldaps://%s:6360 ldapi:///", n, n)}

		service, err := startNode(ctx, image, n, merge(features, urls), certs, nil)
		if err != nil {
			return err
		}
		services = append(services, service)
	}

	return check(ctx, image, certs, env{
		"TEST_NODES":   strings.Join(nodes, " "),
		"TEST_MODULES": strings.Join(allModules, " "),
		"TEST_SCHEMAS": strings.Join(allSchemas, " "),

		"TEST_REPLICATION_PASSWORD": replicationPassword,
	}, fullCheck)
}

//go:embed testdata/default.sh
var defaultCheck string

//go:embed testdata/full.sh
var fullCheck string
