# Open WebUI — Official Context

> [!CAUTION]
> **GENERATED FILE — DO NOT EDIT.**
> This is the compact official entry for this Context Node.
>
> Edit [CONTEXT.src.md](CONTEXT.src.md) instead.

**Node:** Open WebUI  
**Context version:** `0.2.3-draft`

## Local Overview

<!-- contextcanon:format Local Overview
Format: Ordinary Markdown orientation, local to this Node. Any existing placement identity follows its paragraph/item; do not change it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-overview:start -->
- Open WebUI runs as a persistent Docker service accessed from the Windows browser through WSL localhost forwarding.
  <!-- cc:placement-overview id="ONB-15284536311B" -->

- Open WebUI reaches configured model providers over the network.
  <!-- cc:placement-overview id="ONB-57A446045BBD" -->
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon:format Local State
Format: Ordinary Markdown describing the current local situation. Any existing placement identity follows its paragraph/item; preserve it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-state:start -->
- The default Open WebUI address is `http://localhost:3000`.
  <!-- cc:placement-state id="ONB-9745CD6E1E1C" -->

- Open WebUI stores its persistent state in a named Docker volume.
  <!-- cc:placement-state id="ONB-35A21B57D6C3" -->

- The first Open WebUI account becomes the local administrator.
  <!-- cc:placement-state id="ONB-725C7FD86EA6" -->
<!-- contextcanon-placement-state:end -->

## How to use this context

Apply all Rules below to every task in this Node.

## Local Rules

### Onboarding placement

#### `ONB-055DC22CD3AD` — Open WebUI binds to localhost

Open WebUI binds only to `127.0.0.1` on the WSL host by default.

#### `ONB-5CC56E3A7A35` — Open WebUI receives no host workspace

Open WebUI receives no host workspace.

#### `ONB-84AA72A87719` — Open WebUI receives no Docker socket

Open WebUI receives no Docker socket.

#### `ONB-DEF73E20EAE8` — Open WebUI keeps authentication enabled

Open WebUI keeps authentication enabled.

#### `ONB-EAAB7BB9AD74` — Use a strong Open WebUI administrator password

Use a strong password for the Open WebUI administrator account.

#### `ONB-4D2A3FDC8A51` — Do not expose Open WebUI without added controls

Do not publish the Open WebUI localhost port through a proxy or LAN interface without appropriate TLS, authentication and network controls.
