package main

import (
	"context"
	"os"

	"github.com/osixia/container-baseimage/build/cmd"
	"github.com/osixia/container-baseimage/build/config"
)

func main() {

	// image

	var OpenLDAPImage = &config.Image{
		BaseImage:    "osixia/baseimage:alpine-2.0.0-alpha5",
		Distribution: config.Alpine,

		Name:        "osixia/openldap",
		Description: "OpenLDAP container image 🐳🛟🌴",

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

	// execute cmd

	mainCtx := context.Background()
	if err := cmd.Run(mainCtx); err != nil {
		os.Exit(1)
	}

}
