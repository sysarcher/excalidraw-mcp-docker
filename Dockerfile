# syntax=docker/dockerfile:1

ARG NODE_VERSION=22

# ---------- builder ----------
FROM node:${NODE_VERSION}-bookworm-slim AS builder

# Branch/tag/ref of excalidraw/excalidraw-mcp to build.
ARG EXCALIDRAW_MCP_REF=main

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Enables the pnpm version pinned in package.json (packageManager: pnpm@10.11.0).
RUN corepack enable

WORKDIR /app

# Clone upstream. The build pipeline (tsc + vite + bun build) needs node for
# tsc/vite and bun for bundling; the repo's postinstall provides a local bun
# binary via its @oven/bun-linux-* optional dependencies.
RUN git clone --depth 1 --branch "${EXCALIDRAW_MCP_REF}" \
      https://github.com/excalidraw/excalidraw-mcp.git .

RUN pnpm install --frozen-lockfile
RUN pnpm run build

# ---------- runtime ----------
FROM node:${NODE_VERSION}-slim AS runtime

ENV NODE_ENV=production \
    PORT=3001

WORKDIR /app

# dist/ contains the bundled server (index.js + server.js) and the single-file
# MCP App widget (dist/mcp-app.html), which the server reads from ./dist.
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json

# Some transitive deps may be left external by `bun build`. If the container
# exits with a "Cannot find module" error, uncomment the next line to ship deps:
# COPY --from=builder /app/node_modules ./node_modules

EXPOSE 3001

# The server has no dedicated health route; a GET/any request to /mcp proves it
# is listening (it will answer 4xx without a session, which still means healthy).
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "const h=require('node:http');const r=h.request({host:'127.0.0.1',port:process.env.PORT||3001,path:'/mcp',method:'GET'},s=>process.exit(s.statusCode<500?0:1));r.on('error',()=>process.exit(1));r.end()"

CMD ["node", "dist/index.js"]
