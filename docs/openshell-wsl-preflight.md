# OpenShell on an existing WSL installation — research gate 1 (#68)

**Assessment:** 2026-11-13. **Decision: CONDITIONAL (not approved for deployment).**
**Upstream baseline:** NVIDIA OpenShell stable **v0.1.8**, published 2026-11-10;
immutable upstream Git tag commit
[`f3d976590d3eb1379690a2abaf0f0e26c21d487d`](https://github.com/NVIDIA/OpenShell/commit/f3d976590d3eb1379690a2abaf0f0e26c21d487d).
This assessment is a *source review*, not evidence that OpenShell runs securely
on the operator's particular WSL, nor permission to install it.

## Evidence model and driver decision

Labels below are deliberately different:

- **Documented:** an upstream statement for v0.1.8.
- **Implementation:** an inspected upstream source path at the v0.1.8 tag;
  this is not proof of behavior on this host.
- **Observed on this WSL:** **nothing**. The operator has **not** approved
  execution of the preflight; no host data has been collected.
- **Unverified:** active runtime behavior, environment specifics, policy
  permissions, or interactions with Windows.

| Question | Documented upstream | Implementation evidence | Observed on owner WSL | Unknown / next discriminator |
| --- | --- | --- | --- | --- |
| Host support | Debian/Ubuntu x86_64/arm64 supported; **Windows WSL2 + Docker Desktop x86_64 experimental**, not qualified supported Linux-on-WSL by inference [S1] | Published release tag [S0] | Not inspected | In-WSL Docker/Podman arrangement and enterprise support clearance |
| Driver | Docker supported (Docker Engine/Desktop **>=28.0**); Podman 5.x rootless with cgroups v2 and active user socket; MicroVM uses Linux KVM [S1, S3] | Docker gateway uses a Unix socket and default workload network=none [S3] | Not inspected | Existing approved backend, socket usability, systemd and install/daemon permissions |
| Sandbox bootstrap | Landlock **ABI >=3**, enabled LSM; seccomp nested user notification with atomic ADDFD/SEND; parent/child task-memory read; SO_BINDTODEVICE without added caps [S1] | Kernel ABI query [S7]; active notification/ADDFD probes [S8] | Not inspected | Container profile and real workload admission; passive checks alone insufficient |
| Other Linux controls | Unprivileged non-root process, **no Linux capabilities**, no_new_privs, Landlock, seccomp, namespaces, kernel-enforced filesystem [S2] | OpenShell's version-specific runtime source [S7, S8] | Not inspected | Namespace/mount and cgroup delegation, Windows host mounts, Docker privilege reachability |
| Network | Default deny at supervisor proxy/OPA plus driver outer fence [S2]; Docker workload network=none [S3] | Implementation not independently exercised here | Not inspected | Direct egress bypass, IPv4/IPv6/UDP/DNS/raw, host services, localhost/LAN |
| L7 policy | Inspected API traffic defaults to `enforcement: audit` (logs but **does not block**); set `enforce` [S2] | Not exercised | Not inspected | Effective policy via inspection and adversarial requests |
| Filesystem policy | Landlock private/bootstrap baseline is mandatory; additional filesystem policy defaults to `best_effort`, use `hard_requirement` for fail-closed [S2] | ABI detection in source [S7] | Not inspected | Enforced actual runtime policy, mounted filesystem and WSL drive visibility |
| Persistence | Gateway manages stop/start; driver-supported storage retained; restart does **not** preserve process memory/history [S4] | Not exercised | Not inspected | Image updates, filesystem, internal Git history, home/tools and backup/restore after WSL shutdown |
| Agents/workload | Agent runs in user-owned OCI image; CLI does **not** bundle agent tools [S1, S4] | Workload image customization is supported [S3, S4] | Not inspected | Goose/Hermes, subagents/MCP, uv/Node/Rust/C++, build cache and private volumes |

**Working driver choice:** Use `docker` *only if* the operator already has an
authorized, compatible Docker service and v0.1.8 qualification passes. The
documented WSL profile uses **Docker Desktop**, which is experimental and
may itself be prohibited. An Engine inside WSL is **not documented as a
qualified WSL variant**, even though the Docker driver supports Linux Docker
Engine generally. Rootless `podman` is a separate theoretical option with
its own user-service/cgroup/network requirements; do not silently install,
enable or switch it. A `vm` driver requires **KVM** and is outside this
gate: **never require /dev/kvm for the Docker/Podman driver**.

## Installation and local-service footprint (not authorized)

The v0.1.8 Linux CLI is a static musl build; the standalone Linux gateway
binary requires **glibc >= 2.28** [S1]. The upstream Linux installer selects
a Debian/Ubuntu package or RPM and **starts a systemd user gateway service**
(listening on the loopback gateway endpoint) [S6]. It is emphatically
**not** a read-only compatibility check. Package-manager rights, user-service
availability, a gateway-managed local configuration/state location,
downloaded trusted supervisor/runtime images, and access to the chosen
container engine must all be reviewed. Some steps may require corporate
administrator authorization even if the final workload runs non-root.
A standalone binary/manual package path changes bootstrap mechanics but
does not waive runtime qualification or corporate permissions. No such
install, user service start/stop, image pull, daemon access or configuration
change is part of this gate.

## Security boundary to prove, not assume

1. **WSL/Windows adjacency:** WSL's host integration is a meaningful threat
   boundary. Check Windows drive automounts (e.g. `/mnt/c`), executable
   interop, WSL and Windows shared host services, localhost forwarding,
   host/LAN networking and DNS only *after* separate approval for the
   practical gate. A Linux Docker namespace does not automatically prove
   Windows-host isolation; parent WSL compromise remains outside a
   workload-sandbox guarantee. The passive script intentionally never reads
   mount tables, enumerates routes, runs Windows executables or tests connectivity.
2. **Daemon/socket and mounts:** A Docker API socket is powerful authority.
   Socket presence is neither daemon usability nor permission to use it.
   Never delegate Docker/Podman control sockets, Windows mounts or private
   host projects to an untrusted workload. OpenShell's opt-in Docker bind
   mounts can expose host files and bypass the expected workspace isolation
   [S3]. Network namespace, seccomp and Landlock cannot compensate for
   explicitly overbroad host mounts.
3. **Network:** Network default deny depends on correct *effective* gateway
   policy and a functioning driver outer fence. Inspect the actual proxy
   rules, binary identity pins, DNS resolution, IPv4/IPv6/UDP/raw behavior,
   local services and allowed routes in an explicitly authorized disposable
   workload. A successful HTTP proxy test is not proof that direct socket
   egress is impossible. L7 `audit` is not enforcement. Weak wildcard
   binary scope, `tls: skip`, permissive network endpoints and optional
   filesystem policies can reduce protection [S2].
4. **Secrets:** The trusted supervisor can substitute credential placeholders
   and keep provider secrets out of the workload. This is **not DLP**:
   workspace secrets, old Git history and research data already readable by
   the agent can leave via any approved network or inference endpoint.
   Inspect injection/log/argv/env behavior only with fake credentials and
   redacted observations. A Windows inference service is an explicitly
   authorized egress destination **only by operator policy**, not a trusted
   sink for arbitrary data. OpenShell security guarantees do not imply that
   separate AIW or Windows host components are protected from a compromised
   outer WSL host.
5. **Fail closed:** Do not confuse the passive Landlock VERSION query or
   seccomp `GET_ACTION_AVAIL` with the upstream active admission probes.
   OpenShell must successfully test nested USER_NOTIF + ADDFD/SEND under
   the real container profile, same-UID child-memory reading and
   SO_BINDTODEVICE with no elevated capabilities [S1, S8]. No passive
   output can establish those properties.

## Autonomy and persistence tradeoff

OpenShell intentionally runs untrusted agent workloads as **non-root**, with
protected `/usr`, `/etc` and other system paths. Do **not** promise
arbitrary sudo/apt mutation of system directories inside the workload.
Prefer an approved version-pinned OCI image plus user-space toolchains,
virtual environments, user-owned caches and workspace installs for Goose,
Hermes, MCP subprocesses, Python/uv, Node, Rust and C++ compilers.
This is a deliberate limitation, not an AIW environment-catalog feature.

Each long-lived sandbox should own arbitrary independent repositories and Git
history, not merely a patch of one registered host project. Verify
persistence of workspace, agent state and user-space tools across
**stop/start**; what the driver keeps after gateway restart/WSL shutdown;
**delete/recreate** semantics; image version replacement; and explicit
independent export/backup/restore. In v0.1.8 an image update is a distinct
operator-enabled stopped-sandbox operation and does not automatically
rewrite existing persistent workspace content [S4]. Never assume backups
from persistent volumes are automatic. No migration of existing Goose/AIW
volumes is within #68.

## Preflight: default is passive and local

`tools/openshell_preflight.py` uses only Python's standard library.
It never imports OpenShell or invokes Docker, Podman, WSL, sudo, apt, a
shell, a Windows executable or a network service. No output is uploaded,
posted or saved. It does not modify any host configuration. In **passive**
mode it reads only `/etc/os-release` and `/proc/self/status`, examines
fixed public capability locations by metadata, and issues two non-installing
kernel queries: `landlock_create_ruleset(..., VERSION)` to request ABI;
`seccomp(GET_ACTION_AVAIL, SECCOMP_RET_USER_NOTIF)` to ask whether a
notification action is available. These are **not** syscall filter installs
or an attempt to create an OpenShell workload.

Every finding has `PASS`, `FAIL`, `UNKNOWN`, or
`POLICY-APPROVAL-NEEDED` status. `PASS` applies only to the explicitly
named local observation; a runtime isolation check can remain `UNKNOWN`.
`FAIL` on a hard requirement leads to a passive `BLOCKED` report, but
this is diagnostic, not a final OpenShell NO-GO without investigating whether
the query was blocked. Otherwise the verdict is `INCOMPLETE`. The report
**never** sets `compatibility_certified` to true. Output is allowlisted:
OS/distro class, numeric kernel major/minor, architecture, check IDs and
limited status labels. It does not output username, host name, IP, path,
environment, command line, mount list, socket ownership or raw error/log.
The JSON includes schema and upstream release version, but deliberately
no timestamps or telemetry.

**Safe without any host probing (synthetic fixture, for review):**

```sh
python3 -B tools/openshell_preflight.py --example
python3 -B tools/openshell_preflight.py --example --json
python3 -B tests/smoke/openshell-preflight.py
```

All three commands are appropriate **only in a review checkout or disposable
development environment** before the owner approves running any script on
the laptop. The example report is fixed, synthetic input; do not present it
as real host evidence. The focused unit tests mock kernel queries, exercise
redaction, known FAIL/UNKNOWN handling and show that example mode never
reads host files.

**Commands reserved for separate explicit permission on the laptop,
NOT executed for #68:**

```sh
python3 -B tools/openshell_preflight.py
python3 -B tools/openshell_preflight.py --json
```

Sample *synthetic* human excerpt:

```text
OpenShell v0.1.8 read-only preflight [example]
Passive verdict: INCOMPLETE (NOT an OpenShell compatibility certificate)
  linux_host: PASS (linux)
  landlock_abi: PASS (abi-5)
  seccomp_user_notif_action: PASS (action-available)
  seccomp_runtime_enforcement: UNKNOWN (caller-filtered)
  task_memory_access: UNKNOWN (not-probed)
  socket_bind_to_device: UNKNOWN (not-probed)
  runtime_install_approval: POLICY-APPROVAL-NEEDED (not-checked)
```

Do not publish actual outputs automatically. Even sanitized real reports
require an operator privacy review before copying into a public issue.

## Decision record: CONDITIONAL

**Not GO:** v0.1.8 does **not** certify the existing WSL installation. Its
Windows profile is experimental and specifies Docker Desktop. Specific
run-time seccomp/Landlock functionality and safe WSL/Windows separation
remain unobserved, and enterprise permission for an OpenShell
gateway/daemon is not established.

**Not a proven NO-GO:** no concrete incompatibility has yet been measured
on the owner WSL. A compatible pre-existing daemon might allow an
operator-approved Docker-driver experiment, but no engine switch or
installation is assumed.

**Exact conditions to reconsider:** (1) operator approves collecting the
passive local report; (2) privacy-reviewed results reveal no hard blocker;
(3) authorized container driver and enterprise policy approval are stated;
(4) an *independent* practical gate is explicitly unlocked by the owner;
(5) disposable adversarial trials pass upstream's full active runtime
qualification, credential and network/Windows-boundary tests, plus
persistence/recovery. A passive PASS never authorizes those trials.

**Maintenance:** pin OpenShell CLI, gateway, supervisor/runtime, images
and policies to a reviewed stable release or immutable digest; validate
the complete version set together, review release migration notes, run
preflight before upgrades, and design tested backups/rollback. OpenShell
publishes about weekly and maintains security fixes on the newest and
previous minor releases at their newest patch [S1]. Check upstream
[security advisories](https://github.com/NVIDIA/OpenShell/security/advisories)
and fixes before *any* deployment. CNCF participation and stable release
qualification are **not** certification of this WSL threat model.
NVIDIA's [August 2026 OpenShell security bulletin](https://github.com/NVIDIA/product-security/blob/main/2026/5872/5872.md)
lists critical vulnerabilities including CVE-2026-65093 (sandbox escape)
and CVE-2026-65083 (sandbox provisioning input validation) affecting OpenShell
up through v0.0.33 and identifies **v0.0.34** as the fixed release.
The reviewed v0.1.8 is later than that fix, but this does **not** establish
the absence of newer vulnerabilities. Check current upstream advisories and
security notices at deployment and on every update.

**Fallback:** retain merged PR #65 behavior unchanged until a replacement
has passed both gates. Existing Docker workspace review is useful for
operator-owned project changes, but must **not** be described as hostile
code containment, credential exfiltration prevention, or enterprise-policy
approval. Do not create custom AIW enforcement, credential brokers, a
sandbox policy engine or a second operating system/VM as a workaround.
Issue #69 stays blocked. No live changes were performed.

## Primary sources inspected (all checked 2026-11-13)

- **[S0]** [OpenShell v0.1.8 release/tag](https://github.com/NVIDIA/OpenShell/releases/tag/v0.1.8),
  commit `f3d976590d3eb1379690a2abaf0f0e26c21d487d`.
- **[S1]** [Support matrix v0.1.8](https://docs.nvidia.com/openshell/v0.1.8/about/support-matrix):
  platforms, runtime prerequisites, Landlock, seccomp/ADDFD, task memory,
  SO_BINDTODEVICE, release/update policy.
- **[S2]** [Security best practices v0.1.8](https://docs.nvidia.com/openshell/v0.1.8/security/best-practices):
  default deny, L4 vs L7, audit/enforce, credentials, mandatory and optional
  Landlock, non-root/no caps, mounts and policy risks.
- **[S3]** [Compute drivers v0.1.8](https://docs.nvidia.com/openshell/v0.1.8/how-it-works/sandboxes/runtimes):
  Docker, rootless Podman, VM/KVM, process restart and volumes.
- **[S4]** [Manage sandboxes v0.1.8](https://docs.nvidia.com/openshell/v0.1.8/how-it-works/sandboxes/overview):
  stop/start/delete, image update, workspace transfer.
- **[S5]** [Architecture v0.1.8](https://docs.nvidia.com/openshell/v0.1.8/about/architecture):
  trusted gateway/supervisor vs untrusted sandbox.
- **[S6]** [Installation v0.1.8](https://docs.nvidia.com/openshell/v0.1.8/about/installation):
  installation is intentionally **not** undertaken in this gate.
- **[S7]** [Pinned Landlock source](https://github.com/NVIDIA/OpenShell/blob/v0.1.8/crates/openshell-sandbox/src/linux/landlock.rs):
  ABI VERSION kernel query.
- **[S8]** [Pinned seccomp notification source](https://github.com/NVIDIA/OpenShell/blob/v0.1.8/crates/openshell-sandbox/src/linux/seccomp_notify.rs):
  notification and ADDFD/SEND qualification code.

**Source-review limitation:** statements marked *documented* are upstream
claims, not independently replicated host tests. This research does not
promote a currently unsupported WSL variant to a qualified deployment.
