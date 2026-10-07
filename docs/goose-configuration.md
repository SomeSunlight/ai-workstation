# Goose provider and model configuration

AI Workstation exposes the configuration supported by the installed Goose
release. Local/self-hosted APIs and public providers are equally valid choices.
OpenRouter is an optional first test, with no required key or provider default.
The launcher does not infer an optimal model, sampling or reasoning policy.

## Use the native menu

Start `aiw` → **Standard tools (Goose / Open WebUI)** → **Goose** →
**Configure provider, model and extensions**. This opens native `goose configure`
using the selected image and existing persistent home volume. No host project
is mounted. Choose/change the provider, endpoint/credentials, model and extensions.

Choices depend on the installed image. Command-based providers and external
extensions may need additional tools; AI Workstation adds no provider whitelist.
Updating Goose remains the separate **Update application** action.

**Test selected connection (no workspace)** sends a short probe to your selected
provider. **Show status** inspects routing offline without dumping configuration
or secrets. The launcher checks for a provider and model before mounting a
project; Goose performs full provider/authentication validation.

Direct commands work from any WSL directory:

```bash
aiw goose configure
aiw goose env
aiw goose check
aiw goose status
```

Settings, custom providers, credentials and history remain in
`ai-workstation_goose-home`; image updates retain that volume. The container uses
native file-backed secrets (`GOOSE_DISABLE_KEYRING=1`) and disables Goose
telemetry by default. Treat volume backups as sensitive.

## Connect a local/self-hosted OpenAI-compatible API

Choose the built-in **OpenAI** provider with your own API base URL, or create a
native custom OpenAI-compatible provider. The provider name describes the
protocol; the endpoint determines where requests go. Use exact model IDs from
your API's `/v1/models`, for example `sparringpartner` and `agent`.

Set the complete API base URL explicitly. Pinned Goose `v1.44.0` accepts
`OPENAI_BASE_URL=https://llm.example.net/v1`. If you use the older split settings,
set `OPENAI_HOST=https://llm.example.net` and
`OPENAI_BASE_PATH=v1/chat/completions`. Do not retain the public OpenAI endpoint
when intending to use your own API. Use authentication required by your server;
the launcher does not require a public API key.

If the native menu does not expose your required setting, choose **Edit Goose
environment (advanced)** and add its native environment variable:

```dotenv
OPENAI_BASE_URL=https://llm.example.net/v1
```

Container `localhost` identifies the container. A WSL-host service needs a
container-reachable host address and a listening/firewall policy allowing that
connection. A DNS name must resolve to your intended server from the container.

## Main and subagent models

Select `sparringpartner` as the native main model. In **Edit Goose environment
(advanced)** add subagent defaults for the same native provider ID:

```dotenv
GOOSE_SUBAGENT_PROVIDER=openai
GOOSE_SUBAGENT_MODEL=agent
```

For a custom provider replace `openai` with its actual Goose ID. These settings
apply to future containers, leaving the main model unchanged. Your inference
server owns the reasoning/sampling profiles behind the two model IDs.
Goose may send request-level temperature/reasoning settings, and subagents can
inherit settings from the main session. Check the server's effective request
parameters if the two profiles must remain distinct.

These are defaults, not routing enforcement. Pinned `v1.44.0` supports them, but
explicit delegation arguments and recipe settings can take precedence.
Precedence changes between Goose releases; inspect the release you select.
Delegation also needs Goose's `summon` extension. A model split does not
automatically optimize every task or guarantee the main model delegates tasks.

Native per-session flags remain available:

```bash
aiw goose session my-project --provider openai --model sparringpartner
```

## Optional environment and migration

The advanced menu edits `~/.config/ai-workstation/goose.env` using `VISUAL`, then
`EDITOR`, otherwise `sensible-editor`. `AIW_GOOSE_ENV_FILE` can explicitly choose
another file. The operator directory is protected and the file is kept at mode
`600`. Keep alternate files outside Git or in ignored locations.

Use one `NAME=value` per line; blank/comment lines are allowed. Values are
literal: `$` and quotes pass through. Do not add shell quotes or rely on variable
interpolation. The optional file is injected only into Goose and is never
sourced as shell code. Raw env-file support requires Docker Compose 2.30+; the
workstation pins a newer version. Explicit `GOOSE_PROVIDER`/`GOOSE_MODEL` values
override native settings, so prefer native configuration for normal setup.

Previous installations forced `GOOSE_PROVIDER`, `GOOSE_MODEL` and
`OPENROUTER_API_KEY` from shared `.env`. Those entries are now ignored by Goose;
the key remains available to Open WebUI. Choose your intended connection in the
native configuration menu. Existing settings/history remain; no cloud values
are silently imported and no volumes are deleted. Missing/incomplete routing
stops the launcher before a project is mounted.

## One-time reset of old Compose ownership

An older installation may print:

```text
volume "ai-workstation_goose-home" already exists but was created for project "ai-workstation" (expected "ai-workstation-goose")
```

This concerns the volume's stored Compose ownership label, not the image or LLM.
The stable volume name is valid. The home remains a normal Compose-managed
volume; routine commands operate only on `ai-workstation-goose` and do not
clean up the old Compose project automatically.

For a clean reset, close all Goose sessions with `/exit`. **This deletes native
Goose settings, custom providers, stored credentials, sessions and cache.**
Proceed only when you accept that loss or have backed up the home volume.
Project files, workspace registrations, the optional `goose.env` file, installed
images and Open WebUI data are outside this reset.

In a WSL terminal:

```bash
aiw goose down
docker ps --all --filter volume=ai-workstation_goose-home --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'
```

The container list must be empty before removing the volume. If an old utility
container remains, inspect that exact container and check its Compose project
and service labels:

```bash
docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}} / {{index .Config.Labels "com.docker.compose.service"}}' CONTAINER_ID
```

Only an obsolete Goose container with labels `ai-workstation / goose` belongs
to this historical cleanup. Stop and remove that exact container with
`docker stop CONTAINER_ID` followed by `docker rm CONTAINER_ID`; inspect any
other volume user before proceeding. Avoid old-project `down --remove-orphans`,
which could also affect services that previously shared the project.

Once no container uses the home, reset and reconfigure:

```bash
docker volume rm ai-workstation_goose-home
aiw goose configure
docker volume inspect --format '{{index .Labels "com.docker.compose.project"}} / {{index .Labels "com.docker.compose.volume"}}' ai-workstation_goose-home
aiw goose check
```

Compose creates a fresh home during configuration. The ownership check must
print `ai-workstation-goose / goose-home`, and the warning should disappear.
Retained `goose.env` values still apply; if a custom provider's new ID changes,
adjust any primary, planner or subagent provider references in the advanced
environment menu before testing.

## Confidential project operation

Select your own endpoint, main model and subagent defaults, then test the
connection before starting a project session. AI Workstation injects no shared
public credentials and adds no public fallback.

Goose honors explicit CLI/recipe/delegation overrides and saved provider/model
choices in resumed sessions. Extensions may contact other services. Start a new
session for confidential work, review those settings and remove stored public
credentials you do not intend to use.

Exactly one host project is mounted; network access remains unrestricted.
If public destinations must be impossible after a mistaken setting or extension
action, enforce an outbound destination policy outside Goose (for example a
firewall/allowlisted proxy). Selecting a local model alone is not enforcement.
Shared history in Goose's home volume remains available across project sessions.

Upstream references: [providers](https://goose-docs.ai/docs/getting-started/providers/),
[subagents](https://goose-docs.ai/docs/guides/subagents/), the pinned
[OpenAI provider](https://github.com/aaif-goose/goose/blob/v1.44.0/crates/goose-providers/src/openai.rs)
and [delegation implementation](https://github.com/aaif-goose/goose/blob/v1.44.0/crates/goose/src/agents/platform_extensions/summon.rs).
