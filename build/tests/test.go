package tests

import (
	"context"
	"fmt"
	"log"
	"time"

	"dagger.io/dagger"

	"github.com/osixia/dagger-build/job"
)

// scenario is an integration test run against a built image.
type scenario struct {
	name string
	run  func(ctx context.Context, client *dagger.Client, image *dagger.Container) error
}

var scenarios = []scenario{
	{"default bootstrap", Default},
	{"global request limits", GlobalLimits},
	{"read-only bootstrap templates", ReadOnlyTemplates},
	{"alternative schemas", AlternativeSchemas},
	{"TLS certificate reload", TLSReload},
	{"automatic module loading", AutomaticModules},
	{"audit logging", AuditLog},
	{"last successful binds", LastBind},
	{"password history privacy", PasswordPolicyHistory},
	{"password policy inactivity", PasswordPolicyIdle},
	{"progressive password policy lockouts", PasswordPolicyDelay},
	{"password helpers", PasswordHelpers},
	{"LDIF validation", ValidateLDIF},
	{"refint empty-group placeholders", RefintNothing},
	{"all features with 3 replicated nodes", AllFeatures},
	{"backup and restore", BackupRestore},
	{"upgrade", Upgrade},
	{"upgrade from previous releases", UpgradeFromPreviousReleases},
}

// Run checks OpenLDAP behavior after the reusable job's version check. CI builds each arch
// on a native runner: run locally with --arches matching the host to avoid emulation.
func Run(ctx context.Context, client *dagger.Client, builds []*job.BuildResult) error {

	for _, build := range builds {
		for _, image := range build.Containers {

			for _, s := range scenarios {
				log.Printf("scenario: %s ...", s.name)
				sctx, cancel := context.WithTimeout(ctx, 10*time.Minute)
				err := s.run(sctx, client, image)
				cancel()
				if err != nil {
					return fmt.Errorf("%s: %w", s.name, err)
				}
				log.Printf("scenario: %s passed", s.name)
			}
		}
	}

	return nil
}
