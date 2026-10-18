package tests

import (
	"context"
	_ "embed"
	"fmt"

	"dagger.io/dagger"
)

// RefintNothing covers default behavior and automatic placeholder creation,
// including removal of a group's last member.
func RefintNothing(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}

	base := merge(passwords, env{
		"OPENLDAP_BOOTSTRAP_REFINT":            "true",
		"OPENLDAP_BOOTSTRAP_MEMBEROF":          "true",
		"OPENLDAP_BOOTSTRAP_MEMBEROF_DANGLING": "error",
	})
	nothingDN := "cn=unassigned," + suffix

	for _, mode := range []string{"default", "create", "disabled"} {
		settings := env{}
		if mode != "default" {
			settings["OPENLDAP_BOOTSTRAP_REFINT_NOTHING_DN"] = nothingDN
		}
		if mode == "disabled" {
			settings["OPENLDAP_BOOTSTRAP_REFINT"] = "false"
		}
		if err := func() error {
			node := "refint-" + mode
			service, err := startNode(ctx, image, node, merge(base, settings), nil, nil)
			if err != nil {
				return err
			}
			defer stopNodes(ctx, []*dagger.Service{service})
			return check(ctx, image, nil, env{
				"TEST_NODES":       node,
				"TEST_REFINT_MODE": mode,
				"TEST_NOTHING_DN":  nothingDN,
				"TEST_NOTHING_CN":  "unassigned",
			}, refintCheck)
		}(); err != nil {
			return fmt.Errorf("refint %s: %w", mode, err)
		}
	}
	return nil
}

//go:embed testdata/refint.sh
var refintCheck string
