# syntax=docker/dockerfile:1.7
#
# Commit image for yaf (a PHP extension). Builds on the org C/C++ base and adds the PHP dev + embed
# packages the harnesses link against. Build from the repo root:
#   DOCKER_BUILDKIT=1 docker build -f mayhem/Dockerfile --build-arg COMMIT=$(git rev-parse HEAD) -t yaf-commit .
FROM ghcr.io/savantenvs/base:20261023

ARG COMMIT
ARG REPO_URL
ARG SOURCE_DATE_EPOCH
ARG SANITIZER_FLAGS
ARG COVERAGE_FLAGS=
ARG MAYHEM_JOBS=

# PHP is the host the extension runs in: php-dev (phpize, headers, run-tests.php), libphp-embed (the
# embed SAPI the harnesses link) and php-cli (the binary the phpt suite runs). They come from the dated
# Debian snapshot, and the packages stay baked in the image, so the offline build.sh re-run needs no network.
USER root
RUN [ -n "$SOURCE_DATE_EPOCH" ] && repro-sources-list.sh || true ; \
    apt-get update && apt-get install -yq --no-install-recommends \
        php8.4-dev libphp8.4-embed php8.4-cli \
 && rm -rf /var/lib/apt/lists/*
USER mayhem

USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN if [ -x /opt/mayhem/ccache/prefill ]; then /opt/mayhem/ccache/prefill bash mayhem/build.sh; \
    else bash mayhem/build.sh; fi

RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
