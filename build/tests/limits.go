package tests

import (
	"context"
	_ "embed"
	"fmt"

	"dagger.io/dagger"
)

// GlobalLimits checks native defaults, custom limits and request size enforcement.
func GlobalLimits(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}

	for _, mode := range []string{"default", "custom"} {
		settings := env{}
		if mode == "custom" {
			settings = env{
				"OPENLDAP_BOOTSTRAP_GLOBAL_WRITE_TIMEOUT":             "5",
				"OPENLDAP_BOOTSTRAP_GLOBAL_CONN_MAX_PENDING":          "10",
				"OPENLDAP_BOOTSTRAP_GLOBAL_CONN_MAX_PENDING_AUTH":     "20",
				"OPENLDAP_BOOTSTRAP_GLOBAL_SOCKBUF_MAX_INCOMING":      "1024",
				"OPENLDAP_BOOTSTRAP_GLOBAL_SOCKBUF_MAX_INCOMING_AUTH": "2048",
			}
		}
		if err := func() error {
			node := "limits-" + mode
			service, err := startNode(ctx, image, node, merge(passwords, settings), nil, nil)
			if err != nil {
				return err
			}
			defer stopNodes(ctx, []*dagger.Service{service})
			return check(ctx, image, nil, env{
				"TEST_NODES":       node,
				"TEST_LIMITS_MODE": mode,
			}, limitsCheck)
		}(); err != nil {
			return fmt.Errorf("global limits %s: %w", mode, err)
		}
	}
	return nil
}

//go:embed testdata/limits.sh
var limitsCheck string
