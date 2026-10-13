# excalidraw-mcp (Docker)

A small, reproducible Docker packaging of [excalidraw/excalidraw-mcp](https://github.com/excalidraw/excalidraw-mcp) —
a [Model Context Protocol](https://modelcontextprotocol.io) server that renders Excalidraw diagrams
(and streams them element-by-element) for MCP-capable clients.

This repository contains **only the container build files**; the upstream project is cloned and built
inside the image at build time.

## Why

- **One command** to get a running MCP server (`docker compose up` pulls the published image).
- **Reproducible**: pin the upstream ref via a build arg.
- **Persistent**: diagram checkpoints survive container restarts via a named volume.
- **Stateless host**: no Node/pnpm/bun toolchain needed on the host.

## Quick start

The image is published to GHCR by CI on every push to `main` and on `v*` tags.

```bash
docker compose up
```

This pulls `ghcr.io/sysarcher/excalidraw-mcp-docker:latest` and serves on
<http://localhost:3001/mcp>.

Without Compose:

```bash
docker run --rm -p 3001:3001 \
  -v excalidraw-checkpoints:/tmp/excalidraw-mcp-checkpoints \
  ghcr.io/sysarcher/excalidraw-mcp-docker:latest
```

### Published image

`ghcr.io/sysarcher/excalidraw-mcp-docker`

| Tag | Source |
| --- | --- |
| `latest` | latest push to `main` |
| `main` | tip of `main` |
| `sha-<short>` | a specific commit |
| `1.2.3`, `1.2`, `1` | a `v1.2.3` git tag |

Pin a version with `DOCKER_TAG`, e.g. `DOCKER_TAG=sha-537180c docker compose up`.

### Build from source

```bash
docker compose -f docker-compose.yml -f docker-compose.build.yml up --build
```

This builds locally via the `Dockerfile` and tags the result with the same image name.

## Connect an MCP client

The server supports two transports: **Streamable HTTP** (default) and **stdio**
(`node dist/index.js --stdio`). opencode works with either — pick one.

### opencode — stdio (recommended)

No port and no long-running daemon: opencode launches a throwaway container that
speaks MCP over stdio and exits with the session. `docker run` pulls the image on
demand, so there is nothing to start first. Checkpoints persist in the
`excalidraw-mcp-checkpoints` volume.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "excalidraw": {
      "type": "local",
      "command": [
        "docker", "run", "-i", "--rm",
        "-v", "excalidraw-mcp-checkpoints:/tmp/excalidraw-mcp-checkpoints",
        "ghcr.io/sysarcher/excalidraw-mcp-docker:latest",
        "node", "dist/index.js", "--stdio"
      ],
      "enabled": true
    }
  }
}
```

> Pass the full `node dist/index.js --stdio` command — the base image sets
> `docker-entrypoint.sh` as `ENTRYPOINT`, so `--stdio` on its own is not enough.
> Drop the `-v …` line if checkpoints don't need to survive between sessions.

### opencode — Streamable HTTP

Run the server (default command) and point a remote MCP client at it:

```bash
docker compose up -d
```

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "excalidraw": {
      "type": "remote",
      "url": "http://localhost:3001/mcp"
    }
  }
}
```

### Other clients

Any Streamable HTTP MCP client can connect to `http://localhost:3001/mcp` while the
server is running; any stdio client can use the `docker run -i … --stdio`
invocation shown above.

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

The [publish workflow](.github/workflows/publish.yml) builds a multi-arch image
(`linux/amd64`, `linux/arm64`) and pushes it to GHCR on pushes to `main` and on `v*`
tags, with provenance and SBOM attestations. Locally, the same `Dockerfile` is used:

1. **builder** (`node:22-bookworm-slim`): installs `git`/`ca-certificates`, enables corepack,
   clones upstream at `EXCALIDRAW_MCP_REF`, runs `pnpm install --frozen-lockfile` and `pnpm run build`
   (`tsc` + `vite` + `bun build`).
2. **runtime** (`node:22-slim`): copies `dist/` and `package.json` and runs `node dist/index.js`.
   By default it starts the **Streamable HTTP** server on port `3001`; passing `--stdio`
   (`node dist/index.js --stdio`) starts the **stdio** transport instead.

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
