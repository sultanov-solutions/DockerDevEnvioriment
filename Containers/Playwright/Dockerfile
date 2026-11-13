FROM node:26.13.1-slim

ENV PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers

# libnss3-tools: certutil, чтобы добавить локальный CA в хранилище Chromium
RUN apt-get update \
    && apt-get install -y --no-install-recommends libnss3-tools \
    && npm i -g playwright@1.65.0 \
    && playwright install --with-deps chromium \
    && chmod -R a+rX /opt/pw-browsers \
    && rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /out
