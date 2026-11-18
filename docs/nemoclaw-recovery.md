# NemoClaw + Hermes on AIW-Nemo — start, stop, recovery and incident log

**Observed operator flight:** 16–18 November 2026 · **Issue:** [#83](https://github.com/SomeSunlight/ai-workstation/issues/83) · **installation baseline:** [PR #79](https://github.com/SomeSunlight/ai-workstation/pull/79) · **provider migration:** [#80](https://github.com/SomeSunlight/ai-workstation/issues/80).

This runbook concerns the **separate WSL distribution `AIW-Nemo` with Ubuntu 26.04.1, rootless Podman 5.7, NemoClaw, OpenShell and Hermes**. It is **not** the Ubuntu 24.04/Docker/OpenShell+Goose experiment from [#69](https://github.com/SomeSunlight/ai-workstation/issues/69). Do not use Docker commands or the other distribution's gateway port to repair this system. The original sandbox was `testsandbox01` with OpenRouter; after a failed recovery, the operator created **`testhermes01`** using the existing local Dispatcher and model alias `sparringpartner`. Confirm the registered name locally; examples use the latter and **must not** imply the old sandbox still exists.

**Source of truth:** NemoClaw/OpenShell own sandbox, policies, credentials, forwarding and lifecycle; AIW only opens the existing Linux workbench and delegates selected commands. **Do not reinstall, `rebuild`, `destroy`, mutate Podman resources manually, delete WSL or rotate credentials as an ordinary restart.** No production host operation has been executed by this documentation change. More capable commands and flags can change upstream; consult the pinned CLI before a version upgrade.

## One-click Windows penguin — repair, never reinstall

The source already provides the **`NemoClaw Hermes (AIW-Nemo)`** Desktop/Start Menu shortcut and bundled `nemoclaw-hermes.ico`, implemented in `bootstrap/windows/Create-NemoClawShortcut.ps1`. The linked PowerShell launcher checks that the selected WSL distro carries the Nemo profile marker, then invokes the existing Linux `bin/aiw-nemo` menu. **The operator reported the penguin missing on the Windows desktop.** That is a missing/deployed-shortcut problem, not evidence that the icon or launcher code is absent.

From **Windows PowerShell 7.4+**, in a checked-out AI Workstation repository:

```powershell
.\install-nemoclaw.ps1 -Action Shortcuts
.\install-nemoclaw.ps1 -Action Status
```

The shortcut-only action must not import/reinstall Ubuntu, update Podman, invoke onboarding, reboot WSL or alter running sandboxes; it refreshes **only AIW-owned** shortcut files in the Desktop and Start Menu and its own launcher/icon copy under LocalAppData. If a shortcut has been customized or another app owns the same name, the script **refuses to overwrite it**. Desktop path may be redirected by OneDrive/corporate policy; use the reported `Ready:` paths and Windows Start search for **NemoClaw Hermes (AIW-Nemo)**. On a second run, no duplicate link should be created. **Real desktop presence must still be verified on the owner's Windows machine**; GitHub CI only checks isolated Windows shortcut fixtures.

## Normal daily operation — no research, no reinstall

Open **NemoClaw Hermes (AIW-Nemo)**. The menu exports `PATH` and **`NEMOCLAW_GATEWAY_RUNTIME=podman`**, so it does not silently fall back to Docker. Select the new **Launch Hermes** option, choose the already-registered sandbox name (here `testhermes01`) and use the *upstream* `nemohermes launch` command. This starts the interactive Hermes TUI in the selected sandbox, with upstream readiness checks and recovery logic. It does not install a new agent, create another sandbox, or reconfigure the Dispatcher.

For an equivalent manual invocation, enter the dedicated WSL distro from **Windows PowerShell** (replace the placeholder with your existing Linux account if needed):

```powershell
wsl -d AIW-Nemo --user <linux-user>
```

Then in **Linux**:

```bash
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_GATEWAY_RUNTIME=podman

nemohermes testhermes01 status
nemohermes launch testhermes01
```

The `nemohermes launch <name>` command has its own health/preflight contract. If the sandbox is explicitly **Stopped** and `launch` does not start it, use the supported `nemohermes <name> start` and then launch:

```bash
nemohermes testhermes01 start
nemohermes launch testhermes01
```

**Normal shutdown** after the agent finishes: in Hermes, use its exit command (`/exit`) to return to Linux (or exit the interactive shell as indicated by upstream). Then stop **only that sandbox**:

```bash
nemohermes testhermes01 stop
nemohermes testhermes01 status
```

`stop` is an upstream lifecycle action that retains workspace, profile, credentials, policies and registry; **`destroy` does not**. Closing a terminal is not the same as a verified sandbox stop. The shared OpenShell gateway and other registered sandboxes may legitimately remain running. A full Windows reboot naturally stops WSL processes; on return, use **status → start if Stopped → launch**. Do not use `wsl --shutdown` as a routine cleanup: it affects **all** running WSL distros.

## When it breaks: observe first, repair the right layer

All commands below run from **AIW-Nemo Ubuntu**, **not inside Hermes**, with the Podman runtime explicitly selected. The status may print internal endpoints, usernames and provider information: **do not paste unredacted logs into public Issues**.

```bash
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_GATEWAY_RUNTIME=podman

nemohermes testhermes01 status
openshell status
nemohermes testhermes01 logs --tail 50
nemohermes inference get
```

- **Sandbox is Stopped, gateway reachable:** `nemohermes testhermes01 start`, then `nemohermes launch testhermes01`.
- **Sandbox Ready/Running but Hermes dashboard/API forwards unhealthy:** `nemohermes testhermes01 recover`, then `nemohermes launch testhermes01`. `recover` is not a fresh install and should first use upstream identity/ownership checks. Follow its refusal diagnostic if it cannot prove the sandbox.
- **Sandbox Error/Failed, OpenShell gateway unavailable, image or provider missing:** **stop and inspect**, including `nemohermes testhermes01 doctor` if suggested by upstream; do not run `rebuild`, `destroy` or `onboard --resume` reflexively. If registered identity is missing from OpenShell, the next step is a *separately reviewed* backup/restore or new sandbox, never silent replacement.
- **Only the `openshell-gateway.service` systemd user unit is absent:** this is **not** definitive evidence of a dead gateway. On this NemoClaw-owned environment, `openshell status` **actually showed Connected, mTLS authenticated at the NemoClaw loopback gateway** while `systemctl --user status openshell-gateway` said unit not found. Do not invent/install another systemd service.
- **NemoClaw/Podman error:** the vendor selection must be `NEMOCLAW_GATEWAY_RUNTIME=podman`, with the *current user's* rootless socket. Do not export a Docker socket, switch to rootful Podman, or force external privileged container commands.
- **WSL/Desktop fails before reaching the menu:** run `.\install-nemoclaw.ps1 -Action Status` from Windows to see whether the distro and the AIW-owned link are registered, then `-Action Shortcuts` to repair the link. These actions do not recreate Hermes; inspect errors if the distro itself is missing or stopped.

### What actually went wrong (dated owner reports, not reconstructed guesses)

| Incident | Observed symptom | Resolution / safe lesson |
| --- | --- | --- |
| WSL Ubuntu 26 initial user-manager / Windows parsing | `Failed to start the systemd user session` warning sometimes preceded a successful identity probe; PowerShell originally merged stderr and stdout | PR #79 separated streams and verified actual default Linux user, not the first output line |
| Linux privilege escalation | Ubuntu 26 `sudo-rs` prompt and pinned Ansible 2.21 `become` timed out | PR #79 used narrowly scoped Ubuntu-signed classic `sudo.ws` and real preflight; did not change global sudoers |
| WSL multi-distro cgroups | `user@1000.service`/systemd could not start, blocking rootless Podman | Operator updated WSL 2.7.14 → 3.0.5, meeting the ≥2.9.13 contract. Never automatically update shared WSL or change UIDs |
| Empty stderr installer bug | `Get-Content -Raw` returned null and PowerShell called `.Trim()` | Fixed in PR #79 with null/empty stderr handling |
| NemoClaw provider selection | Native Docker Engine inside WSL rejected by vendor admission even though independent OpenShell+Goose had worked | Dedicated Ubuntu26 with **rootless Podman 5.7** and explicit runtime choice; no Docker Desktop identity spoofing |
| Windows Dispatcher test-client registration | `client add` wrote a new DPAPI secret but failed before the `services.yaml` manifest was updated, leaving an orphan key and preventing a clean retry | [PR #82](https://github.com/SomeSunlight/ai-workstation/pull/82) added bounded sharing-error retries, rollback of only newly generated unregistered secrets, and sanitized actionable diagnostics. The exact original Speedy file-lock cause was not proven; never overwrite another secret. Register → verify client → render hash-only registry → restart **only Dispatcher** |
| OpenRouter model lookup | Featured `deepseek-ai/deepseek-v4.1-flash` produced HTTP 400 before the sandbox | Entered supported actual OpenRouter model ID through vendor onboarding; not an OpenShell firewall failure |
| **Nov 18 unexpected restart** | Earlier `testsandbox01` container Exited(1); sandbox log: `Policy fetch failed after 5 attempts: failed to connect to OpenShell server` | Gateway later reported Connected, proving it was **not** a permanent absent-service condition. Prefer status/start/recover over rebuild or reinstall; sandbox remained troubled |
| Rebuild recovery complication | `rebuild` performed a backup/destroy/recreate/restore attempt, aborted on missing **Tavily credential**, then encountered an unreachable sandbox/recovery deadlock even after a temporary key was supplied | This is **not a routine restart**. Previous sandbox was deliberately retired by operator after investigation; new `testhermes01` was separately onboarded. A future rebuild must verify all required credentials and backup integrity before a destructive transition |
| Dispatcher local DNS/SSRF | Approved HTTPS Dispatcher DNS resolved to an **RFC1918 LAN address**; unauthenticated `GET /v1/models` returned HTTP 401 | Service reachable but requires auth; exact-host `NEMOCLAW_TRUSTED_PRIVATE_HOSTS` was used during a separately authorized onboarding run, not a global network bypass |
| NemoClaw forwarding | Dashboard/API port-forwarding warnings after restart | Use `status`/`recover`; don't equate Hermes dashboard/API localhost ports to the Dispatcher HTTPS endpoint, and don't start new unbound listeners |
| Optional Hermes security/tool diagnostics | During the first Hermes sandbox test `tirith` was unavailable; only the vendor's pattern-based fallback was observed | Do not treat a healthy agent run as proof this optional protection ran. Distinguish upstream feature availability and sandbox egress/filesystem policy; avoid installing unsigned or network-fetched helpers merely to silence a warning |
| Sandbox work environment | Chromium missing; Playwright browser install received HTTP403 | Hermes still created `/sandbox/bouquet.html` and used an offline Node DOM/Canvas harness (720 frames, resize cases) to detect and fix two script bugs. A real in-sandbox browser screenshot was **not** verified; treat extra tool downloads/egress as an explicit policy decision |

**What is unproven:** one-command recovery after *every* sleep/crash; preserving active Hermes TUI conversation across host shutdown; unattended backup/restore of a broken Podman gateway; private LAN and port-forward behavior in other DNS conditions. The next **owner trial** must test Start/Stop/Start without `onboard`, and report whether the WSL/Desktop shortcut opens the correct distro.

## The local Dispatcher — supported migration, not a startup command

The Windows inference host runs the pre-existing **Strata/llama.cpp → Dispatcher → Caddy HTTPS** chain. A separate revocable Hermes client key was registered on that trusted Windows host and the **Dispatcher alone** was restarted to activate the registration. The successful newer Hermes sandbox used the logical alias **`sparringpartner`**; the older OpenRouter sandbox is a different provider and identity. Avoid duplicating Strata on WSL or editing NemoClaw's generated Hermes files.

The owner observed an HTTPS host resolving to a **private LAN IP**. The old HTTP 400 from OpenRouter was a bad model selection; **HTTP 401 from the Dispatcher `/v1/models` without a key means the listener was reachable and auth was required, not that model calls had succeeded**. NVIDIA applies trusted-private-endpoint / DNS-pinning restrictions. The owner deliberately permitted **one exact approved hostname** for a **manual provider enrollment**; only perform that if authorized and after verifying the current DNS mapping. It is a trust exception and has a wider reach than a single URL path.

```bash
export NEMOCLAW_GATEWAY_RUNTIME=podman
# Only in an operator-authorized host enrollment shell:
export NEMOCLAW_TRUSTED_PRIVATE_HOSTS='dispatcher.example.invalid'
```

The hostname above is a deliberately invalid placeholder. **Do not** commit your real hostname/IP, broadly allow private networks, or make the exception permanent without a separate decision. The Nov 18 export was shell-local; **persistence across sessions was not observed**. **Normal Hermes restart does not require repeating provider enrollment.**

For an existing sandbox needing a *deliberately approved* provider change, official pinned NemoClaw supported this form (not a normal start command):

```bash
(
  set +x
  IFS= read -r -s -p "Separate Dispatcher Hermes key: " COMPATIBLE_API_KEY
  printf '\n'
  export COMPATIBLE_API_KEY
  export NEMOCLAW_GATEWAY_RUNTIME=podman
  export NEMOCLAW_TRUSTED_PRIVATE_HOSTS='dispatcher.example.invalid'
  nemohermes inference set \
    --provider compatible-endpoint \
    --model sparringpartner \
    --endpoint-url https://dispatcher.example.invalid/v1 \
    --credential-env COMPATIBLE_API_KEY \
    --inference-api openai-completions \
    --sandbox testhermes01
)
```

**Substitute the same approved real hostname in both placeholders locally** and only when re-enrolling intentionally; omit this step when the provider already works. The temporary secret is not in the command-line arguments, config files or shell history; a secret in an exported process environment is still accessible to privileged local administrators. Upstream version changes or managed provider reconciliation may require the supported `onboard --resume` instead; that was the route used for the post-crash new sandbox, and **must not** be a generic restart action. Do not hand-edit OpenShell internal provider/policy files or `/sandbox/.hermes/config.yaml`. Do not print `gateway-token` or raw credentials.

**Remaining route check after start:** `nemohermes inference get`, then a harmless actual model-backed agent prompt, not just an anonymous 401. The owner did successfully create an HTML bouquet with the local alias, but the separate provider migration failure history remains recorded in [#80](https://github.com/SomeSunlight/ai-workstation/issues/80).

## Export Hermes' result without mounting Windows directories

From **AIW-Nemo's host shell**, not from inside Hermes:

```bash
mkdir -p "$HOME/aiw-preview"
# First check the file really exists in the CURRENT sandbox:
openshell sandbox exec -n testhermes01 -- ls -l /sandbox/bouquet.html

openshell sandbox download \
  testhermes01 \
  /sandbox/bouquet.html \
  "$HOME/aiw-preview/hermes-bouquet.html"

# Opens the trusted host folder in Windows; run after verifying the exported HTML:
explorer.exe "$(wslpath -w "$HOME/aiw-preview")"
```

The operator reported a pleasing, visually rotating bouquet generated locally in approximately 11 minutes, after using the `sparringpartner` alias. The exact absolute **`/sandbox/bouquet.html`** path was reported by Hermes. The export is a deliberate copy; agent never receives a host mount. **An HTML5 file may execute untrusted JavaScript in a Windows browser**, so inspect it before opening. The agent reported no external dependencies; its Node harness is not a browser security audit. Export and verify any wanted files/Git history before choosing `destroy` or `rebuild`.

## Boundary and escalation

- **No new local AIW service/supervisor.** Start/stop/launch/recover delegate to the pinned `nemohermes` CLI. NemoClaw/OpenShell manages gateway lifecycle, rootless Podman, all credentials, policy and forwarding.
- **No automatic `rebuild`, `destroy`, `onboard --resume`, Podman restart, broad network exception or installer on desktop click.** If a command fails, show the upstream error and this guide; do not silently guess a fix.
- **No global Windows WSL shutdown or native Windows sandbox execution.** Existing Windows Dispatcher/services and other Linux distributions remain independent.
- **No copying private data into public repository/PR.** Replace any real hosts, IPs, usernames, passwords, gateway tokens, receipt IDs and transcript snippets with safe examples before publishing.
- Future architecture split is separately tracked in [#78](https://github.com/SomeSunlight/ai-workstation/issues/78). General OpenShell integration direction [#71](https://github.com/SomeSunlight/ai-workstation/issues/71); platform install [#77](https://github.com/SomeSunlight/ai-workstation/issues/77). This issue only fixes the practical operator experience.

**Pinned upstream source:** [NVIDIA/NemoClaw commands](https://github.com/NVIDIA/NemoClaw/blob/82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f/docs/reference/commands.mdx) (launch/stop/start/status/recover), [provider switch](https://github.com/NVIDIA/NemoClaw/blob/82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f/docs/inference/switch-providers.mdx), [NVIDIA troubleshooting](https://github.com/NVIDIA/NemoClaw/blob/82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f/docs/reference/troubleshooting.mdx).