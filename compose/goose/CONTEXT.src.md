# Goose — Local Context Source
<!-- ctx:node id="3fd2ae4e-d712-4232-917a-7059b03a3cd4" name="Goose" version="0.1.0-draft" -->

## Parent Context Node

<!-- contextcanon-placement-parent:start -->
- [Containerized application runtimes](..) — `0.1.0-draft`
  <!-- ctx:parent id="90dd976e-8753-495b-a631-d708b13878d1" version="0.1.0-draft" normalized-digest="74bf1306d7da7225f485ed9a63938259e2af53be41f451024d1af47fc430d7c2" package-digest="558e628e517fabe47987e789a2117c390ffca6e69df4574311775692abd324be" -->
<!-- contextcanon-placement-parent:end -->

## Local Overview

<!-- contextcanon-placement-overview:start -->
<!-- cc:placement-overview id="ONB-AEFFCCD9AA3E" -->
- Each Goose session starts a short-lived container that is removed when the session ends.
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon-placement-state:start -->
<!-- cc:placement-state id="ONB-427D3A5E729C" -->
- Goose state and session history persist in the `goose-home` Docker volume after a session container is removed.
<!-- contextcanon-placement-state:end -->

## Local Rules

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Goose gets exactly one registered workspace:** Each Goose session mounts exactly one explicitly registered host workspace read-write.
  Why: Bounds Goose file authority to the workspace deliberately selected for that session.
  <!-- ctx:rule id="ONB-0A89CA3DEB05" -->

- **Goose root filesystem is read-only:** Goose containers use a read-only root filesystem.
  Why: Limits container-side mutation outside the delegated persistent surfaces.
  <!-- ctx:rule id="ONB-3B9C2D19E779" -->

- **Goose drops Linux privileges:** Goose containers drop Linux capabilities and use `no-new-privileges`.
  Why: Reduces privileges available inside the session container.
  <!-- ctx:rule id="ONB-31BF69407B79" -->

- **Goose cannot see unrelated host directories:** Goose receives no access to unrelated WSL or Windows directories unless they are deliberately registered as the selected workspace.
  Why: Prevents accidental expansion of the agent file-access boundary.
  <!-- ctx:rule id="ONB-073CCD7C33CE" -->

- **Goose rejects broad workspace roots:** Broad workspace paths such as `/`, `/home`, `$HOME`, `/mnt` and `/mnt/c` are rejected by the wrapper.
  Why: Prevents registering host-wide paths that would defeat workspace isolation.
  <!-- ctx:rule id="ONB-8103C2181D78" -->

- **Goose workspace container path:** The selected Goose workspace is mounted at a stable container path under `/workspaces/NAME`.
  Why: Gives sessions a predictable container-side workspace location independent of the host path.
  <!-- ctx:rule id="ONB-252B9B6CA5E5" -->

- **Selected Goose workspace is delegated authority:** The selected workspace is delegated authority: Goose can edit or delete files inside it and can modify its Git repository.
  Why: Makes the consequence of granting a workspace explicit to operators and reviewers.
  <!-- ctx:rule id="ONB-EBCD0451BABA" -->

- **Review Goose changes before publishing:** Review Goose changes before committing or pushing them.
  Why: Keeps publication of agent-made repository changes under human control.
  <!-- ctx:rule id="ONB-A0D929FAD90A" -->
<!-- contextcanon-placement-rules:end -->
