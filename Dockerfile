# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. The runtime image is distroless:
# it has no shell and no package manager. Build and run by hand:
# docker build -t hubee .
# docker run -d -p 80:3000 -e SECRET_KEY_BASE=<...> -e DATABASE_HOST=<...> -e DATABASE_PORT=<...> -e DATABASE_USERNAME=<...> -e DATABASE_PASSWORD=<...> --name hubee hubee

FROM gcr.io/distroless/base-debian13@sha256:0ebad3510af52aefe45045cc01b07564570be4feecf8d9f93d3a05d1b5f2f93b AS distroless

FROM docker.io/library/ruby:4.0.7-slim@sha256:d10bdb076bb10d2261773ea20eadf4cdbde3346fc8f8db409856608b2d01b9c9 AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libjemalloc2 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Runtime pieces the final image lacks, from Ruby and the base image only, so this stage
# stays cached until the ruby or distroless digest changes.
FROM base AS shared-libs

# Reference rootfs, to stage only the libraries the final image lacks.
COPY --from=distroless / /distroless-ref

RUN <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# The libraries staged below are linked against this stage's glibc and OpenSSL: both images
# must be the same Debian release.
build_release="$(. /etc/os-release; echo "$VERSION_ID")"
runtime_release="$(. /distroless-ref/usr/lib/os-release; echo "$VERSION_ID")"
if [ "$build_release" != "$runtime_release" ]; then
  echo "error: build stage is Debian $build_release, runtime base is Debian $runtime_release" >&2
  exit 1
fi

mkdir -p /shared-libs/usr/local
cp -a /usr/local/bin /usr/local/lib /shared-libs/usr/local/
rm -rf /shared-libs/usr/local/lib/pkgconfig /shared-libs/usr/local/lib/libjemalloc.so /shared-libs/usr/local/lib/ruby/gems/*/cache

cp -L /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /shared-libs/usr/local/lib/libjemalloc.so

# Keep /usr/bin/env so #!/usr/bin/env shebangs still resolve without a shell.
mkdir -p /shared-libs/usr/bin
cp -L /usr/bin/env /shared-libs/usr/bin/env

# Without the C.UTF-8 locale files (libc-bin), LANG=C.UTF-8 is ignored and Ruby falls back to US-ASCII.
mkdir -p /shared-libs/usr/lib/locale
cp -a /usr/lib/locale/C.utf8 /shared-libs/usr/lib/locale/

# Stage every shared library that ruby, its extensions, env and jemalloc link against, unless
# distroless already ships it. realpath folds the merged-usr /lib into /usr/lib.
ldd_out="$(mktemp)"
{
  find /usr/local/bin -type f -perm -u+x -print0
  find /usr/local/lib -name '*.so*' -type f -print0
  printf '%s\0' /usr/bin/env /shared-libs/usr/local/lib/libjemalloc.so
} | xargs -0 -r ldd > "$ldd_out" 2>&1 || true

awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) next; print so }' "$ldd_out" | sort -u | while read -r so; do
  dir="$(realpath "$(dirname "$so")")"
  name="$(basename "$so")"
  [ -e "/distroless-ref$dir/$name" ] && continue
  mkdir -p "/shared-libs$dir"
  cp -L "$so" "/shared-libs$dir/$name"
  echo "staged $dir/$name"
done

# Debian's OPENSSLDIR (/usr/lib/ssl) is absent from distroless.
mkdir -p /shared-libs/usr/lib/ssl
ln -s /etc/ssl/certs /shared-libs/usr/lib/ssl/certs
ln -s /etc/ssl/certs/ca-certificates.crt /shared-libs/usr/lib/ssl/cert.pem
EOF

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock vendor ./

# Bundler credentials for the private GitLab gem source (hub-api-v1 client)
ARG BUNDLE_GITLAB__HUBEE__NUMERIQUE__GOUV__FR
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# A gem extension that needs a library absent from the runtime image must fail here, not at boot.
COPY --from=distroless / /distroless-ref
COPY --from=shared-libs /shared-libs /shared-libs
RUN <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ldd_out="$(mktemp)"
find /usr/local/bundle -name '*.so*' -type f -print0 | xargs -0 -r ldd > "$ldd_out" 2>&1 || true
awk '/=> not found/ { print $1; next } /=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) next; print so }' "$ldd_out" | sort -u | while read -r so; do
  dir="$(realpath "$(dirname "$so")")"
  name="$(basename "$so")"
  [ -e "/distroless-ref$dir/$name" ] || [ -e "/shared-libs$dir/$name" ] || { echo "error: a gem needs $so: add it to the shared-libs stage" >&2; exit 1; }
done
EOF

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without needing the real secrets (SECRET_KEY_BASE, DATABASE_*)
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage for app image
FROM distroless

# Replicated from the ruby base image: distroless has none of this by default.
ENV LANG="C.UTF-8" \
    GEM_HOME="/usr/local/bundle" \
    BUNDLE_APP_CONFIG="/usr/local/bundle" \
    BUNDLE_SILENCE_ROOT_WARNING="1" \
    PATH="/usr/local/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    HOME="/home/nonroot" \
    SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

# Rails app lives here
WORKDIR /rails

# Ruby, shared libraries, jemalloc, env, locale, ssl paths.
COPY --from=shared-libs /shared-libs /

# Run and own only the runtime files as the distroless nonroot user (uid 65532)
COPY --chown=65532:65532 --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=65532:65532 --from=build /rails /rails
USER 65532:65532

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Readiness for the container runtime: /up only proves the app booted, it does not touch the database.
# Ruby stands in for curl, which the image does not have. start-period covers boot and db:prepare.
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD ["/usr/local/bin/ruby", "-rnet/http", "-e", "exit Net::HTTP.get_response(URI('http://127.0.0.1:' + ENV.fetch('PORT', '3000') + '/up')).is_a?(Net::HTTPSuccess)"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
