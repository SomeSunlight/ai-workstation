# Containerized application runtimes — Official Context

> [!CAUTION]
> **GENERATED FILE — DO NOT EDIT.**
> This is the compact official entry for this Context Node.
>
> Edit [CONTEXT.src.md](CONTEXT.src.md) instead.

**Node:** Containerized application runtimes  
**Context version:** `0.2.3-draft`

## Local Overview

<!-- contextcanon:format Local Overview
Format: Ordinary Markdown orientation, local to this Node. Any existing placement identity follows its paragraph/item; do not change it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-overview:start -->
- Dockerfiles define the contents of service images.
  <!-- cc:placement-overview id="ONB-C188029871F5" -->

- Compose defines services, mounts, networks and resource limits.
  <!-- cc:placement-overview id="ONB-DBF6C3D9FAA2" -->
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon:format Local State
Format: Ordinary Markdown describing the current local situation. Any existing placement identity follows its paragraph/item; preserve it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-state:start -->
- The currently integrated application runtimes are Goose and Open WebUI.
  <!-- cc:placement-state id="ONB-5475B681ADB6" -->
<!-- contextcanon-placement-state:end -->

## Local Plan

<!-- contextcanon:format Local Plan
Format: Ordinary Markdown describing intended local work. Any existing placement identity follows its paragraph/item; preserve it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-plan:start -->
- Goose supports operator-selected local/self-hosted and public model connections through its native configuration; hardware inference provisioning remains a separate host runtime concern.
  <!-- cc:placement-plan id="ONB-F2E85C95052E" -->
<!-- contextcanon-placement-plan:end -->

## How to use this context

Apply all Rules below to every task in this Node.

## Local Rules

### Onboarding placement

#### `ONB-C582F0CA4FCE` — Application containers do not receive the Docker socket

Agent and application containers do not receive the Docker socket.

#### `ONB-E7F7BAC0BF5F` — Runtime credentials use protected local storage

Runtime credentials stay outside Git, images and authored Compose definitions. Applications may use their native persistent secret store; environment-based credentials use a protected untracked file with mode `600`, scoped to the intended application.
