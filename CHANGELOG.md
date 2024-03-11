# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.5.1] - 2024-03-11
### Changed
  - Update openldap 2.4.57 to 2.5.13
  - Upgrade baseimage to light-baseimage:1.3.4 (debian bookworm)

## [1.5.0] - 2021-02-19
50M+ docker pulls 🎉🎉🎉 thanks to all contributors 💕

### Added
  - Allowing own replication via LDAP_REPLICATION=own #535. Thanks to @sistason !
  - Seeding from internal path is now complete. #361. Thanks to @dbck !

### Changed
  - Update openldap 2.4.50 to 2.4.57
  - Upgrade baseimage to light-baseimage:1.3.2. Thanks to @heidemn !
  - Replace mail.schema for postfix-book.schema #450. Thanks to @vivacarvajalito !
  - Replace zarafa.schema for kopano.schema

### Removed
  - mmc schemas (dhcp.schema, dnszone.schema, mail.schema, mmc.schema, quota.schema) and radius.schema

### Fixed
  - Few small typos #536. Thanks to @timgates42 !
  - Out of date api in the using-secrets kubernetes yaml #527. Thanks to @joshuacox !
  - Custom ldap file and schema #481.  Thanks to @Os-carsun !

## [1.4.0] - 2020-06-15
30M+ docker pulls 🎉🎉🎉 thanks to all contributors 💕

### Added
  - Allow setting ports on ldap and ldaps #403. Thanks to @chirauki !
  - Address firewall issues on RHEL in README #394. Thanks to @BirkhoffLee !
  - Ensure ca certs are up to date #387. Thanks to @Jyrno42 !
  - Install slapd-contrib to include pbkdf2 pw support #365. Thanks to @col-panic !
  - Seeding from internal path. #361. Thanks to @dbck !
  - Enable openldap uid/gid to be specified at runtime #336. Thanks to @lj020326 !

### Changed
  - Update openldap 2.4.48 to 2.4.50 
  - LDAP_TLS_PROTOCOL_MIN is deprecated #432. Thanks to @mettacrawler !
  - Better handling of environment variables checks #382. Thanks to @obourdon !

### Fixed
  - Multi-node replication fixes #420. Thanks to @pcolmer !
  - Grant root manage access to database #416. Thanks to @olia-dev !

## [1.3.0] - 2019-09-29
### Added
  - Multiarch support

### Changed
  - Update openldap 2.4.47 to 2.4.48 #247
  - Upgrade baseimage to light-baseimage:1.2.0 (debian buster)

## [1.2.5] - 2019-08-16
### Added
  - Support for docker secrets #325. Thanks to @anagno !
  - Add DISABLE_CHOWN environment variable #240
  - pqChecker lib to check passwords strength with ppolicy pwdCheckModule

### Fixed
  - Fix of incorrectly positioned 'log-helper debug' command #327. Thanks to @turcan !
  - Fix domain dn #341. Thanks to @obourdon !

## [1.2.4] - 2019-03-14
### Fixed
  - Excessive RAM usage on 1.2.2, increased 10x from 1.2.1 #242
  - Startup issue with 1.2.3 #283

## [1.2.3] - 2019-01-21
10M+ docker pulls 🎉🎉🎉 thanks to all contributors 💕

### Added
  - GCE statefulset #241
  - Custom dhparam.pem via environment. #254

### Changed
  - Update openldap 2.4.44 to 2.4.47 #247
  - Upgrade baseimage to light-baseimage:1.1.2

### Fixed
  - Ldaps port numbers in readme #281
  - Replication after restart container #264

## [1.2.2] - 2018-09-04
### Added
  - Environment variable LDAP_NOFILE to setup a custom ulimit value #237
  
### Fixed
  - Remove schema ambiguity #204
  - lidf typo in readme #217
  - Ignore all the folders started with . #232

### Security 
  - Fix self-edit security issue #239
  
    Thanks to Yann Voumard for reporting this and @jonremy for the fix.

## [1.2.1] - 2018-05-14
### Security
  - The default "write" access to "*" by  "self" in the file  "config/bootstrap/ldif/02-security.ldif" allowed anyone to change all the data about himself. This includes the gid and uid numbers what could lead to serious security issues.

  This has been changed to ```olcAccess: to * by self read by dn="cn=admin,{{ LDAP_BASE_DN }}" write by * none"```

  Thanks to Francesc Escale for reporting this.

## [1.2.0] - 2018-03-02
### Changed
  - Use mdb as default backend

### Fixed
  - startup.sh: Ensure SCHEMAS is sorted #193
  - LDAP_ADMIN_PASSWORD with space breaks container setup #167

## [1.1.11] - 2017-12-19
### Added
  - Add krb5-kdc-ldap with doc examples #171
  - Add support of readonly user in custom bootstrap ldif #162

### Fixed
  - Fix NFS issue #169
  - Create schemas in a consistent order. #174

## [1.1.10] - 2017-11-09
### Changed
  - Upgrade baseimage to light-baseimage:1.1.1

### Fixed
  - Readme #145 #148
  - Let ldapmodify and ldapadd use the same auth #146
  - Enable matching uid's and gid's in the host and container. #156

## [1.1.9] - 2017-07-19
### Added
  - LDAP_RFC2307BIS_SCHEMA option to use rfc2307bis schema instead of nis default schema
  - KEEP_EXISTING_CONFIG option to not change the ldap config

### Changed
  - Upgrade baseimage to light-baseimage:1.1.0 (debian stretch)

## [1.1.8] - 2017-02-16
### Fixed
  - LDAP_ENFORCE_TLS is not working correctly #107
  - Unable to reuse volumes after LDAP_TLS_ENFORCE is true #92

## [1.1.7] - 2016-11-09
### Changed
  - Upgrade baseimage to light-baseimage:0.2.6

## [1.1.6] - 2016-09-02
### Changed
  - Upgrade baseimage to light-baseimage:0.2.5

### Fixed
  - Upgrade to 1.1.5 startup issues with cfssl-helper #73

## [1.1.5] - 2016-08-02
### Fixed
  - Restarting container with new environment #44
  - Cannot rerun with customized certificate at 1.1.1 #36

## [1.1.4] - 2016-07-26
### Fixed
  - Remove environment variable LDAP_TLS_PROTOCOL_MIN as it takes no effect, see #69
  - Adjust default GnuTLS cipher string according to Red Hat's TLS hardening guide.
    This by default also restricts the TLS protocol version to 1.2. For reference,
    see #69
  - Fix Error in Adding "Billy" #71
  - Add docker-compose.yml example and update kubernetes examples #52
  - Update LDAP_TLS_CIPHER_SUITE, remove LDAP_TLS_PROTOCOL_MIN #70
  - fixed LDAP_BACKEND for readonly user #62

## [1.1.3] - 2016-06-09
In this version the new environment variable LDAP_BACKEND let you set the the backend used by your ldap database.
By default it's hdb. In comming versions 1.2.x the default will be changed to mdb.

Environment variable LDAP_REPLICATION_HDB_SYNCPROV changed to LDAP_REPLICATION_DB_SYNCPROV

### Added
  - Use mdb over hdb #50

### Changed
  - Ignore lost+found directories #53
  - LDAP_REPLICATION_HDB_SYNCPROV changed to LDAP_REPLICATION_DB_SYNCPROV
  - Upgrade baseimage to light-baseimage:0.2.4

### Removed
  - Volume command from Dockerfile #56

## [1.1.2] - 2016-03-18
### Fixed
  - Honor LDAP_LOG_LEVEL on startup #39
  - slapd tcp bind is network not interface, and so does not respond on overlay networks #35
  - specify base_dn without domain #37

## [1.1.1] - 2016-02-20
### Changed
  - Upgrade baseimage to light-baseimage:0.2.2

## [1.1.0] - 2016-01-25
### Added
  - Use \*.startup.yaml environment files to keep configuration secrets
  - Use cfssl tool to generate tls certs
  - Use log-helper to write leveled log messages
  - Allow copy of /container/service and mounted files to /container/run/service dir usefull for write only filesystems and avoid file permissions problems
  - Add enforcing TLS options (#26)

### Changed
  - Upgrade baseimage to light-baseimage:0.2.1

### Fixed
  - Should SSL certs be copied on load? (#25)

## [1.0.9] - 2015-12-16
### Added
  - Makefile with build no cache

### Changed
  - Upgrade baseimage to light-baseimage:0.2.0

## [1.0.8] - 2015-11-23
### Fixed
  - An other startup bug ! whuhu

## [1.0.7] - 2015-11-20
### Fixed
  - Startup bug

## [1.0.6] - 2015-11-20
### Changed
  - Upgrade baseimage to light-baseimage:0.1.5

## [1.0.5] - 2015-11-19
### Changed
  - Upgrade baseimage to light-baseimage:0.1.4

### Fixed
  - Replication bug when the hostname was changed

## [1.0.4] - 2015-11-06
### Changed
  - Upgrade baseimage to light-baseimage:0.1.3

## [1.0.3] - 2015-10-26
### Changed
  - Upgrade baseimage to light-baseimage:0.1.2

### Fixed
  - Re-running container with volumes won't start #19

## [1.0.2] - 2015-08-27
### Added
  - LDAP_TLS_CIPHER_SUITE
  - LDAP_TLS_PROTOCOL_MIN
  - LDAP_TLS_VERIFY_CLIENT

## [1.0.1] - 2015-08-18
### Changed
  - Upgrade baseimage to light-baseimage:0.1.1

### Fixed
  - OpenLdap container won't start when dhparam.pem is missing in bound volume #13

## [1.0.0] - 2015-07-24
### Added
  - Improve documentation

### Changed
  - Upgrade baseimage to light-baseimage

## [0.10.2] - 2015-07-14
### Added
  - Bootstrap config, only on non existing slapd config
  - Limit max open file descriptors to fix slapd memory usage (#9)
  - Don't disable network access from outside (#8)
  - Make log level configurable via environment variable (#7)
  - Support for ldaps (#10)

### Fixed
  - Unable to start container with the following invocation. (#6)

## [0.10.1] - 2015-05-17
### Added
  - LDAPI
  - Custom ldap schema
  - Auto convert .schema to .ldif

### Fixed
  - Docker VOLUME is not needed to be able to stop a container without losing data (#2)
  - starting from old data (#3)

## [0.10.0] - 2015-03-03
New version initial release, no changelog before this sorry.

[1.5.0]: https://github.com/osixia/docker-openldap/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/osixia/docker-openldap/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/osixia/docker-openldap/compare/v1.2.5...v1.3.0
[1.2.5]: https://github.com/osixia/docker-openldap/compare/v1.2.4...v1.2.5
[1.2.4]: https://github.com/osixia/docker-openldap/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/osixia/docker-openldap/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/osixia/docker-openldap/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/osixia/docker-openldap/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/osixia/docker-openldap/compare/v1.1.11...v1.2.0
[1.1.11]: https://github.com/osixia/docker-openldap/compare/v1.1.10...v1.1.11
[1.1.10]: https://github.com/osixia/docker-openldap/compare/v1.1.9...v1.1.10
[1.1.9]: https://github.com/osixia/docker-openldap/compare/v1.1.8...v1.1.9
[1.1.8]: https://github.com/osixia/docker-openldap/compare/v1.1.7...v1.1.8
[1.1.7]: https://github.com/osixia/docker-openldap/compare/v1.1.6...v1.1.7
[1.1.6]: https://github.com/osixia/docker-openldap/compare/v1.1.5...v1.1.6
[1.1.5]: https://github.com/osixia/docker-openldap/compare/v1.1.4...v1.1.5
[1.1.4]: https://github.com/osixia/docker-openldap/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/osixia/docker-openldap/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/osixia/docker-openldap/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/osixia/docker-openldap/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/osixia/docker-openldap/compare/v1.0.9...v1.1.0
[1.0.9]: https://github.com/osixia/docker-openldap/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/osixia/docker-openldap/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/osixia/docker-openldap/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/osixia/docker-openldap/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/osixia/docker-openldap/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/osixia/docker-openldap/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/osixia/docker-openldap/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/osixia/docker-openldap/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/osixia/docker-openldap/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/osixia/docker-openldap/compare/v1.10.2...v1.0.0
[0.10.2]: https://github.com/osixia/docker-openldap/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/osixia/docker-openldap/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/osixia/docker-openldap/compare/v0.1.0...v0.10.0
