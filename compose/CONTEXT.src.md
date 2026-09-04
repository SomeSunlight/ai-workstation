# Containerized application runtimes — Local Context Source
<!-- ctx:node id="90dd976e-8753-495b-a631-d708b13878d1" version="0.1.0-draft" -->

## Parent Context Node

<!-- contextcanon-placement-parent:start -->
- [AI Workstation](..) — `0.1.0`
  <!-- ctx:parent id="aea56adf-2a26-43f0-b712-3bbeab7a3097" version="0.1.0" normalized-digest="529a183318232946b8201cecaf9912e9dccfba27d384e303c5f388e39a160ef5" package-digest="1c6e06d2a2c5a14edeb3df79c18673169bf4aebdd00916398b5463dc6efc7cfa" -->
<!-- contextcanon-placement-parent:end -->

## Local Overview

<!-- contextcanon-placement-overview:start -->
<!-- cc:placement-overview id="ONB-C188029871F5" -->
- Dockerfiles define the contents of service images.

<!-- cc:placement-overview id="ONB-DBF6C3D9FAA2" -->
- Compose defines services, mounts, networks and resource limits.
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon-placement-state:start -->
<!-- cc:placement-state id="ONB-5475B681ADB6" -->
- The currently integrated application runtimes are Goose and Open WebUI.
<!-- contextcanon-placement-state:end -->

## Local Plan

<!-- contextcanon-placement-plan:start -->
<!-- cc:placement-plan id="ONB-F2E85C95052E" -->
- Local model integration is intentionally deferred to the next phase.
<!-- contextcanon-placement-plan:end -->

## Local Rules

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Application containers do not receive the Docker socket:** Agent and application containers do not receive the Docker socket.
  Why: Prevents application runtimes from gaining Docker control-plane authority.
  <!-- ctx:rule id="ONB-C582F0CA4FCE" -->

- **Runtime credentials use the protected env file:** Runtime credentials are read from the Git-ignored `.env` file with mode `600`.
  Why: Centralizes runtime secrets in an untracked file with restrictive permissions.
  <!-- ctx:rule id="ONB-E7F7BAC0BF5F" -->
<!-- contextcanon-placement-rules:end -->
