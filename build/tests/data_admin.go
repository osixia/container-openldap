package tests

import (
	"context"
	_ "embed"
	"fmt"
	"strings"

	"dagger.io/dagger"
)

// DataAdmin checks the scoped directory administrator and coexistence with other accounts.
func DataAdmin(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}
	base := merge(passwords, env{
		"OPENLDAP_BOOTSTRAP_DATA_TREE":                       "true",
		"OPENLDAP_BOOTSTRAP_DATA_ADMIN":                      "true",
		"OPENLDAP_BOOTSTRAP_DATA_ADMIN_PASSWORD_HASHED":      passwords["OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED"],
		"OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT":                 "true",
		"OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_PASSWORD_HASHED": passwords["OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED"],
	})
	for _, mode := range []string{"disabled", "plain", "policy", "custom", "supplied"} {
		if err := func() error {
			usersDN := "ou=users," + suffix
			groupsDN := "ou=groups," + suffix
			servicesDN := "ou=services," + suffix
			settings := merge(base)
			nodeImage := image
			switch mode {
			case "disabled":
				settings["OPENLDAP_BOOTSTRAP_DATA_ADMIN"] = "false"
			case "policy":
				settings = merge(settings, env{
					"OPENLDAP_BOOTSTRAP_PPOLICY":                       "true",
					"OPENLDAP_BOOTSTRAP_DATA_READONLY":                 "true",
					"OPENLDAP_BOOTSTRAP_DATA_READONLY_PASSWORD_HASHED": passwords["OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED"],
				})
			case "custom":
				usersDN = "ou=people," + suffix
				groupsDN = "ou=roles," + suffix
				servicesDN = "ou=applications," + suffix
			case "supplied":
				settings["OPENLDAP_BOOTSTRAP_DATA_TREE"] = "false"
				nodeImage = image.WithNewFile("/container/services/openldap-bootstrap/assets/ldif/data/custom/30-custom-tree.ldif", fmt.Sprintf(`dn: %s
objectClass: organizationalUnit
ou: users

dn: %s
objectClass: organizationalUnit
ou: groups

dn: %s
objectClass: organizationalUnit
ou: services
`, usersDN, groupsDN, servicesDN))
			}
			adminDN := "cn=admin," + servicesDN
			if mode == "custom" {
				adminDN = "cn=directory-admin," + servicesDN
			}
			managementDN := "cn=management," + servicesDN
			settings = merge(settings, env{
				"OPENLDAP_BOOTSTRAP_DATA_TREE_USERS_DN":    usersDN,
				"OPENLDAP_BOOTSTRAP_DATA_TREE_GROUPS_DN":   groupsDN,
				"OPENLDAP_BOOTSTRAP_DATA_TREE_SERVICES_DN": servicesDN,
				"OPENLDAP_BOOTSTRAP_DATA_ADMIN_DN":         adminDN,
				"OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_DN":    managementDN,
			})
			node := "directory-admin-" + mode
			service, err := startNode(ctx, nodeImage, node, settings, nil, nil)
			if err != nil {
				return err
			}
			defer stopNodes(ctx, []*dagger.Service{service})
			return check(ctx, image, nil, env{
				"TEST_NODES":              node,
				"TEST_ADMIN_MODE":         mode,
				"TEST_USERS_DN":           usersDN,
				"TEST_GROUPS_DN":          groupsDN,
				"TEST_SERVICES_DN":        servicesDN,
				"TEST_DIRECTORY_ADMIN_DN": adminDN,
				"TEST_MANAGEMENT_DN":      managementDN,
				"TEST_PASSWORD_HASHED":    passwords["OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED"],
			}, dataAdminCheck)
		}(); err != nil {
			return fmt.Errorf("directory admin %s: %w", mode, err)
		}
	}

	generated, err := expect(ctx, withEnv(image, merge(base, env{"OPENLDAP_BOOTSTRAP_DATA_ADMIN_PASSWORD_HASHED": ""})), true,
		[]string{"Generated database admin user password:", "config file testing succeeded"}, "container", "--skip-process")
	if err != nil {
		return err
	}
	data, err := generated.container.WithExec([]string{"container", "run", "--", "slapcat", "-n", "1", "-a", "(cn=admin)"}).Stdout(ctx)
	if err != nil {
		return err
	}
	if !strings.Contains(data, "dn: cn=admin,ou=services,"+suffix) || !strings.Contains(data, "userPassword:: ") {
		return fmt.Errorf("generated directory admin account/password missing")
	}
	return nil
}

//go:embed testdata/data-admin.sh
var dataAdminCheck string
