# excalidraw-mcp (Docker)

A small, reproducible Docker packaging of [excalidraw/excalidraw-mcp](https://github.com/excalidraw/excalidraw-mcp) —
a [Model Context Protocol](https://modelcontextprotocol.io) server that renders Excalidraw diagrams
(and streams them element-by-element) for MCP-capable clients.

This repository contains **only the container build files**; the upstream project is cloned and built
inside the image at build time.

## Why

- **One command** to get a running MCP server (`docker compose up --build`).
- **Reproducible**: pin the upstream ref via a build arg.
- **Persistent**: diagram checkpoints survive container restarts via a named volume.
- **Stateless host**: no Node/pnpm/bun toolchain needed on the host.

## Quick start

```bash
docker compose up --build
```

The server listens on <http://localhost:3001/mcp>.

Or without Compose:

```bash
docker build -t excalidraw-mcp:local .
docker run --rm -p 3001:3001 \
  -v excalidraw-checkpoints:/tmp/excalidraw-mcp-checkpoints \
  excalidraw-mcp:local
```

## Connect an MCP client

Point any remote/HTTP MCP client at `http://localhost:3001/mcp`. Example (`opencode.jsonc`):

```jsonc
{
  "mcp": {
    "excalidraw": {
      "type": "remote",
      "url": "http://localhost:3001/mcp"
    }
  }
}
```

## Configuration

### Build args

| Arg | Default | Description |
| --- | --- | --- |
| `EXCALIDRAW_MCP_REF` | `main` | Upstream branch, tag, or commit to build. Pin this for reproducible images. |
| `NODE_VERSION` | `22` | Node.js base image version. |

```bash
docker build --build-arg EXCALIDRAW_MCP_REF=v0.1.0 -t excalidraw-mcp:0.1.0 .
```

### Runtime

| Variable | Default | Description |
| --- | --- | --- |
| `PORT` | `3001` | Port the MCP server listens on. |
| `NODE_ENV` | `production` | Node environment. |

### Volumes

| Path | Purpose |
| --- | --- |
| `/tmp/excalidraw-mcp-checkpoints` | `FileCheckpointStore` output. Mount a volume to keep checkpoints across restarts. |

## How the image is built

1. **builder** (`node:22-bookworm-slim`): installs `git`/`ca-certificates`, enables corepack,
   clones upstream at `EXCALIDRAW_MCP_REF`, runs `pnpm install --frozen-lockfile` and `pnpm run build`
   (`tsc` + `vite` + `bun build`).
2. **runtime** (`node:22-slim`): copies `dist/` and `package.json`, runs `node dist/index.js`,
   and exposes port `3001`.

A `HEALTHCHECK` issues a `GET /mcp` request — the server answers with a 4xx when no session exists,
which is treated as healthy (any status `< 500`).

## Troubleshooting

- **`Cannot find module ...` on startup** — `bun build` may leave a transitive dependency external.
  Uncomment this line in the `Dockerfile` and rebuild:

  ```dockerfile
  COPY --from=builder /app/node_modules ./node_modules
  ```

- **Checkpoints disappear after restart** — make sure the `excalidraw-checkpoints` volume is mounted
  (Compose does this by default).

## License

The files in this repository (Docker build files) are released under the
[MIT License](LICENSE).

Images built from this repository bundle the upstream
[`excalidraw/excalidraw-mcp`](https://github.com/excalidraw/excalidraw-mcp) project, which remains
under the license chosen by its authors; see that repository for its terms.
