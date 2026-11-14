# Goose work areas: network choices and risk

Issue [#71](https://github.com/SomeSunlight/ai-workstation/issues/71) · OpenShell **0.1.8** · First owner-tested host: Ubuntu 24.04 in WSL2 with Docker Engine inside WSL.

## What is a Goose work area?

It is **one persistent OpenShell sandbox**: a private Linux workspace with its own files, independent Git repositories, development tools and potentially many Goose **conversations**. This is not a Goose chat/session. The files observed in the research test survived OpenShell stop/start; complete backup, WSL reboot, image upgrades, delete/recreate and conversations remain **untested**. The same OpenShell sandbox must not mount a trusted host project or Docker socket. The Windows inference host is unrelated to this menu.

Open `aiw` → **8) Goose work areas (OpenShell)** → **Create a new Goose work area**. Supply a title, e.g. `OpenShellGooseTest01`, and select a *network choice*. **No YAML file is required**, no extra AIW catalogue is created, and nothing is installed in WSL until you actually approve a sandbox creation. OpenShell remains the trusted policy authority.

## The three choices

| Choice | Behavior and intended use | Risk/limitation |
| --- | --- | --- |
| **Protected — recommended** | Bundled, **strict** policy matching the #69 operator test: writable sandbox working directory and `/tmp`, readonly system paths, `landlock.compatibility: hard_requirement`, **no general outbound network policy**. | Separately attached inference providers can extend effective networking. Goose still needs an operator-configured, restricted provider/model route; the policy is not a full security certificate. |
| **One HTTPS website** | Same strict filesystem restrictions, plus an OpenShell network rule for **one public DNS host on port 443**, with HTTP `GET`/`HEAD`/`OPTIONS` and `enforcement: enforce`, scoped to Goose, curl and Git executable paths. | This permits downloads from **the entire host**, not only the pasted URL path. Other subdomains, redirect destinations, and non-GET methods are not automatically included. Some development toolchains/binaries may not yet exist or have different actual executable paths. |
| **Flexible web — experimental** | Same strict filesystem restrictions, but set OpenShell's **per-sandbox policy-advisor `--approval-mode auto`**. OpenShell can automatically approve low-risk proposals for public websites when a compatible agent proposes them. | **This is NOT unrestricted Internet.** Flagged/private/unsafe destinations can still require manual approval or fail. A tool must submit proposals; the official Goose image's developer extension/approval behavior is not yet validated. The administrator's global manual mode can override this mode. This grants potential outbound data channels without each review; use only synthetic data pending safety acceptance. |

**There is deliberately no "Internet completely unrestricted" preset.** In OpenShell 0.1.8, the policy engine requires destination/port and executable-specific authorization, and even broad hostless policies are subject to network exclusions and transport limits. It would be misleading to label an unverified policy "full Internet", or to disable OpenShell's network mediation to simulate such a profile. More permissive network policy and user-approved hostlists can be evaluated separately after operator tests; do not silently change the gateway's security posture. See the upstream [network rules](https://docs.nvidia.com/openshell/v0.1.8/how-it-works/policies/network-rules), [policy schema](https://docs.nvidia.com/openshell/v0.1.8/how-it-works/policies/schema) and [policy advisor](https://docs.nvidia.com/openshell/v0.1.8/how-it-works/policies/advisor).

## For users who need a custom policy

The built-in restrictive YAML lives at `config/openshell/policies/restricted.yaml` in the AIW repository, **not** in a temporary personal directory. AIW uses that file directly; no persistent policy management exists. For "one website" AIW creates a temporary derived YAML while invoking upstream OpenShell, and deletes the local temporary file after success/error. The effective policy remains with OpenShell.

For advanced users only:
```bash
aiw workstations create "My Goose work area"             # restricted preset
aiw workstations create "Docs research" --profile website --website https://docs.python.org/3/
aiw workstations create "Experimental web" --profile flexible
aiw workstations create "Review my own policy" --policy /path/to/reviewed.yaml
```

Both flexible and custom policies still need a trusted operator review. On new creation, AIW records only a non-secret initial profile label in OpenShell metadata. **That label is not proof of the current policy**: provider attachments and policy changes may alter the effective privileges. Review locally with:
```bash
openshell policy get <exact-open-shell-sandbox-name> --full
openshell policy list <exact-open-shell-sandbox-name>
```
OpenShell's explicit CLI stays available for advanced inspection; AIW does not replicate its security engine.

### Safety warnings

- A separate, strictly scoped **provider** is still necessary for inference. Enabling website access alone does not register the Dispatcher key or make interactive Goose ready. Credentials are never provided in public policy files.
- Provider mediation prevents direct exposure of certain credentials, **not exfiltration**: the agent may send files, old Git secrets or conversations through *approved* inference/public endpoints. Do not import private company repos into the experimental sandbox until negative security tests pass.
- `landlock.compatibility: hard_requirement` improves filesystem admission but does not make shared WSL kernel + Docker a VM-grade boundary. WSL itself is not a hostile-code security boundary.
- Developer tools (Python, Node, uv) are still missing from the first Goose OCI image. Network allowances cannot install missing local binaries without a reviewed image or user-space setup.
- The offline test suite checks **generated arguments and policy content**, not effective OpenShell admission, actual request routing, provider overlap, credential hiding, reboot resilience or a malware-scanning result. A real WSL flight needs explicit owner approval before making claims.

### Antivirus and downloaded files

Windows antivirus must not be assumed to scan files inside WSL2 or a Linux container, and installing an antivirus **inside Goose's untrusted sandbox** would not establish reliable protection. Kaspersky offers Linux products, but WSL2 kernel/real-time protection, license applicability and sandbox isolation need independent vendor confirmation. A later optional **trusted-host scan-on-export** adapter (or a download staging/approval gate) can use a locally installed, approved scanner. That scan must fail clearly on scanner-not-installed, unknown status or detection; it must not imply that downloaded scripts, dependencies or binaries are safe to execute merely because a signature scan passes.

See [optional antivirus scan-on-transfer research #74](https://github.com/SomeSunlight/ai-workstation/issues/74) before assuming Kaspersky covers WSL2 or OpenShell's private files.

### Related

- [Architecture ADR](openshell-architecture.md) — upstream ownership, persistent data, migration boundaries.
- [Tested first-flight runbook](openshell-hands-on.md) — operator-verified old manual commands; temporary policy from research is not required for normal menu use.
- [Issue #71](https://github.com/SomeSunlight/ai-workstation/issues/71) — remaining security, backup and tooling gates.
