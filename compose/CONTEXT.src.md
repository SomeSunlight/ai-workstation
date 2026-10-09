# Containerized application runtimes — Local Context Source
<!-- ctx:node id="90dd976e-8753-495b-a631-d708b13878d1" name="Containerized application runtimes" version="0.1.3-draft" -->

## Parent Context Node

<!-- contextcanon-placement-parent:start -->
- [ai-workstation](..) — `0.1.2`
  <!-- ctx:parent id="aea56adf-2a26-43f0-b712-3bbeab7a3097" version="0.1.2" normalized-digest="2622d3482e9b3f0f657c7f385ae6662c0028159e1ba0e69204e274b30d1d99cf" package-digest="faa3552482ada2cf0231776b7cf078713929e1b3d4b52db114669d03470d5f82" -->
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
- Goose supports operator-selected local/self-hosted and public model connections through its native configuration; hardware inference provisioning remains a separate host runtime concern.
<!-- contextcanon-placement-plan:end -->

## Local Rules

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Application containers do not receive the Docker socket:** Agent and application containers do not receive the Docker socket.
  Why: Prevents application runtimes from gaining Docker control-plane authority.
  <!-- ctx:rule id="ONB-C582F0CA4FCE" -->

- **Runtime credentials use protected local storage:** Runtime credentials stay outside Git, images and authored Compose definitions. Applications may use their native persistent secret store; environment-based credentials use a protected untracked file with mode `600`, scoped to the intended application.
  Why: Preserves native provider configuration while avoiding implicit sharing of credentials between unrelated applications.
  <!-- ctx:rule id="ONB-E7F7BAC0BF5F" -->
<!-- contextcanon-placement-rules:end -->
