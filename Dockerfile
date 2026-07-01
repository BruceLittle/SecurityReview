FROM ruby:3.3.6-slim AS base

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libpq5 curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH="/usr/local/bundle"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential libpq-dev git && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

COPY . .

# No secrets are needed to precompile assets/bootsnap cache in this app
# (API + server-rendered admin views only, no webpacker/js bundling), so
# no RAILS_MASTER_KEY or credentials are baked into the image at build time.
RUN bundle exec bootsnap precompile app/ lib/ || true

FROM base

# Run as a non-root, unprivileged user — a container compromise doesn't
# hand the attacker root inside the container.
RUN useradd --create-home --shell /bin/bash app
COPY --from=build --chown=app:app /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=app:app /app /app

USER app
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s CMD curl -sf http://localhost:3000/healthz || exit 1

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
