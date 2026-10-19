#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# All runtime scratch files must work with /tmp mounted read-only.
if touch /tmp/openldap-write-probe 2>/dev/null; then
    fail '/tmp is unexpectedly writable'
fi
cat > /run/container/runtime-temp.schema <<'SCHEMA'
attributetype ( 1.3.6.1.4.1.4203.666.11.999.1 NAME 'runtimeTempAttribute' EQUALITY caseIgnoreMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 )
SCHEMA
openldap-ctl schema2ldif /run/container/runtime-temp.schema > /run/container/schema-conversion.log
test -s /run/container/runtime-temp.ldif

mkdir /run/container/projected
ln -s /run/container/certs1 /run/container/projected/..data
for name in tls.crt tls.key ca.crt; do
    ln -s "..data/${name}" "/run/container/projected/${name}"
done

container --kill-all=false -x openldap -x openldap-bootstrap -x openldap-upgrade \
    -x openldap-tls-reload > /run/container/tls-container.log 2>&1 &
runner=$!
trap 'kill -TERM "${runner}" 2>/dev/null || true; wait "${runner}" || true' EXIT

serial() {
    openssl s_client -connect 127.0.0.1:6360 </dev/null 2>/dev/null | openssl x509 -noout -serial
}
wait_serial() {
    local expected="$1"
    for _ in {1..150}; do
        if [ "$(serial 2>/dev/null || true)" = "${expected}" ]; then
            return 0
        fi
        sleep 0.1
    done
    cat /run/container/tls-container.log
    fail "TLS certificate did not become ${expected}"
}
rotate() {
    ln -s "$1" /run/container/projected/..next
    mv -Tf /run/container/projected/..next /run/container/projected/..data
}
restart_count() {
    grep -c 'TLS file contents changed; restarting OpenLDAP' /run/container/tls-container.log || true
}
assert_no_restart() {
    sleep 3
    [ "$(cat /run/container/processes/openldap.pid)" = "${original_pid}" ] || fail 'unchanged TLS files restarted slapd'
    [ "$(restart_count)" = "${expected_restarts}" ] || fail 'unexpected TLS restart'
}
expected1=$(openssl x509 -in /run/container/certs1/tls.crt -noout -serial)
expected2=$(openssl x509 -in /run/container/certs2/tls.crt -noout -serial)
wait_serial "${expected1}"
for _ in {1..100}; do
    if grep -q 'Watching changes on' /run/container/tls-container.log; then
        break
    fi
    sleep 0.1
done
sleep 0.2
original_pid=$(cat /run/container/processes/openldap.pid)
expected_restarts=0

# Metadata events and identical rewrites must not restart slapd.
touch /run/container/certs1/tls.crt
cp /run/container/certs1/tls.crt /run/container/copy.crt
cat /run/container/copy.crt > /run/container/certs1/tls.crt
assert_no_restart

# Even a forced Kubernetes-style projection with identical bytes is ignored.
cp -R /run/container/certs1 /run/container/certs-identical
rotate /run/container/certs-identical
assert_no_restart

# Multiple events from one renewal must cause exactly one restart.
rotate /run/container/certs2
wait_serial "${expected2}"
[ "$(cat /run/container/processes/openldap.pid)" != "${original_pid}" ] || fail 'slapd was not restarted'
original_pid=$(cat /run/container/processes/openldap.pid)
expected_restarts=1
assert_no_restart

# A second renewal still works and duplicate callbacks remain harmless.
rotate /run/container/certs1
wait_serial "${expected1}"
[ "$(cat /run/container/processes/openldap.pid)" != "${original_pid}" ] || fail 'second renewal did not restart slapd'
original_pid=$(cat /run/container/processes/openldap.pid)
expected_restarts=2
assert_no_restart

# Ordinary directory mounts: replacing symlinks with identical regular files
# must not restart slapd either, then a direct multi-file renewal restarts once.
for name in tls.crt tls.key ca.crt; do
    cp -L "/run/container/projected/${name}" "/run/container/${name}"
    mv -f "/run/container/${name}" "/run/container/projected/${name}"
done
assert_no_restart
for name in tls.crt tls.key ca.crt; do
    cp "/run/container/certs2/${name}" "/run/container/projected/${name}"
done
wait_serial "${expected2}"
[ "$(cat /run/container/processes/openldap.pid)" != "${original_pid}" ] || fail 'direct renewal did not restart slapd'
original_pid=$(cat /run/container/processes/openldap.pid)
expected_restarts=3
assert_no_restart

# A watcher event must not undo an intentional administrative stop.
container processes stop openldap
for name in tls.crt tls.key ca.crt; do
    cp "/run/container/certs1/${name}" "/run/container/projected/${name}"
done
sleep 3
[ -e /run/container/processes/openldap.down ] || fail 'intentional stop was undone'
[ "$(restart_count)" = 3 ] || fail 'stopped slapd was restarted'
kill -0 "${runner}"
echo 'TLS reload checks: OK'
