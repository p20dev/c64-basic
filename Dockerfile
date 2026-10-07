FROM node:22-alpine

WORKDIR /app
COPY server.mjs ./server.mjs
COPY public ./public
COPY . /programs

ENV PORT=8080
ENV PROGRAM_DIRECTORY=/programs
EXPOSE 8080

USER node
CMD ["node", "server.mjs"]

