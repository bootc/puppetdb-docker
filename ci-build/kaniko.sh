#!/bin/dash
#
# NB: This script runs in a Kaniko container in BusyBox ash. You must avoid
# bashisms when modifying this script.
#

set -eu

case "$CI_COMMIT_REF_SLUG" in
  "$CI_DEFAULT_BRANCH")
    # Strip out all non-numeric characters from the date to get YYYYMMDDHHMMSS
    COMMIT_TS="$(echo "$CI_COMMIT_TIMESTAMP" | sed -e 's/[^0-9]//g' | cut -c1-14)"
    TAGS="${CI_COMMIT_BRANCH}-${CI_COMMIT_SHORT_SHA}-${COMMIT_TS}${ARCH:+-${ARCH}}"
    ;;
  *)
    TAGS="$CI_COMMIT_REF_SLUG${ARCH:+-${ARCH}}"
    ;;
esac

CREATED_DATE="$(date --utc +%Y-%m-%dT%H:%M:%SZ)"

kaniko_destinations() {
  for TAG in $TAGS; do
    echo "--destination ${CI_REGISTRY_IMAGE}:${TAG}";
  done
}

# Generate the Docker config.json with authentication info
[ -z "${DOCKER_CONFIG:-}" ] && export DOCKER_CONFIG=/kaniko/.docker/
cat > "${DOCKER_CONFIG}/config.json" <<EOF
{
  "auths": {
    "${CI_REGISTRY}": {
      "username": "${CI_REGISTRY_USER}",
      "password": "${CI_REGISTRY_PASSWORD}"
    }
  }
}
EOF

echo "Building image: $CI_REGISTRY_IMAGE ..."
set -x

# Build the container image
# shellcheck disable=SC2046
/kaniko/executor \
  --context . \
  --dockerfile puppetdb/Dockerfile \
  --cache \
  --digest-file "kaniko-digest${ARCH:+-${ARCH}}.txt" \
  --label org.opencontainers.image.created="$CREATED_DATE" \
  --label org.opencontainers.image.revision="$CI_COMMIT_SHA" \
  "$@" \
  $(kaniko_destinations)

# vim: ai ts=2 sw=2 et sts=2 ft=sh
