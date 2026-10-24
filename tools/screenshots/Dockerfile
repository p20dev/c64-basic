FROM mcr.microsoft.com/playwright:v1.56.1-noble

WORKDIR /tool
COPY tools/screenshots/package*.json ./
RUN npm ci --omit=dev
COPY tools/screenshots/capture.mjs ./

ENTRYPOINT ["node", "/tool/capture.mjs"]
