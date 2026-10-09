# ai-workstation — Local Context Source
<!-- ctx:node id="aea56adf-2a26-43f0-b712-3bbeab7a3097" name="ai-workstation" version="0.2.0" adapters="agents,goose" -->

<!-- contextcanon:format Node
Format: Node metadata follows the # title: ctx:node id="..." name="..." version="...". Preserve existing identity.
Details: CONTEXT-format.md
-->

<!-- contextcanon:source-help:intro:start -->
Edit this local Context source; ContextCanon generates CONTEXT.md from it.
Some sections use a strict syntax. The comments below show the expected format.
New Rules, Topics and Resources receive IDs automatically during build; preserve existing IDs.
See [the source format guide](CONTEXT-format.md) for examples and editing instructions.
<!-- contextcanon:source-help:intro:end -->

## Context Imports

<!-- contextcanon:format Context Imports
Format: - [Name](location) — `version` — `relationship=parent|reference`; optional indented Why:, then ctx:source metadata. Preserve exact pins; use source list/adopt/update for package identity.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-sources:start -->
- [Development Workflow](https://github.com/SomeSunlight/context-canon.git) — `0.3.0-draft` — `relationship=parent`
  Why: We want to use the same successful development workflow from context-canon for this project too. Feel free to use also other workflowss, if you like. Then put it here.
  <!-- ctx:source id="c4c94726-3cc7-4df6-b779-72bbf9c06f40" version="0.3.0-draft" transport="git" ref="c213d4d492464265ff96ffb4b111193cdcf5662d" node-path="nodes/library/development-workflow" normalized-digest="0ca4b977665a971dcb068c22342d6d7904e5f03a078a6c58b66fe5af3328be79" package-digest="6b2694121e5c69ed772e9b9fde7e15e71f97444a13b2f1f808190e4f7eabe0cb" -->
<!-- contextcanon-placement-sources:end -->

## Local Overview

<!-- contextcanon:format Local Overview
Format: Ordinary Markdown orientation, local to this Node. Any existing placement identity follows its paragraph/item; do not change it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-overview:start -->
- AI Workstation is a reproducible workstation built from Windows/WSL bootstrap, Linux host configuration, and containerized application runtimes.
  <!-- cc:placement-overview id="ONB-468CE58AC863" -->
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon:format Local State
Format: Ordinary Markdown describing the current local situation. Any existing placement identity follows its paragraph/item; preserve it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-state:start -->
- Supported Windows host: Windows 11 with current Store WSL.
  <!-- cc:placement-state id="ONB-AF4EE42CF15A" -->

- Supported PowerShell: 7.4 or newer.
  <!-- cc:placement-state id="ONB-081E84B6F644" -->

- Supported Linux guest: Ubuntu 24.04 under WSL 2.
  <!-- cc:placement-state id="ONB-0022686FB5D8" -->

- Supported architecture: x86-64 on both Windows and WSL.
  <!-- cc:placement-state id="ONB-9699C06578AD" -->
<!-- contextcanon-placement-state:end -->

## Local Rules

<!-- contextcanon:format Local Rules
Format: ### Group, then - **Title:** Statement, then indented Why: Rationale. build adds a missing ctx:rule ID after the entry; preserve existing IDs.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Repository is the installation specification:** The repository is the installation specification; running containers and manually modified hosts are not the source of truth.
  Why: Prevents runtime or host drift from becoming an implicit configuration authority.
  <!-- ctx:rule id="ONB-6566E6E85D48" -->

- **Develop inside the WSL filesystem:** Work inside the WSL Linux filesystem, not under `/mnt/c`.
  Why: Keeps development on the Linux filesystem the project expects.
  <!-- ctx:rule id="ONB-504C6A92475F" -->

- **Keep versions documentation and tests aligned:** Update `config/versions.json`, documentation and tests together.
  Why: Keeps declared versions, human guidance and validation in sync.
  <!-- ctx:rule id="ONB-02E2C1B8C47B" -->

- **Run release check before committing:** Run `./tools/release-check.sh` before committing.
  Why: Provides the project-defined pre-commit validation step.
  <!-- ctx:rule id="ONB-BE08FE3A5E3D" -->

- **Keep secrets out of Git images and Compose:** Secrets must not be committed, copied into images or stored in Compose files.
  Why: Keeps credentials out of durable repository history and built artifacts.
  <!-- ctx:rule id="ONB-DCF5EB952F7D" -->
<!-- contextcanon-placement-rules:end -->

## Local Topics

<!-- contextcanon:format Local Topics
Format: ### Title, condition text, Required: and/or Optional:, then - Resource: `path` or - Context Node: `node-path`. Resource may have indented Why:. build adds missing Topic/Resource IDs after their entries; preserve existing IDs.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-topics:start -->
### Security reporting resource

When reporting a vulnerability or checking the project security-reporting procedure, read the security document.

Required:
- Resource: `SECURITY.md`
  <!-- ctx:resource id="RESOURCE-B06EC8C816F4" -->

<!-- ctx:topic id="ONB-FA47F00F43A9" -->

### Troubleshooting guide

When diagnosing installation, WSL access, permissions, Docker-session, elevation or recovery problems, read the troubleshooting guide.

Required:
- Resource: `docs/troubleshooting.md`
  <!-- ctx:resource id="RESOURCE-B762C2ED8A3A" -->

<!-- ctx:topic id="ONB-0513F8B51242" -->

### Public repository creation procedure

When recreating or auditing the original public-repository setup from the tested prototype, read the repository setup guide.

Required:
- Resource: `docs/repository-setup.md`
  <!-- ctx:resource id="RESOURCE-5D8641A6973B" -->

<!-- ctx:topic id="ONB-716FC7DB282B" -->
<!-- contextcanon-placement-topics:end -->
