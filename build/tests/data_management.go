package tests

import (
	"context"
	_ "embed"
	"fmt"
	"strings"

	"dagger.io/dagger"
)

// DataManagement checks optional tree creation and the scoped password-reset account.
func DataManagement(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}
	base := merge(passwords, env{
		"OPENLDAP_BOOTSTRAP_DATA_TREE":                       "true",
		"OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT":                 "true",
		"OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_PASSWORD_HASHED": passwords["OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED"],
	})

	for _, mode := range []string{"disabled", "tree", "plain", "policy", "custom", "supplied"} {
		if err := func() error {
			usersDN := "ou=users," + suffix
			groupsDN := "ou=groups," + suffix
			servicesDN := "ou=services," + suffix
			managementDN := "cn=management," + servicesDN
			settings := merge(base)
			nodeImage := image
			switch mode {
			case "disabled":
				settings["OPENLDAP_BOOTSTRAP_DATA_TREE"] = "false"
				settings["OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT"] = "false"
			case "tree":
				settings["OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT"] = "false"
			case "policy":
				settings = merge(settings, env{
					"OPENLDAP_BOOTSTRAP_PPOLICY":                       "true",
					"OPENLDAP_BOOTSTRAP_MEMBEROF":                      "true",
					"OPENLDAP_BOOTSTRAP_REFINT":                        "true",
					"OPENLDAP_BOOTSTRAP_REFINT_NOTHING_DN":             "cn=empty-group," + servicesDN,
					"OPENLDAP_BOOTSTRAP_UNIQUE":                        "true",
					"OPENLDAP_BOOTSTRAP_AUDITLOG_ENABLED":              "true",
					"OPENLDAP_BOOTSTRAP_DATA_READONLY":                 "true",
					"OPENLDAP_BOOTSTRAP_DATA_READONLY_PASSWORD_HASHED": passwords["OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED"],
				})
			case "custom":
				usersDN = "ou=people," + suffix
				groupsDN = "ou=roles," + suffix
				servicesDN = "ou=machines," + suffix
				managementDN = "cn=sso," + servicesDN
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
			settings = merge(settings, env{
				"OPENLDAP_BOOTSTRAP_DATA_TREE_USERS_DN":    usersDN,
				"OPENLDAP_BOOTSTRAP_DATA_TREE_GROUPS_DN":   groupsDN,
				"OPENLDAP_BOOTSTRAP_DATA_TREE_SERVICES_DN": servicesDN,
				"OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_DN":    managementDN,
			})
			node := "management-" + mode
			service, err := startNode(ctx, nodeImage, node, settings, nil, nil)
			if err != nil {
				return err
			}
			defer stopNodes(ctx, []*dagger.Service{service})
			return check(ctx, image, nil, env{
				"TEST_NODES":           node,
				"TEST_MANAGEMENT_MODE": mode,
				"TEST_USERS_DN":        usersDN,
				"TEST_GROUPS_DN":       groupsDN,
				"TEST_SERVICES_DN":     servicesDN,
				"TEST_MANAGEMENT_DN":   managementDN,
			}, dataManagementCheck)
		}(); err != nil {
			return fmt.Errorf("data management %s: %w", mode, err)
		}
	}

	generated, err := expect(ctx, withEnv(image, merge(base, env{"OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_PASSWORD_HASHED": ""})), true,
		[]string{"Generated database management user password:", "config file testing succeeded"}, "container", "--skip-process")
	if err != nil {
		return err
	}
	data, err := generated.container.WithExec([]string{"container", "run", "--", "slapcat", "-n", "1", "-a", "(cn=management)"}).Stdout(ctx)
	if err != nil {
		return err
	}
	if !strings.Contains(data, "cn: management") || !strings.Contains(data, "userPassword:: ") {
		return fmt.Errorf("generated management account/password missing")
	}
	return nil
}

//go:embed testdata/data-management.sh
var dataManagementCheck string
