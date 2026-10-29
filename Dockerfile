FROM node:22-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && mkdir /app/screenshot-cache && chown node:node /app/screenshot-cache
COPY server.mjs ./server.mjs
COPY screenshot-cache.mjs ./screenshot-cache.mjs
COPY public ./public
RUN mkdir -p public/vendor/prism \
    && cp node_modules/prismjs/components/prism-core.min.js public/vendor/prism/ \
    && cp node_modules/prismjs/components/prism-asm6502.min.js public/vendor/prism/ \
    && cp node_modules/prismjs/LICENSE public/vendor/prism/LICENSE
COPY . /programs

ENV PORT=8080
ENV PROGRAM_DIRECTORY=/programs
ENV SCREENSHOT_CACHE_DIRECTORY=/app/screenshot-cache
EXPOSE 8080

USER node
CMD ["node", "server.mjs"]

