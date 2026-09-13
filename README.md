# MCP.MailCalendarContacts

A hardened, provider-neutral mail, calendar, and contacts MCP server deployment for Codex Gateway. This repository packages [Adjutant](https://github.com/MarimerLLC/calendar-mcp) at reviewed commit `b38414bcfe666ef563d7f87c40b3c44dde096a7b`; the Docker build verifies the source archive checksum before compiling it.

The server supports multiple Microsoft 365, Outlook.com, Google, IMAP/SMTP, ICS, and JSON accounts. Generic IMAP/SMTP accounts provide email only. The MCP server and all provider-specific code live here; Codex Gateway treats it as an ordinary Streamable HTTP MCP server.

## Security defaults

- The MCP endpoint is confined to the trusted private network and does not use
  transport-level API-key authentication.
- The management UI uses a different administrator token.
- New accounts default to calendar read-only.
- Mail, contacts, calendar writes, and outbound email require explicit account-level permission.
- Microsoft and Google OAuth scopes are derived from the enabled account capabilities.
- The container runs as a dedicated non-root user. Compose deliberately avoids
  `no-new-privileges` because some supported Docker hosts reject .NET process
  execution when that option is applied.
- Account configuration, OAuth caches, and protected IMAP/SMTP credentials remain in a dedicated volume.
- The UI binds to loopback by default, and the container joins the gateway backend network rather than its runner network.

Codex Gateway provides the tool-authorization layer: each API key/project grant selects exact MCP tools, and its run-scoped relay rejects calls to tools outside that selection.

## Start the server

The Compose deployment expects the external `codex-gateway-backend` network created by the gateway deployment. Start Codex Gateway first, or create the network explicitly:

```powershell
docker network create codex-gateway-backend
```

Copy `.env.example` to `.env`, replace the administrator token, sign in to `registry.tichymichal.net`, and start the published image:

```powershell
docker compose pull
docker compose up -d
```

Use `docker compose up --build -d` instead when validating the pinned upstream source and local patch.

Open `http://localhost:5051/admin/ui` and authenticate with `MAIL_CALENDAR_CONTACTS_MCP_ADMIN_TOKEN` to configure provider accounts.

Treat the persistent volume as a secret. On Linux, the current Microsoft token-cache implementation relies on owner-only file permissions rather than a host keyring.

## Connect Codex Gateway

Add an HTTP MCP server through the gateway UI:

| Field | Value |
| --- | --- |
| Name | `Mail, Calendar & Contacts` |
| URL | `http://mail-calendar-contacts-mcp:8080` |
| Execution mode | `Gateway` |

Use **Test connection & discover tools** and select the tools that may be offered by this trusted server. The gateway catalog selection is separate from the per-API-key/project selection.

For a gateway running directly on the host, use `http://localhost:5051` instead of the Docker network address.

## Capability boundaries

The server exposes 30 tools grouped by effect:

- Discovery: account listing and usage guidance.
- Mail read: listing, searching, details, attachments, contextual summaries, and unsubscribe information.
- Mail management: read-state changes, moves, and deletion, including bulk variants.
- Outbound mail: `send_email`, native-thread `reply_email`, and `unsubscribe_from_email`.
- Calendar read: calendars, events, and event details.
- Calendar write: create, update, delete, and respond to events.
- Contacts read: list, search, and details.
- Contacts write: create, update, and delete contacts.

Leave the outbound-mail tools unselected in a gateway grant to prevent sending, replying, and outbound unsubscribe actions. Calendar and contact mutations can be disabled independently from their read tools.

## Updating Adjutant

1. Review the upstream changes and choose an immutable commit.
2. Update `ADJUTANT_COMMIT` and the source archive SHA-256 in `Dockerfile` and `compose.yaml`.
3. Rebase `patches/safe-defaults.patch` against that commit.
4. Build the image and verify the MCP endpoint is reachable only on the intended private network.
5. Initialize an MCP session and verify all expected tools and server metadata.

The upstream Apache 2.0 license is copied into `/licenses/adjutant-LICENSE` in the resulting image.
