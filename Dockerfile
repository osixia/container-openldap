ARG BASE_IMAGE="osixia/baseimage:alpine-2.0.0-alpha5"
FROM ${BASE_IMAGE}

ARG IMAGE="osixia/openldap:develop"
ENV CONTAINER_IMAGE=${IMAGE}

# Add OpenLDAP group and user
ARG OPENLDAP_GROUP_GID=911
ARG OPENLDAP_USER_UID=911

RUN container groups add "${OPENLDAP_GROUP_GID}" ldap \
    && container users add "${OPENLDAP_USER_UID}" ldap --group-id "${OPENLDAP_GROUP_GID}" --group-name ldap

# Set OpenLDAP version
ARG OPENLDAP_VERSION=2.6.10-r0
ENV OPENLDAP_VERSION="${OPENLDAP_VERSION}"

# Install all OpenLDAP packages
RUN container packages install --update --clean \
    openldap-backend-all="${OPENLDAP_VERSION}" \
    openldap-clients="${OPENLDAP_VERSION}" \
    openldap-overlay-all="${OPENLDAP_VERSION}" \
    openldap-passwd-argon2="${OPENLDAP_VERSION}" \
    openldap-passwd-pbkdf2="${OPENLDAP_VERSION}" \
    openldap-passwd-sha2="${OPENLDAP_VERSION}" \
    openldap="${OPENLDAP_VERSION}"

COPY services /container/services

RUN container services install \
    && container services link

COPY environment /container/environment

USER ldap

EXPOSE 3890 6360
