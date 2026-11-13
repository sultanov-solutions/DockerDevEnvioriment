FROM rust:1.100.0-slim-trixie

# pkg-config + libssl-dev: needed to build the most common native crates (openssl-sys)
RUN apt-get update \
    && apt-get install -y --no-install-recommends pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# watchexec: restarts `cargo run` when sources change (hot reload)
RUN cargo install --locked watchexec-cli@2.8.0 \
    && rm -rf /usr/local/cargo/registry
