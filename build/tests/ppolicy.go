package tests

import (
	"context"
	_ "embed"
	"fmt"

	"dagger.io/dagger"
)

// PasswordPolicyIdle checks inactivity limits and their bootstrap prerequisites.
func PasswordPolicyIdle(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}

	base := merge(passwords, env{
		"OPENLDAP_BOOTSTRAP_PPOLICY":                  "true",
		"OPENLDAP_BOOTSTRAP_DATA_LAST_BIND":           "true",
		"OPENLDAP_BOOTSTRAP_DATA_LAST_BIND_PRECISION": "0",
		"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_AGE":  "0",
	})

	for _, prerequisite := range []string{
		"OPENLDAP_BOOTSTRAP_DATA_LAST_BIND",
		"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_LOCKOUT",
	} {
		settings := merge(base, env{
			"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_IDLE": "3600",
			prerequisite: "false",
		})
		if _, err := expect(ctx, withEnv(image, settings), false,
			[]string{"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_IDLE requires " + prerequisite + "=true"},
			"container", "--skip-process"); err != nil {
			return fmt.Errorf("max idle without %s: %w", prerequisite, err)
		}
	}

	for _, mode := range []string{"default", "enabled"} {
		settings := env{}
		if mode == "enabled" {
			settings["OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_IDLE"] = "3600"
		}
		if err := func() error {
			node := "ppolicy-idle-" + mode
			service, err := startNode(ctx, image, node, merge(base, settings), nil, nil)
			if err != nil {
				return err
			}
			defer stopNodes(ctx, []*dagger.Service{service})
			return check(ctx, image, nil, env{
				"TEST_NODES":             node,
				"TEST_PPOLICY_IDLE_MODE": mode,
			}, ppolicyIdleCheck)
		}(); err != nil {
			return fmt.Errorf("max idle %s: %w", mode, err)
		}
	}
	return nil
}

//go:embed testdata/ppolicy-idle.sh
var ppolicyIdleCheck string

// PasswordPolicyDelay checks progressive lockouts and the existing failure threshold.
func PasswordPolicyDelay(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}
	base := merge(passwords, env{"OPENLDAP_BOOTSTRAP_PPOLICY": "true"})
	for _, tc := range []struct {
		settings env
		message  string
	}{
		{env{"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MIN_DELAY": "2"}, "Password policy delays must satisfy"},
		{env{"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_DELAY": "4"}, "Password policy delays must satisfy"},
		{env{
			"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MIN_DELAY": "4",
			"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_DELAY": "2",
		}, "Password policy delays must satisfy"},
		{env{
			"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MIN_DELAY": "2",
			"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_DELAY": "4",
			"OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_LOCKOUT":   "false",
		}, "Password policy delays require OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_LOCKOUT=true"},
	} {
		if _, err := expect(ctx, withEnv(image, merge(base, tc.settings)), false,
			[]string{tc.message}, "container", "--skip-process"); err != nil {
			return fmt.Errorf("password policy delay prerequisites: %w", err)
		}
	}

	for _, mode := range []string{"default", "enabled", "threshold"} {
		settings := env{}
		if mode != "default" {
			settings["OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MIN_DELAY"] = "2"
			settings["OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_DELAY"] = "4"
		}
		if mode == "threshold" {
			settings["OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_FAILURE"] = "2"
		}
		if err := func() error {
			node := "ppolicy-delay-" + mode
			service, err := startNode(ctx, image, node, merge(base, settings), nil, nil)
			if err != nil {
				return err
			}
			defer stopNodes(ctx, []*dagger.Service{service})
			return check(ctx, image, nil, env{
				"TEST_NODES":              node,
				"TEST_PPOLICY_DELAY_MODE": mode,
			}, ppolicyDelayCheck)
		}(); err != nil {
			return fmt.Errorf("password policy delay %s: %w", mode, err)
		}
	}
	return nil
}

//go:embed testdata/ppolicy-delay.sh
var ppolicyDelayCheck string
