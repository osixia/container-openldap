package tests

import (
	"context"
	_ "embed"
	"fmt"

	"dagger.io/dagger"
)

// AuditLog checks file-based auditing, custom paths, rotation and process restarts.
func AuditLog(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}

	for _, mode := range []string{"default", "enabled", "custom", "minimal", "explicit"} {
		settings := env{}
		file := "/var/log/openldap/audit.ldif"
		if mode != "default" {
			settings["OPENLDAP_BOOTSTRAP_AUDITLOG_ENABLED"] = "true"
		}
		if mode == "custom" {
			file = "/var/log/openldap/custom audit.ldif"
			settings["OPENLDAP_BOOTSTRAP_AUDITLOG_FILE"] = file
		}
		if mode == "minimal" || mode == "explicit" {
			settings["OPENLDAP_BOOTSTRAP_MODULES"] = "back_mdb.so argon2.so"
			if mode == "explicit" {
				settings["OPENLDAP_BOOTSTRAP_MODULES"] += " /usr/lib/openldap/auditlog.so"
			}
		}
		if err := check(ctx, withEnv(image, merge(passwords, settings)), nil, env{
			"TEST_AUDITLOG_MODE": mode,
			"TEST_AUDITLOG_FILE": file,
		}, auditlogCheck); err != nil {
			return fmt.Errorf("auditlog %s: %w", mode, err)
		}
	}
	return nil
}

//go:embed testdata/auditlog.sh
var auditlogCheck string
