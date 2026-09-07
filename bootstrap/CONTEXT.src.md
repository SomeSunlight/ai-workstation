# Bootstrap — Local Context Source
<!-- ctx:node id="f78265e4-e023-4d7a-9b26-9a917ef68a4a" version="0.1.0-draft" -->

## Parent Context Node

<!-- contextcanon-placement-parent:start -->
- [ai-workstation](..) — `0.1.0`
  <!-- ctx:parent id="aea56adf-2a26-43f0-b712-3bbeab7a3097" version="0.1.0" normalized-digest="529a183318232946b8201cecaf9912e9dccfba27d384e303c5f388e39a160ef5" package-digest="1c6e06d2a2c5a14edeb3df79c18673169bf4aebdd00916398b5463dc6efc7cfa" -->
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
