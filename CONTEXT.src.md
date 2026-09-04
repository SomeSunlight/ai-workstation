# ai-workstation — Local Context Source
<!-- ctx:node id="aea56adf-2a26-43f0-b712-3bbeab7a3097" version="0.1.0" -->

## Local Overview

<!-- contextcanon-placement-overview:start -->
<!-- cc:placement-overview id="ONB-468CE58AC863" -->
- AI Workstation is a reproducible workstation built from Windows/WSL bootstrap, Linux host configuration, and containerized application runtimes.
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon-placement-state:start -->
<!-- cc:placement-state id="ONB-AF4EE42CF15A" -->
- Supported Windows host: Windows 11 with current Store WSL.

<!-- cc:placement-state id="ONB-081E84B6F644" -->
- Supported PowerShell: 7.4 or newer.

<!-- cc:placement-state id="ONB-0022686FB5D8" -->
- Supported Linux guest: Ubuntu 24.04 under WSL 2.

<!-- cc:placement-state id="ONB-9699C06578AD" -->
- Supported architecture: x86-64 on both Windows and WSL.
<!-- contextcanon-placement-state:end -->

## Sources

<!-- contextcanon-placement-sources:start -->
- [Development Workflow](https://github.com/SomeSunlight/context-canon.git) — `0.2.0-draft`
  Why: We want to use the same successful development workflow from context-canon for this project too. Feel free to use also other workflowss, if you like. Then put it here.
  <!-- ctx:source id="c4c94726-3cc7-4df6-b779-72bbf9c06f40" version="0.2.0-draft" normalized-digest="360fce40e173bb58f72c25be3092771b74094ab5d428ffc615c09c2e5bb84e99" package-digest="67392242f1cc1e305607a19b8c82b1a3a5e9fbf7f85640af5f90daaf3a992653" transport="git" ref="1a2b9e7029150f493ca7a3fafb2cda9362416fba" node-path="nodes/library/development-workflow" -->
<!-- contextcanon-placement-sources:end -->

## Local Rules

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

<!-- contextcanon-placement-topics:start -->
### Security reporting resource

When reporting a vulnerability or checking the project security-reporting procedure, read the security document.

Required:
- Resource: `SECURITY.md`

<!-- ctx:topic id="ONB-FA47F00F43A9" -->

### Troubleshooting guide

When diagnosing installation, WSL access, permissions, Docker-session, elevation or recovery problems, read the troubleshooting guide.

Required:
- Resource: `docs/troubleshooting.md`

<!-- ctx:topic id="ONB-0513F8B51242" -->

### Public repository creation procedure

When recreating or auditing the original public-repository setup from the tested prototype, read the repository setup guide.

Required:
- Resource: `docs/repository-setup.md`

<!-- ctx:topic id="ONB-716FC7DB282B" -->
<!-- contextcanon-placement-topics:end -->
