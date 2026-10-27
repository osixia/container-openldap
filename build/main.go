package main

import (
	"context"
	"os"

	"dagger.io/dagger"

	"github.com/osixia/container-openldap/build/tests"
	"github.com/osixia/dagger-build/cmd"
	"github.com/osixia/dagger-build/config"
	"github.com/osixia/dagger-build/job"
)

func main() {

	// image

	var OpenLDAPImage = &config.Image{
		BaseImage:    "osixia/baseimage:alpine-2.1.0",
		Distribution: config.Alpine,

		Name:        "osixia/openldap",
		Description: "OpenLDAP container image 🐳🪪🌴",

		Url:           "https://opensource.osixia.net/projects/container-images/openldap/",
		Documentation: "https://opensource.osixia.net/projects/container-images/openldap/",
		Source:        "https://github.com/osixia/container-openldap",

		Authors: "The osixia/container-openldap maintainers",
		Vendor:  "Osixia",

		Licences: "MIT",
	}

	config.Images = []*config.Image{
		OpenLDAPImage,
	}

	config.DefaultImage = OpenLDAPImage

	// github

	config.ProjectGithubRepo = &config.GithubRepo{
		Organization: "osixia",
		Project:      "container-openldap",
	}

	// tests

	job.Test = func(ctx context.Context, client *dagger.Client, options any) ([]*job.BuildResult, error) {
		builds, err := job.DefaultTest(ctx, client, options)
		if err != nil {
			return nil, err
		}
		if err := tests.Run(ctx, client, builds); err != nil {
			return nil, err
		}
		return builds, nil
	}

	// execute cmd

	mainCtx := context.Background()
	if err := cmd.Run(mainCtx); err != nil {
		os.Exit(1)
	}

}
