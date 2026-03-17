# OpenLDAP Schemas

This directory contains optional schemas that can be loaded during bootstrap with `OPENLDAP_BOOTSTRAP_SCHEMAS`.

## eduperson

Academic identity schema used in higher-education federations (students, staff, affiliations, scoped identifiers).

https://github.com/REFEDS/eduperson/blob/master/schema/openldap/eduperson.schema

## kerberos 

Kerberos LDAP schema for storing principals and Kerberos-related attributes in LDAP-backed KDC setups.

https://github.com/krb5/krb5/blob/master/src/plugins/kdb/ldap/libkdb_ldap/kerberos.schema

## openssh-lpk

Adds OpenSSH public key attributes (for example `sshPublicKey`) to publish SSH keys directly from LDAP.

https://github.com/AndriiGrytsenko/openssh-ldap-publickey/blob/master/misc/openssh-lpk-openldap.schema

## rfc2307bis

Extended RFC2307/NIS-style schema for UNIX account/group integration, including better group/member modeling.

https://dev.gentoo.org/~robbat2/distfiles/rfc2307bis.schema-20120525

Fixed version: https://github.com/shoop/openldap-rfc2307bis/blob/master/rfc2307bis.schema

## samba

Samba directory schema for domain/account attributes used by Samba services and legacy domain integration.

https://gitlab.com/samba-team/samba/-/blob/master/examples/LDAP/samba.schema

## sudo

Schema for storing sudo rules in LDAP (`sudoRole`) so sudo policy can be centralized.

https://www.sudo.ws/docs/man/sudoers.ldap.man/

## totp

Schema for Time-based One-Time Password (TOTP) secrets and metadata for LDAP-based 2FA workflows.

https://github.com/wheelybird/ldap-totp-schema/blob/main/totp-schema.ldif

## virtualMail

Mail-oriented schema for virtual mailbox deployments (mail accounts, aliases, delivery metadata).

https://github.com/tleuxner/ldap-virtualMail/blob/master/schema.txt
