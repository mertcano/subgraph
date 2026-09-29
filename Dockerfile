# Runtime is pinned to the exact Node major/minor/patch that CI validates
# (see .github/workflows/ci.yml, which runs the test suite on Node 22). Building
# the image on a different major than the one the suite runs against means the
# shipped artifact is never the artifact that was tested.
FROM node:22.22.0-slim

# psql is needed for dumping and restoring the initial effects cache.
# ca-certificates: the -slim base ships no CA bundle, so the native hypersync-client
# Rust addon fails TLS to *.hypersync.xyz with "UnknownIssuer" (Node bundles its own, this addon doesn't).
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates postgresql-client && \
    rm -rf /var/lib/apt/lists/*

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN npm install -g pnpm@10.32.1

WORKDIR /envio-indexer

COPY ./package.json ./package.json
COPY ./pnpm-lock.yaml ./pnpm-lock.yaml

# `--frozen-lockfile` fails the build if the lockfile drifts from package.json,
# which keeps the image reproducible from the committed lockfile alone.
RUN pnpm install --frozen-lockfile

COPY ./config.yaml ./config.yaml
COPY ./schema.graphql ./schema.graphql

RUN pnpm envio codegen

COPY ./ ./

# Run as an unprivileged user. The `node` image ships a `node` user (uid 1000);
# the indexer only ever reads its own bundle and writes to its data directory, so
# root is unnecessary and would turn any RCE in the indexer process into root on
# the container.
USER node

CMD pnpm envio start
