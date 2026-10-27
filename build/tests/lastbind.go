package tests

import (
	"context"
	_ "embed"
	"fmt"

	"dagger.io/dagger"
)

// LastBind checks successful bind tracking and precision, with and without ppolicy.
func LastBind(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}

	for _, mode := range []string{"default", "enabled", "precise", "ppolicy"} {
		settings := env{}
		if mode != "default" {
			settings["OPENLDAP_BOOTSTRAP_DATA_LAST_BIND"] = "true"
		}
		if mode == "precise" {
			settings["OPENLDAP_BOOTSTRAP_DATA_LAST_BIND_PRECISION"] = "0"
		}
		if mode == "ppolicy" {
			settings["OPENLDAP_BOOTSTRAP_PPOLICY"] = "true"
		}
		if err := func() error {
			node := "lastbind-" + mode
			service, err := startNode(ctx, image, node, merge(passwords, settings), nil, nil)
			if err != nil {
				return err
			}
			defer stopNodes(ctx, []*dagger.Service{service})
			return check(ctx, image, nil, env{
				"TEST_NODES":          node,
				"TEST_LAST_BIND_MODE": mode,
			}, lastBindCheck)
		}(); err != nil {
			return fmt.Errorf("last bind %s: %w", mode, err)
		}
	}
	return nil
}

//go:embed testdata/lastbind.sh
var lastBindCheck string
