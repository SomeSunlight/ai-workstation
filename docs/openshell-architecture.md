# ADR — OpenShell owns the agent workstation; AIW stays thin

**Status:** proposed for owner review (Issue [#71](https://github.com/SomeSunlight/ai-workstation/issues/71)).
**Baseline:** [research gate #68](https://github.com/SomeSunlight/ai-workstation/issues/68), [operator flight #69](https://github.com/SomeSunlight/ai-workstation/issues/69), and the [tested-command runbook](openshell-hands-on.md) from merged PR #72. This ADR precedes any migration or deprecation.

## Decision

For **new Linux/WSL agent workstations**, use NVIDIA OpenShell as the external lifecycle, persistence, filesystem/network-security and credential-provider runtime. Keep AIW to a small, *optional* adapter to the upstream `openshell` CLI: readable workstation titles, create/choose, start/stop, Goose launch, explicit import/export, status/help and later backup/restore. The adapter must not implement a separate session database, security broker, gateway, firewall, policy engine, project diff/promoter, OCI image catalogue or supervisor. The upstream sandbox is a persistent private computer, **not a temporary patch candidate**.

The **first implementation slice** provides `aiw workstations` on Linux/WSL and a top-level menu entry. It is opt-in, creates no resources on installation, and does not configure or run the local gateway. OpenShell keeps its own sandbox names and metadata; a user chooses a **title**, not an internal ID. AIW stores a stable human title as an OpenShell annotation and marks its own workstations with an OpenShell label, without creating an additional persisted registry. Existing unlabeled research sandboxes are not silently adopted or destroyed. If the expected CLI metadata/schema is incompatible, the adapter fails closed rather than guessing.

## Ownership and boundaries

| Owner | Responsibility |
| --- | --- |
| **OpenShell** | Sandbox create/start/stop/exec/upload/download, private persistent filesystem, upstream supervisor/gateway, effective policy admission, provider mediation |
| **Docker Engine (trusted WSL host)** | OpenShell's tested OCI runtime, pinned base-image cache, containers/volumes owned by their respective systems |
| **AIW** | Human-title selection, minimal menu/CLI forwarding, user-directed transfers and concise warnings/diagnostics; *not* policy enforcement |
| **Trusted operator** | Approve OpenShell installation, reviewed strict policy, pinned image digest, endpoint/provider and separate revocable credential, host files and backups |
| **Goose in sandbox** | Its own sessions/history, arbitrary work, tools, processes and multiple independent Git repositories under a private writable area |
| **Original Linux project** | Remains outside the sandbox. No host project, WSL drive, host home or Docker socket bind mount enters the workload |

No new privileged host services, inference-host changes or second WSL installation are authorized. The tested host was **Ubuntu 24.04 on existing WSL2 with in-WSL Docker Engine**, using **OpenShell 0.1.8** and official **Goose 1.59.0**. This combination is one operator's empirical success, **not** an upstream-qualified WSL configuration or complete hostile-code isolation certification. The first adapter pins the tested OpenShell CLI and Goose OCI manifest digest `sha256:18e801642a134d3d3975b563ab6185593b53fac270167b1acbfb4368baca1c96`; later upgrades need explicit compatibility review.

Strict operator-reviewed OpenShell policy (including `landlock.compatibility: hard_requirement`) and a separately attached brokered inference provider are prerequisites to meaningful Goose operation. AIW does **not** manufacture, weaken or certify them. An approved model endpoint is an intentional data-egress route: brokering a secret is **not** data-loss prevention.

## Workstation and data lifecycle

- **Create:** choose a human title and a readable network choice. The default is the bundled strict policy, not a requested YAML path. A specific website produces a short-lived derived OpenShell policy; flexible mode uses OpenShell's automatic policy-advisor approval (NOT unrestricted Internet). Type `CREATE`, or `ALLOW` for the riskier flexible mode. Experts may explicitly supply a custom policy file. The adapter neither installs an image explicitly nor registers a provider; missing OpenShell prerequisites fail without silent changes.
- **Start / continue:** reuse the same persistent sandbox, and optionally enter an interactive Goose session or development shell. Interactive Goose's `loading extensions in background...` stall and missing Python/uv/Node tooling remain unresolved; they must not be declared functional by the mere ability to launch the process.
- **Import source:** select an **existing registered Linux project folder** and type `COPY`; OpenShell uploads a **complete independent copy**, including `.git` and ignored files, without mounting the original. It refuses an already existing destination basename instead of silently merging or overwriting. This can also copy hidden credentials or sensitive Git history. Until remaining exfiltration tests are approved, use **synthetic/nonconfidential source data only**.
- **Export result:** choose an explicit sandbox-relative file/folder and a **new** trusted Linux destination; type `EXPORT`. The adapter rejects traversal, existing destinations and WSL-mounted targets. Transferred content is untrusted and must be inspected. This is not automatic sync and not a backup. CLI-native upload/download remain the transfer authority.
- **Stop:** explicitly type `STOP`. The real first flight proved sample files and one Git history surviving sandbox stop/start. It did **not** establish survival of WSL shutdown, delete/recreate, OCI upgrade, full conversation history or off-host backup/restore.
- **Delete / backup / restore / migration:** **not provided** by this first adapter. Deletion is intentionally absent. For later releases, require a tested, verifiable complete workspace+Git+Goose-state backup, safe restore, named deletion guard, and separate operator approval. Container-image cache, sandbox state and legacy named Docker volumes are not interchangeable.

A long-lived workstation may contain **several unrelated Git repositories**, builds and user-space installations. Future offline toolchains should be delivered as reviewed/pinned OCI images with persistent user-space state, not AIW environment revisions or an agent `sudo apt` escape route. Prefer an agent-neutral shared operator menu for later Hermes support; packaging/provider integration must be independently demonstrated.

## Operator entry points (only after separate host authorization)

```text
aiw
  8) Goose work areas (OpenShell)
```

The workstations menu shows numbered **titles**. The advanced CLI also accepts exact titles:

```bash
aiw workstations list
aiw workstations create "Explore Project"  # bundled restrictive policy
aiw workstations create "Public docs" --profile website --website https://docs.python.org/3/
aiw workstations create "Flexible research" --profile flexible
aiw workstations import-project "Explore Project" registered-project
aiw workstations goose "Explore Project" --endpoint https://dispatcher.example.invalid --session work --directory registered-project
aiw workstations export "Explore Project" project/result.html "$HOME/aiw-export/new-result.html"
aiw workstations stop "Explore Project"
```

See [OpenShell network choices and safety warnings](openshell-network-profiles.md). Flexible web is **not** a verified all-Internet grant.

`dispatcher.example.invalid` is an intentionally invalid example hostname. Substitute the approved local HTTPS origin only on the operator's machine; do **not** commit secrets, actual hostnames or local provider files. Create the destination parent directory manually before export, attach/review the trusted OpenShell provider separately, and do not assume the command sequence above was executed in the first PR. For the manually tested OpenShell setup and restricted provider procedure, consult [the first-flight runbook](openshell-hands-on.md). Advanced titles map to upstream names internally; users should not need to memorize them.

## Fallback, migration and remaining gates

Keep **all** existing Windows inference services, native Goose config/history, Docker Compose Goose and #65 sandbox images/volumes/projects untouched. Old AIW workspaces/candidates and environment promotions are a *legacy fallback*, not a dependency of OpenShell or a target to recreate. No automatic legacy transfer or data retirement; eventually review ownership, consumers and independently verified backups before separately approving a reversible migration and destructive cleanup.

Independent review slices after this ADR/adapter:

1. **Practical Goose:** diagnose extension loading, review official packaging and pin an offline-capable Goose+Git+Python/uv/Node/toolchain OCI base. Test interactive sessions, permissions, subtools and at least two independent Git histories.
2. **Security and recovery:** broaden WSL/Windows interop, socket, DNS/UDP/IPv6, localhost/LAN, redirect/proxy/other-process, policy-revocation, credential and inference-egress negatives. Test WSL shutdown, gateway restart, upgrades, complete backup/restore and specifically named disposal. Do not claim unrestricted unattended autonomy until these are accepted.
3. **UX and compatibility:** refine menu based on operator flight, verified status/policy display, clear backup and specific deletion safeguard; prototype Hermes using the same menu; decide if/how to retire #59/#64/#66/#67 semantics and #65 fallback. Native Linux [#33](https://github.com/SomeSunlight/ai-workstation/issues/33) and further host-placement [#52](https://github.com/SomeSunlight/ai-workstation/issues/52) remain separate decisions.

**Source context:** current `CONTEXT.src.md` still contains an older default disposable-session/promotion assumption. It is intentionally *not* rewritten in this first PR: after operator approval of this ADR, update the authorized source, then regenerate/check with pinned ContextCanon. Do not hand-edit generated `CONTEXT.md` or `AGENTS.md`.
