ARG BASE_IMAGE="osixia/baseimage:alpine-2.0.0-alpha3"
FROM ${BASE_IMAGE}

ARG IMAGE="osixia/openldap:develop"
ENV CONTAINER_IMAGE=${IMAGE}

ARG OPENLDAP_VERSION=2.6.10-r0

ARG OPENLDAP_GROUP_GID=911
ARG OPENLDAP_USER_UID=911

# Add OpenLDAP group and user
RUN addgroup -g "${OPENLDAP_GROUP_GID}" ldap \
    && adduser -D \
         -u "${OPENLDAP_USER_UID}" \
         -G ldap \
         -s /sbin/nologin \
         ldap

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

# Change user to ldap
USER ldap:ldap

EXPOSE 3890 6360
