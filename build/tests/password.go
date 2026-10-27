package tests

import (
	"context"
	_ "embed"

	"dagger.io/dagger"
)

// PasswordHelpers checks password input sources by authenticating with their hashes.
func PasswordHelpers(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}

	const node = "password-helpers"
	service, err := startNode(ctx, image, node, passwords, nil, nil)
	if err != nil {
		return err
	}
	defer stopNodes(ctx, []*dagger.Service{service})

	return check(ctx, image, nil, env{"TEST_NODES": node}, passwordCheck)
}

//go:embed testdata/password.sh
var passwordCheck string
