# Ansible host configuration — Local Context Source
<!-- ctx:node id="ad9cbb59-ae04-4290-9c53-5d70cfefe434" name="Ansible host configuration" version="0.1.0-draft" -->

## Parent Context Node

<!-- contextcanon-placement-parent:start -->
- [Bootstrap](..) — `0.1.0-draft`
  <!-- ctx:parent id="f78265e4-e023-4d7a-9b26-9a917ef68a4a" version="0.1.0-draft" normalized-digest="f14212a032675699c05b7c2d4d7d24755b4de52b0a6fad682d6d8855f98d1eaf" package-digest="7b9d48b4239666b4dd6fbb1785eac7c6a55eb27ab1a1447d8fc09363ad8d5119" -->
<!-- contextcanon-placement-parent:end -->

## Local Overview

<!-- contextcanon-placement-overview:start -->
<!-- cc:placement-overview id="ONB-444A1E93B553" -->
- Ansible owns Ubuntu host state and Docker Engine.
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon-placement-state:start -->
<!-- cc:placement-state id="ONB-F7A368F3CAE1" -->
- The automation environment requires Python 3.12.*.

<!-- cc:placement-state id="ONB-73F6A9557DB5" -->
- `ansible-core` is pinned to 2.21.1.

<!-- cc:placement-state id="ONB-D32F29A7A6AB" -->
- `ansible-lint` is pinned to 26.6.0.
<!-- contextcanon-placement-state:end -->

## Local Rules

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Conflicting container packages are not removed automatically:** Existing conflicting container packages are reported, not removed automatically.
  Why: Avoids destructive host changes during Docker setup.
  <!-- ctx:rule id="ONB-B139299ADE50" -->

- **Docker daemon stays on the local Unix socket:** The Docker daemon is exposed only through its local Unix socket.
  Why: Avoids exposing the Docker control plane over a network interface.
  <!-- ctx:rule id="ONB-4D9D0588DD63" -->

- **Only the interactive user joins the docker group:** Only the interactive Linux user joins the powerful `docker` group.
  Why: Keeps Docker-equivalent host authority limited to the intended interactive account.
  <!-- ctx:rule id="ONB-FE26E55B301A" -->
<!-- contextcanon-placement-rules:end -->
