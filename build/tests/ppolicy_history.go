package tests

import (
	"context"
	_ "embed"
	"fmt"
	"strings"

	"dagger.io/dagger"
)

// PasswordPolicyHistory checks history privacy, replication and custom ACLs.
func PasswordPolicyHistory(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}
	base := merge(passwords, env{
		"OPENLDAP_BOOTSTRAP_DATA_READONLY":                 "true",
		"OPENLDAP_BOOTSTRAP_DATA_READONLY_PASSWORD_HASHED": passwords["OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED"],
	})

	for _, feature := range []string{"OPENLDAP_BOOTSTRAP_PPOLICY", "OPENLDAP_BOOTSTRAP_DATA_READONLY"} {
		settings := merge(base, env{"OPENLDAP_BOOTSTRAP_PPOLICY": "true"}, env{feature: "false"})
		disabled, err := expect(ctx, withEnv(image, settings), true,
			[]string{"config file testing succeeded"}, "container", "--skip-process")
		if err != nil {
			return fmt.Errorf("history ACL without %s: %w", feature, err)
		}
		config, err := disabled.container.WithExec([]string{"container", "run", "--", "slapcat", "-n", "0"}).Stdout(ctx)
		if err != nil {
			return err
		}
		if strings.Contains(config, "attrs=pwdHistory") {
			return fmt.Errorf("password history ACL must not be added when %s is disabled", feature)
		}
	}

	for _, mode := range []string{"standalone", "replicated", "custom", "replacement"} {
		if err := func() error {
			nodes := []string{"history-ldap1"}
			settings := merge(base, env{"OPENLDAP_BOOTSTRAP_PPOLICY": "true"})
			nodeImage := image
			if mode == "custom" {
				nodeImage = image.WithNewFile("/container/services/openldap-bootstrap/assets/ldif/config/custom/68-history-reader-acl.ldif.template", `olcAccess: to attrs=pwdHistory
  by dn.exact="uid=history-observer,${OPENLDAP_BOOTSTRAP_SUFFIX}" read
  by * break
`)
			} else if mode == "replacement" {
				nodeImage = image.WithNewFile("/container/services/openldap-bootstrap/assets/ldif/config/custom/64-password-history-acl.ldif", "")
			}
			if mode == "replicated" {
				nodes = append(nodes, "history-ldap2")
				hosts := make([]string, 0, len(nodes))
				for _, node := range nodes {
					hosts = append(hosts, "ldap://"+node+":3890")
				}
				settings = merge(settings, env{
					"OPENLDAP_BOOTSTRAP_REPLICATION":                        "true",
					"OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS":                  strings.Join(hosts, " "),
					"OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD": password,
				})
			}
			services := make([]*dagger.Service, 0, len(nodes))
			defer func() { stopNodes(ctx, services) }()
			for _, node := range nodes {
				urls := env{"OPENLDAP_URLS": "ldap://" + node + ":3890 ldapi:///"}
				service, err := startNode(ctx, nodeImage, node, merge(settings, urls), nil, nil)
				if err != nil {
					return err
				}
				services = append(services, service)
			}
			return check(ctx, image, nil, env{
				"TEST_NODES":                   strings.Join(nodes, " "),
				"TEST_HISTORY_REPLICATION":     fmt.Sprint(mode == "replicated"),
				"TEST_HISTORY_CUSTOM":          fmt.Sprint(mode == "custom"),
				"TEST_HISTORY_READONLY_ACCESS": fmt.Sprint(mode == "replacement"),
			}, ppolicyHistoryCheck)
		}(); err != nil {
			return fmt.Errorf("password history %s: %w", mode, err)
		}
	}
	return nil
}

//go:embed testdata/ppolicy-history.sh
var ppolicyHistoryCheck string
