# Bootstrap — Local Context Source
<!-- ctx:node id="f78265e4-e023-4d7a-9b26-9a917ef68a4a" name="Bootstrap" version="0.1.2-draft" -->

## Parent Context Node

<!-- contextcanon-placement-parent:start -->
- [ai-workstation](..) — `0.1.2`
  <!-- ctx:parent id="aea56adf-2a26-43f0-b712-3bbeab7a3097" version="0.1.2" normalized-digest="2622d3482e9b3f0f657c7f385ae6662c0028159e1ba0e69204e274b30d1d99cf" package-digest="faa3552482ada2cf0231776b7cf078713929e1b3d4b52db114669d03470d5f82" -->
<!-- contextcanon-placement-parent:end -->

## Local Overview

## Local Rules

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Keep installation entry points thin:** Keep installation entry points thin and move implementation into modules.
  Why: Preserves a small entry-point surface while keeping implementation maintainable.
  <!-- ctx:rule id="ONB-14050ED3235E" -->

- **Preserve installer idempotency:** Preserve idempotency: a second run must be safe.
  Why: Installation is explicitly designed to be rerun after interruption or partial completion.
  <!-- ctx:rule id="ONB-F02E76A8ECF4" -->

- **No automatic destructive migration:** Never introduce an automatic destructive migration.
  Why: Destructive changes require explicit human control rather than implicit installer behavior.
  <!-- ctx:rule id="ONB-DDE1BB850066" -->
<!-- contextcanon-placement-rules:end -->
