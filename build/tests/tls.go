package tests

import (
	"context"
	_ "embed"
	"fmt"

	"dagger.io/dagger"
)

// TLSReload verifies certificate rotation on new TLS connections by restarting only after file contents change.
func TLSReload(ctx context.Context, client *dagger.Client, image *dagger.Container) error {
	passwords, err := rootPasswords(ctx, image)
	if err != nil {
		return err
	}
	c := withEnv(image, merge(passwords, env{
		"OPENLDAP_BOOTSTRAP_TLS":          "true",
		"OPENLDAP_BOOTSTRAP_TLS_CERT":     "/run/container/projected/tls.crt",
		"OPENLDAP_BOOTSTRAP_TLS_CERT_KEY": "/run/container/projected/tls.key",
		"OPENLDAP_BOOTSTRAP_TLS_CA_CERT":  "/run/container/projected/ca.crt",
	})).WithUser("0").
		WithDirectory("/run/container/certs1", certificates(client, []string{"localhost"}), dagger.ContainerWithDirectoryOpts{Owner: ldapUser}).
		WithDirectory("/run/container/certs2", certificates(client, []string{"localhost"}), dagger.ContainerWithDirectoryOpts{Owner: ldapUser}).
		WithNewFile("/run/container/tls-reload-test.sh", tlsReloadCheck).
		WithExec([]string{"container", "packages", "install", "openssl"}).
		WithMountedDirectory("/tmp", client.Directory(), dagger.ContainerWithMountedDirectoryOpts{ReadOnly: true}).
		WithUser(ldapUser)
	_, err = expect(ctx, c, true, []string{"TLS reload checks: OK"}, "container", "run", "--", "bash", "/run/container/tls-reload-test.sh")
	if err != nil {
		return fmt.Errorf("TLS reload: %w", err)
	}
	return nil
}

//go:embed testdata/tls-reload.sh
var tlsReloadCheck string
