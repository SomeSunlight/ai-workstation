# OpenShell first flight — reproducible WSL/Goose operator runbook

**Evidence date:** 2026-11-13–14 · **research:** #68, #69 · **integration work:** #71.
**Observed versions:** NVIDIA OpenShell `v0.1.8`; Goose official OCI `v1.59.0`; Docker Engine **29.6.1** on Ubuntu 24.04 WSL2; cgroups v2, systemd user manager running. **OpenShell v0.1.8 WSL2 + Docker Desktop is experimental upstream; a Docker Engine *inside WSL* was tested successfully by one operator but is not a published upstream-qualified WSL driver.**

This is a **manual reference**, not an installer, integration layer or security certification. Commands were entered by the operator and worked in that test; the runbook is intentionally *not* executed in CI or on another host. It contains **no private hostname, API key, user name, host path, company configuration, generated token/receipt ID or public raw console logs**. Do not paste actual `sandbox get`/`logs` output publicly without privacy review.

## Safety boundaries and names

- **Run on the existing authorized WSL host only**, never automatically on a Windows inference host or an unapproved OS/VM. Runtime installation and privilege elevation need operator/device-policy approval.
- **Trusted/outside sandbox:** OpenShell CLI/gateway, Docker daemon, workspace backup/export target, Dispatcher identity registration. **Untrusted/inside:** Goose, development tools, arbitrary repos and agent subprocesses. No host home, Windows drive, original project, Docker socket or credential folder is bind-mounted.
- **Test sandboxes:** `aiw-p0-scratch` (stock/default policy), `aiw-p0-hardened` (strict Landlock policy), `aiw-goose-test` (official Goose OCI image, same strict policy). Never apply a generic Docker prune or remove them while active work is wanted.
- **Model route:** trusted dispatcher HTTPS endpoint is a deliberate egress path. Gateway-brokered credentials are **not** data-loss prevention for text/files/history accessible to the agent.
- **Replacement variables below:** the example `dispatcher.example.invalid` is a **placeholder only**; replace it locally with the approved DNS hostname and never commit a machine-specific value. Keep any model API key out of Git, chat, CLI argv, scripts and screen capture.

## 1 — Read-only prerequisites and initial capability check (observed)

From a WSL checkout of AI Workstation:

```bash
python3 -B tools/openshell_preflight.py
python3 -B tests/smoke/openshell-preflight.py

docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}}'
docker info --format 'OS={{.OperatingSystem}} | Cgroup={{.CgroupVersion}} | Security={{json .SecurityOptions}}'
systemctl --user is-system-running
docker context show

command -v openshell || true
dpkg-query -W openshell 2>/dev/null || true
ss -ltn '( sport = :17670 )'
```

Operator observed: 10/10 offline tests, no passive hard failure, Landlock ABI7 and seccomp USER_NOTIF action available, Docker client/server 29.6.1, cgroup v2, running systemd user manager. Kernel queries and Docker metadata **do not certify** security. In-WSL Docker rather than Docker Desktop was used.

## 2 — Pinned OpenShell installation / gateway (host-changing; already proven on the test host)

**Run only if currently absent, with explicit local authority.** The upstream installer installs an 84.7 MB Debian package (may invoke `sudo apt`), configures and enables/restarts the `openshell-gateway` **systemd user service**, registers local gateway and generates TLS material/state. Inspect before executing. Do **not** pipe a mutable upstream script straight into a shell.

```bash
curl -fLsS \
  https://raw.githubusercontent.com/NVIDIA/OpenShell/f3d976590d3eb1379690a2abaf0f0e26c21d487d/install.sh \
  -o /tmp/openshell-install-v0.1.8.sh

less /tmp/openshell-install-v0.1.8.sh

OPENSHELL_VERSION=v0.1.8 sh /tmp/openshell-install-v0.1.8.sh

openshell --version
openshell status
```

Observed: binary/daemon `0.1.8`, local HTTPS loopback gateway connected and authenticated via **mTLS**, without changing the existing Dispatcher or host Goose service. Release artifact checksum was verified by the pinned installer. Host package installation and service startup are **not** read-only. Do not rerun just to check status.

## 3 — Initial stock sandbox and persistence (observed)

```bash
openshell sandbox list

openshell sandbox create \
  --name aiw-p0-scratch \
  --detach \
  --cpu 1 \
  --memory 2Gi

openshell sandbox get aiw-p0-scratch
openshell sandbox exec -n aiw-p0-scratch -- id

openshell sandbox exec -n aiw-p0-scratch -- \
  sh -c 'printf "AIW-PERSISTENCE-OK\n" > .aiw-p0-canary && cat .aiw-p0-canary'

openshell sandbox stop aiw-p0-scratch
openshell sandbox start aiw-p0-scratch

openshell sandbox exec -n aiw-p0-scratch -- cat .aiw-p0-canary
```

Observed: `Ready`/supervisor connected, ordinary UID/GID 1000, test file persisted over stop/start. A stock sandbox's optional Landlock policy displayed `best_effort`; do **not** use that assumption for the strict agent profile.

## 4 — Explicit hard-requirement filesystem sandbox (observed)

A configuration file is created **outside** the untrusted sandbox by the operator:

```bash
cat > /tmp/aiw-p0-hard-policy.yaml <<'YAML'
version: 1
filesystem_policy:
  include_workdir: true
  read_only:
    - /bin
    - /usr
    - /lib
    - /proc
    - /dev/urandom
    - /etc
    - /var/log
  read_write:
    - /tmp
    - /dev/null
landlock:
  compatibility: hard_requirement
YAML

openshell sandbox create \
  --name aiw-p0-hardened \
  --policy /tmp/aiw-p0-hard-policy.yaml \
  --detach \
  --cpu 1 \
  --memory 2Gi

openshell sandbox get aiw-p0-hardened
openshell policy get aiw-p0-hardened --full
openshell sandbox exec -n aiw-p0-hardened -- id
```

Observed: second sandbox `Ready`, `openshell policy get --full` reported **Effective**, policy showed `compatibility: hard_requirement`; UID/GID 1000. This is a strict-configuration/real-admission success, **not a complete filesystem-escape proof**. Upstream's mandatory bootstrap Landlock baseline is separate from optional filesystem rules.

### Synthetic filesystem and network negatives (observed)

```bash
openshell sandbox exec -n aiw-p0-hardened -- sh -c '
  (: > /tmp/aiw-p3-canary) && echo "TMP: WRITABLE" || echo "TMP: DENIED"
  for p in /mnt/c /var/run/docker.sock /run/docker.sock; do
    if [ -e "$p" ] || [ -L "$p" ]; then
      echo "$p: VISIBLE"
    else
      echo "$p: NOT_VISIBLE"
    fi
  done
  if (: > /etc/aiw-p3-canary) 2>/dev/null; then
    echo "ETC: UNEXPECTEDLY WRITABLE"
  else
    echo "ETC: DENIED"
  fi
'

openshell sandbox exec -n aiw-p0-hardened -- \
  bash -c 'echo > /dev/tcp/1.1.1.1/443'

openshell logs aiw-p0-hardened --source sandbox --since 1h
```

Observed: `/tmp` writable; Windows `/mnt/c` and the two tested Docker-socket paths not visible; writing `/etc` denied (ordinary UNIX permissions could also contribute); direct IPv4 TCP/443 returned **`Permission denied`**. OpenShell's supervisor logged **`NET:OPEN DENIED`** with reason **`transparent_tcp_policy_denied`**, an attributable network-policy denial. Scratch sandbox also returned `Permission denied` for the same attempted TCP connection. Only this destination/protocol/path were tested; these results do *not* cover IPv6, UDP, DNS exfiltration, localhost/LAN, Windows interop, allowed-host redirects, other child binaries or policy revocation.

The first attempt to test HTTPS with `curl` in the stock shell sandbox did **not** actually make a request: `curl` was not installed. A tool-missing error is **not a security PASS**. Logs may contain generated instance IDs and operational details: share redacted excerpts only.

## 5 — Reproducible Goose OCI sandbox (observed)

The official aaif-goose/goose `v1.59.0` image contains Goose and Git; the initial stock shell image does not contain Goose, Git, Python3, uv or Node. Pull is a **host Docker operation** (adds a cached OCI image). The recorded manifest digest is public and useful for reproducibility; resolve and review digest for your actual architecture before using it as an immutable pin.

```bash
docker pull ghcr.io/aaif-goose/goose:v1.59.0
# Observed manifest digest:
# sha256:18e801642a134d3d3975b563ab6185593b53fac270167b1acbfb4368baca1c96

openshell sandbox create \
  --name aiw-goose-test \
  --from ghcr.io/aaif-goose/goose:v1.59.0 \
  --policy /tmp/aiw-p0-hard-policy.yaml \
  --detach \
  --cpu 1 \
  --memory 2Gi

openshell sandbox exec -n aiw-goose-test -- goose --version
openshell sandbox exec -n aiw-goose-test -- git --version
openshell sandbox get aiw-goose-test
```

Observed: Goose `1.59.0`, Git `2.39.5`, Ready, strict filesystem policy. **No host project mounts, existing Goose settings or secrets were copied.**

### Git history persisted across stop/start (observed)

```bash
openshell sandbox exec -n aiw-goose-test -- sh -c '
  set -eu
  mkdir -p aiw-workbench/demo
  cd aiw-workbench/demo
  git init -q
  echo "My first OpenShell workstation" > README.md
  git add README.md
  git -c user.name="Sandbox Test" \
      -c user.email="test@example.invalid" \
      commit -qm "Initial commit"
  GIT_PAGER=cat git log -1 --oneline
'

openshell sandbox stop aiw-goose-test
openshell sandbox start aiw-goose-test

openshell sandbox exec -n aiw-goose-test -- sh -c '
  cd aiw-workbench/demo
  GIT_PAGER=cat git log -1 --oneline
  cat README.md
'
```

Observed: same synthetic Git commit and README after stop/start. Use `q` to leave `git log`'s `less` pager if one appears; `GIT_PAGER=cat` avoids it. **Do not** infer data survival from `sandbox delete`, OCI image updates or WSL shutdown: those were not tested.

## 6 — Restricted provider and test credential (observed with a separately registered client)

First create a **separate revocable application key** on the authorized Dispatcher host, update its hash-only client registry and restart **only Dispatcher** to activate. Keep old clients untouched. The original key must never enter public files, terminal history, command arguments or this repository.

Create the following local profile **with your approved hostname substituted for the placeholder**; the hostname is **not** an API key. The version-specific shape below was accepted by `openshell profile lint`, `import` and `describe`.

```bash
cat > /tmp/aiw-dispatcher-profile.yaml <<'YAML'
id: aiw-dispatcher-test
display_name: AIW Dispatcher Test
description: Test-only OpenAI-compatible inference access
category: inference
inference_capable: true

credentials:
  - name: api_key
    env_vars: [OPENAI_API_KEY]
    required: true
    auth_style: bearer
    header_name: authorization

endpoints:
  - host: dispatcher.example.invalid  # REPLACE locally with approved HTTPS hostname
    port: 443
    path: /v1/chat/completions
    protocol: rest
    access: read-write
    enforcement: enforce

binaries:
  - /usr/local/bin/goose
YAML

# Edit only the placeholder hostname before continuing.
openshell profile lint -f /tmp/aiw-dispatcher-profile.yaml
openshell profile import -f /tmp/aiw-dispatcher-profile.yaml
openshell profile describe aiw-dispatcher-test
```

**Key entry:** run the next code in **Bash**, in a local WSL terminal without `set -x` or command recording. It reads the original into a short-lived, exported environment variable; `--credential OPENAI_API_KEY` asks OpenShell to look up that variable rather than passing the literal key as `KEY=secret` in process argv. This avoids common history/argument leaks but is *not* a guarantee against privileged process introspection.

```bash
(
  set +x
  IFS= read -r -s -p "Dispatcher test key: " OPENAI_API_KEY
  printf '\n'
  export OPENAI_API_KEY

  openshell provider create \
    --name aiw-dispatcher-goose-test \
    --type aiw-dispatcher-test \
    --credential OPENAI_API_KEY
)

openshell sandbox provider attach \
  aiw-goose-test aiw-dispatcher-goose-test --wait

openshell sandbox provider list aiw-goose-test
openshell policy get aiw-goose-test --full
```

Observed: `credentials=true, policy=true, future process environment=true, Wait: complete`; one provider credential attached. `enforcement: enforce` was declared in the profile. The operator tested an actual permitted model response next; OpenShell brokering does **not** eliminate the possibility of agent-readable data leaving through that permitted endpoint. **Do not** print the `OPENAI_API_KEY` value or publish full provider/log output.

## 7 — One model request through the approved Dispatcher (observed)

Replace `dispatcher.example.invalid` with the **same** approved hostname as in the imported profile. Keep the default network policy: no blanket Internet access.

```bash
openshell sandbox exec -n aiw-goose-test -- sh -c '
  if [ -z "$OPENAI_API_KEY" ]; then
    echo "ERROR: Provider credential placeholder missing"
    exit 1
  fi
  GOOSE_PROVIDER=openai \
  GOOSE_MODEL=agent \
  OPENAI_HOST=https://dispatcher.example.invalid \
  OPENAI_BASE_PATH=v1/chat/completions \
  goose run \
    --no-profile \
    --no-session \
    --max-turns 1 \
    --text "Antworte ausschliesslich mit dem Wort BEREIT. Keine Werkzeuge verwenden."
'
```

Observed: **BEREIT** from Goose with provider `openai` and model alias `agent`. Banner `new session` appeared even with `--no-session`; the latter requests no persistent session file, but this particular test did not independently verify the resulting session storage. Do not interpret this as a tested multi-turn session-resume guarantee.

## 8 — Real agent output, targeted export and interactive Goose (operator used; refine UX)

The operator requested a **single HTML5 file with a richly animated, swaying bouquet**, with no external assets. A bounded Goose invocation with explicitly enabled `developer` built-in created `bouquet.html` in the sandbox workspace. **Generated HTML/JS is untrusted code:** inspect it before executing in a host browser; standalone offline resources minimise, but do not eliminate, risk.

```bash
# A bounded repeatable agent task (writes ONLY inside sandbox):
openshell sandbox exec -n aiw-goose-test -- sh -c '
  cd aiw-workbench/demo || exit 1
  GOOSE_PROVIDER=openai \
  GOOSE_MODEL=agent \
  OPENAI_HOST=https://dispatcher.example.invalid \
  OPENAI_BASE_PATH=v1/chat/completions \
  goose run \
    --no-profile \
    --with-builtin developer \
    --max-turns 12 \
    --text "Create bouquet.html: one standalone animated HTML5 file, with CSS/JS, colorful swaying flowers, no external assets. Briefly confirm the file."
'

# Pull ONLY this file out to WSL (no host bind mount made visible to Goose):
mkdir -p ~/aiw-preview
openshell sandbox download \
  aiw-goose-test \
  aiw-workbench/demo/bouquet.html \
  ~/aiw-preview/

# From WSL, open the containing folder in Windows Explorer:
explorer.exe "$(wslpath -w "$HOME/aiw-preview")"
```

**Explicit export principle:** the transferred file is a *copy*. Further edits inside the sandbox require a deliberate re-download. Do not mount the Windows original project into an untrusted agent to avoid this step.

An interactive Goose session was then started with a trusted per-process provider/model setting and manually approved tool calls:

```bash
openshell sandbox exec -n aiw-goose-test --tty -- bash -lc '
  cd ~/aiw-workbench/demo || exit 1

  export GOOSE_PROVIDER=openai
  export GOOSE_MODEL=agent
  export OPENAI_HOST=https://dispatcher.example.invalid
  export OPENAI_BASE_PATH=v1/chat/completions
  export GOOSE_MODE=approve

  exec goose session \
    --name blumenstrauss \
    --no-profile \
    --with-builtin developer \
    --max-turns 20
'
```

**Open issue:** Interactive Goose showed **`loading extensions in background...`** and appeared stuck/very slow while the operator waited for an improved bouquet. This must be diagnosed in #71 (extension startup, missing toolchain, denied network and status behavior) *before* claiming reliable interactive autonomy. The official Goose image includes Git and curl but lacks a useful general development toolchain; stock OpenShell base image lacks even Git/Python/Node. A **reviewed prebuilt image** should add pinned Python3, uv, Node and other needed tools. Goose extension names/availability are not interchangeable with apt executables (`read` may denote a built-in tool or shell command, not a Linux package). Don't bypass the security policy by allowing arbitrary external downloads or apt/sudo in the non-root sandbox.

## 9 — Daily operations, diagnosis, cleanup and outstanding release gates

```bash
openshell status
openshell sandbox list
openshell sandbox get aiw-goose-test
openshell policy get aiw-goose-test --full

openshell sandbox stop aiw-goose-test
openshell sandbox start aiw-goose-test

# The last log buffer may be incomplete; review locally and sanitize before sharing:
openshell logs aiw-goose-test --source sandbox --since 1h
```

For **deliberate destruction of a named disposable test sandbox only**, after backing up anything valuable and confirming its name, the tested CLI family supports:

```bash
openshell sandbox delete aiw-p0-scratch
# Or explicitly delete aiw-p0-hardened / aiw-goose-test ONLY when their data is no longer needed.
```

**Do not execute deletion during a normal test handoff.** It is *not* a stop operation and may irreversibly discard private workspace/history. No `docker system prune`, volume reset or automated apt autoremove. If uninstalling OpenShell entirely is later approved, separately verify all test-only resources, service state and package ownership. Avoid generic deletion of the user's profile/configuration/data.

### After-flight cleanup — separate sandbox state from Docker images

**Important: the operator may still be using interactive Goose to refine the bouquet. Do not run these commands until that interaction is finished.** A test sandbox is *persistent private work*, not just a running process. **Stop/start preserves it; delete may destroy both its files and private Git history.**

1. **Inspect:** `openshell sandbox list`, `docker system df -v` (read-only). If a sandbox holds a result worth keeping, explicitly download the specific artifact(s), verify the files on the trusted host, and separately arrange any needed history/state backup *before* deleting it. The HTML file export above is only a partial backup; `bouquet.html` is not the whole workspace.
2. **Finish or exit** all interactive Goose sessions and confirm the three exact test-only names. Keep `aiw-goose-test` if there is still useful active work. Never delete it merely to improve a disk-space statistic.
3. **Targeted cleanup (operator approval only):**

```bash
openshell sandbox list

# Only when these exact named sandboxes are no longer needed:
openshell sandbox delete aiw-p0-scratch
openshell sandbox delete aiw-p0-hardened
openshell sandbox delete aiw-goose-test

openshell sandbox list
docker system df -v
```

The sandbox **deletion CLI family exists upstream but was not exercised in this first-flight research**. Review the actual list, errors, effects and surviving data before assuming every sandbox-owned filesystem volume was removed. A declined deletion or failed operation must be investigated, **not** followed by broad Docker prune.

4. **Do not automatically remove OCI images or Docker volumes.** Docker Engine is the required backend for the successful OpenShell sandbox driver. The pulled `ghcr.io/aaif-goose/goose:v1.59.0` image is a reusable base layer, *not* a second live Goose service. The OpenShell gateway/supervisor uses its own OCI/container resources. Meanwhile, the old AIW `compose/goose.yml` and the merged #65 named sandbox templates, their distinct images and **persistent volumes including `ai-workstation_goose-home`**, remain functional **legacy/fallback** machinery until a separately approved retirement. Open WebUI and unrelated OCI images remain independent and must not be affected.
5. **Only in a separate retirement decision** inventory each image's tag/digest, its actual consumers (including stopped containers), and all volumes/backup locations. Delete exact, unreferenced images through a reviewed operation; avoid `docker system prune`, `docker volume prune`, `docker compose down -v`, `apt autoremove` or other blanket cleanup commands. Container/sandbox removal and cached OCI image removal are different actions.
6. **Host-only local helper files** `/tmp/aiw-p0-hard-policy.yaml`, `/tmp/aiw-dispatcher-profile.yaml`, `/tmp/openshell-install-v0.1.8.sh` are separate from OpenShell's persisted provider and sandbox records. Keep/share the *nonsecret* policy through a reviewed config if needed. Never delete a host file thinking it revokes a provider/key; use the trusted OpenShell/Dispatcher revocation operations if retiring the identity.

**Outcome:** Test sandboxes and cached images can consume disk; removing test-owned sandboxes is a good end-of-flight practice, but **image pruning is not a substitute for identifying the source of space usage**, and deleting state is not a backup.

### What this flight proved — and what it did not

| Capability | Empirical result |
| --- | --- |
| Install v0.1.8 and authenticate local gateway | **PASS** |
| WSL Docker Engine non-root sandbox admission | **PASS, local experiment** |
| Optional Landlock `hard_requirement` accepted + effective policy | **PASS (configuration/observed admission)** |
| Synthetic file and one independent Git history over stop/start | **PASS** |
| Tested Windows drive / Docker-socket paths invisible; `/etc` write denied | **PASS limited observations** |
| Direct IPv4 TCP/443 denial, OpenShell attribution | **PASS for tested path** |
| Separate test provider, per-sandbox attach, real Goose/LLM answer | **PASS** |
| Independent HTML creation and targeted export | **PASS by operator report** |
| Interactive Goose extension readiness and broad toolchains | **NOT YET PASS** |
| Full Windows interop, DNS/UDP/IPv6/LAN/proxy/bypass, credential exfil negatives | **NOT TESTED** |
| WSL shutdown, gateway restart, image update/delete/recreate, portable backups | **NOT TESTED** |
| Corporate-wide security qualification / unrestricted autonomy | **NOT ESTABLISHED** |

**Decision:** **GO to an OpenShell-first, staged WSL integration** (#71); **not** blanket approval for untrusted arbitrary code with real data or broad autonomous external access. Keep merged #65 fallback and existing services/data untouched until a separately reviewed migration decision. Build the smallest useful integration rather than introducing a second sandbox factory, session catalogue or patch-promotion workflow.

### Primary references

- [NVIDIA OpenShell v0.1.8 support matrix](https://docs.nvidia.com/openshell/v0.1.8/about/support-matrix)
- [NVIDIA OpenShell v0.1.8 installation](https://docs.nvidia.com/openshell/v0.1.8/about/installation)
- [NVIDIA OpenShell security best practices](https://docs.nvidia.com/openshell/v0.1.8/security/best-practices)
- [NVIDIA OpenShell sandbox overview](https://docs.nvidia.com/openshell/v0.1.8/how-it-works/sandboxes/overview)
- [NVIDIA OpenShell provider API/inference](https://docs.nvidia.com/openshell/v0.1.8/how-it-works/inference)
- [Official Goose v1.59.0 Dockerfile](https://github.com/aaif-goose/goose/blob/v1.59.0/Dockerfile)
- [Goose v1.59.0 provider documentation](https://github.com/aaif-goose/goose/blob/v1.59.0/documentation/docs/getting-started/providers.md)
