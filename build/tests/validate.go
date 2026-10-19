package tests

import (
	"context"
	_ "embed"
	"fmt"

	"dagger.io/dagger"
)

// ValidateLDIF checks entry validation without changing local config or data.
func ValidateLDIF(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}
	for _, mode := range []string{"offline", "online"} {
		if err := check(ctx, withEnv(image, passwords), nil,
			env{"TEST_VALIDATE_LDIF_MODE": mode}, validateLDIFCheck); err != nil {
			return fmt.Errorf("LDIF validation %s: %w", mode, err)
		}
	}
	return nil
}

//go:embed testdata/validate-ldif.sh
var validateLDIFCheck string
