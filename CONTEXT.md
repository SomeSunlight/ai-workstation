# ai-workstation — Official Context

> [!CAUTION]
> **GENERATED FILE — DO NOT EDIT.**
> This is the compact official entry for this Context Node.
> Together with `CONTEXT/` it forms the human/agent-facing Official Context Package.
>
> Edit [CONTEXT.src.md](CONTEXT.src.md) instead.

**Node:** ai-workstation  
**Context version:** `0.2.3`

## Local Overview

<!-- contextcanon:format Local Overview
Format: Ordinary Markdown orientation, local to this Node. Any existing placement identity follows its paragraph/item; do not change it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-overview:start -->
- AI Workstation is a general-purpose, reproducible installer/operator with host-native Windows services, WSL2/Linux and native Linux execution paths, plus independently managed containers. The currently accepted full installation path is Windows/WSL; native Linux host acceptance is a separate gate.
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

## How to use this context

Apply all Rules below to every task in this Node.

For the current task, evaluate each Topic condition. When one matches, read every **Required** target before continuing; read **Optional** targets only when useful.

## Local Rules

### Onboarding placement

#### `ONB-6566E6E85D48` — Repository is the installation specification

The repository is the installation specification; running containers and manually modified hosts are not the source of truth.

#### `ONB-504C6A92475F` — Keep WSL development inside its Linux filesystem

When developing or installing Linux workloads under WSL, use the WSL Linux filesystem rather than `/mnt/c`; native Windows and native Linux tools use their own appropriate host filesystems.

#### `ONB-02E2C1B8C47B` — Keep versions documentation and tests aligned

Update `config/versions.json`, documentation and tests together.

#### `ONB-BE08FE3A5E3D` — Run release check before committing

Run `./tools/release-check.sh` before committing.

#### `ONB-DCF5EB952F7D` — Keep secrets out of Git images and Compose

Secrets must not be committed, copied into images or stored in Compose files.

#### `RULE-81304E42320A` — Keep shipped product behavior general and English-language

Design and document AI Workstation for native Windows, Linux under WSL and native Linux using platform-specific adapters where needed. Keep public code, menu/CLI text, default examples and documentation in English regardless of the conversation language. Personal hostnames, usernames, domains, provider preferences and password-manager choices belong in private operator configuration, not product assumptions.

#### `RULE-7E9AB1D9A8A0` — Make operator workflows discoverable with little memorization

Prefer concise menus that preserve readable action results, redisplay choices on request, offer numbered selection of already known objects and briefly distinguish terms such as original credentials versus derived hashes. Keep details in linked guidance and test representative user journeys on each relevant operating system.

## Local Topics

### Security reporting resource

When reporting a vulnerability or checking the project security-reporting procedure, read the security document.

**Required**

- [`CONTEXT/references/aea56adf-2a26-43f0-b712-3bbeab7a3097/SECURITY.md`](CONTEXT/references/aea56adf-2a26-43f0-b712-3bbeab7a3097/SECURITY.md)

### Troubleshooting guide

When diagnosing installation, WSL access, permissions, Docker-session, elevation or recovery problems, read the troubleshooting guide.

**Required**

- [`CONTEXT/references/aea56adf-2a26-43f0-b712-3bbeab7a3097/docs/troubleshooting.md`](CONTEXT/references/aea56adf-2a26-43f0-b712-3bbeab7a3097/docs/troubleshooting.md)

### Public repository creation procedure

When recreating or auditing the original public-repository setup from the tested prototype, read the repository setup guide.

**Required**

- [`CONTEXT/references/aea56adf-2a26-43f0-b712-3bbeab7a3097/docs/repository-setup.md`](CONTEXT/references/aea56adf-2a26-43f0-b712-3bbeab7a3097/docs/repository-setup.md)
