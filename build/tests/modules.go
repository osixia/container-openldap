package tests

import (
	"context"
	_ "embed"
	"fmt"

	"dagger.io/dagger"
)

// AutomaticModules checks automatic selection and exact explicit module ordering.
func AutomaticModules(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}

	const baseModules = "back_mdb.so argon2.so"
	const explicitModules = "back_mdb.so pw-sha2.so argon2.so memberof refint.so unique /usr/lib/openldap/ppolicy.so auditlog"
	type moduleCase struct {
		name     string
		settings env
		modules  string
		fails    bool
	}
	cases := []moduleCase{
		{"default", nil, baseModules, false},
		{"custom order", env{"OPENLDAP_BOOTSTRAP_MODULES": "back_mdb.so pw-sha2.so argon2.so memberof.so"}, "back_mdb.so pw-sha2.so argon2.so memberof.so", false},
		{"explicit aliases", env{
			"OPENLDAP_BOOTSTRAP_MODULES":          explicitModules,
			"OPENLDAP_BOOTSTRAP_AUDITLOG_ENABLED": "true",
			"OPENLDAP_BOOTSTRAP_PPOLICY":          "true",
			"OPENLDAP_BOOTSTRAP_UNIQUE":           "true",
			"OPENLDAP_BOOTSTRAP_REFINT":           "true",
			"OPENLDAP_BOOTSTRAP_MEMBEROF":         "true",
		}, explicitModules, false},
		{"missing explicit module", env{
			"OPENLDAP_BOOTSTRAP_MODULES": baseModules,
			"OPENLDAP_BOOTSTRAP_UNIQUE":  "true",
		}, "", true},
		{"all automatic", env{
			"OPENLDAP_BOOTSTRAP_AUDITLOG_ENABLED":                   "true",
			"OPENLDAP_BOOTSTRAP_PPOLICY":                            "true",
			"OPENLDAP_BOOTSTRAP_UNIQUE":                             "true",
			"OPENLDAP_BOOTSTRAP_REFINT":                             "true",
			"OPENLDAP_BOOTSTRAP_MEMBEROF":                           "true",
			"OPENLDAP_BOOTSTRAP_REPLICATION":                        "true",
			"OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD": replicationPassword,
		}, baseModules + " ppolicy.so unique.so refint.so memberof.so auditlog.so syncprov.so", false},
	}
	for _, feature := range []struct{ flag, module string }{
		{"AUDITLOG_ENABLED", "auditlog"},
		{"PPOLICY", "ppolicy"},
		{"UNIQUE", "unique"},
		{"REFINT", "refint"},
		{"MEMBEROF", "memberof"},
	} {
		cases = append(cases, moduleCase{feature.module, env{"OPENLDAP_BOOTSTRAP_" + feature.flag: "true"}, baseModules + " " + feature.module + ".so", false})
	}
	for _, tc := range cases {
		if err := check(ctx, withEnv(image, merge(passwords, tc.settings)), nil, env{
			"TEST_MODULES":         tc.modules,
			"TEST_BOOTSTRAP_FAILS": fmt.Sprint(tc.fails),
		}, modulesCheck); err != nil {
			return fmt.Errorf("modules %s: %w", tc.name, err)
		}
	}
	return nil
}

//go:embed testdata/modules.sh
var modulesCheck string
