# Ansible host configuration — Official Context

> [!CAUTION]
> **GENERATED FILE — DO NOT EDIT.**
> This is the compact official entry for this Context Node.
> Together with `CONTEXT/` it forms the human/agent-facing Official Context Package.
>
> Edit [CONTEXT.src.md](CONTEXT.src.md) instead.

**Node:** Ansible host configuration  
**Context version:** `0.1.0-draft`

**Parent Context Node:** [Bootstrap](.context/sources/7b9d48b4239666b4dd6fbb1785eac7c6a55eb27ab1a1447d8fc09363ad8d5119/CONTEXT.md) — `0.1.0-draft`  
**Accepted Parent package:** `7b9d48b4239666b4dd6fbb1785eac7c6a55eb27ab1a1447d8fc09363ad8d5119`

**Resulting imported Contexts:**

- **Development Workflow** — `0.2.0-draft` — via Parent Context Node **Bootstrap** — Why: We want to use the same successful development workflow from context-canon for this project too. Feel free to use also other workflowss, if you like. Then put it here. — [inspect accepted carrier](.context/sources/7b9d48b4239666b4dd6fbb1785eac7c6a55eb27ab1a1447d8fc09363ad8d5119/CONTEXT.md)
- **ai-workstation** — `0.1.0` — via Parent Context Node **Bootstrap** — [inspect accepted carrier](.context/sources/7b9d48b4239666b4dd6fbb1785eac7c6a55eb27ab1a1447d8fc09363ad8d5119/CONTEXT.md)
- **Bootstrap** — `0.1.0-draft` — direct Parent Context Node — [inspect accepted carrier](.context/sources/7b9d48b4239666b4dd6fbb1785eac7c6a55eb27ab1a1447d8fc09363ad8d5119/CONTEXT.md)

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

## How to use this context

Apply all Rules below to every task in this Node.

For the current task, evaluate each Topic condition. When one matches, read every **Required** target before continuing; read **Optional** targets only when useful.

## Rules from Development Workflow

### Recoverable planning

#### `CCW-001` — Plan a coherent change block before editing

Before starting a new coherent development block, record a short purpose and checklist in the project's durable planning surface; use `PLAN.md` when the project follows this workflow convention.

#### `CCW-002` — Checkpoint completed plan items immediately

When a listed step is actually complete, mark its `PLAN.md` checkbox `[x]` immediately rather than reconstructing completion at the end of a long session.

#### `CCW-003` — Keep recovery-critical knowledge in the repository

Put decisions, active constraints, accepted state, and next steps needed to resume work in repository documentation such as `PLAN.md`, `STATE.md`, or the project's equivalent rather than relying on chat history or model memory.

#### `CCW-007` — Resume recent explicit continuation without re-proving unchanged state

When the project owner resumes work after a short conversational interruption, explicitly says to continue, and reports no intervening repository changes, continue from the last established branch/PR state unless a repository operation gives evidence that it changed. Do not spend a new work cycle re-checking already established repository facts merely to prove that nothing happened.

### Proportional verification

#### `CCW-004` — Batch related edits before expensive final verification

For one coherent correction block, make the related authoring/code changes and run proportionate focused checks first; do not repeat the project's most expensive generated-output, integration, packaging, or full verification cycle after every micro-edit.

#### `CCW-009` — Use owner-approved fast-run blocks without weakening the final gate

When the project owner explicitly approves a coherent implementation scope and says intermediate product review is unnecessary, mark the fast-run as active in the durable PLAN with its scope and exit condition, keep recovery checkpoints and focused verification inside bounded work blocks, and defer repeated PR-description polish, full CI, generated-output regeneration, and other review ceremony until the coherent review candidate. When the fast-run ends, record that closure before returning to ordinary review cadence.

#### `CCW-005` — Require exact-head green verification at the merge gate, not the first review gate

A coherent development block may be presented for project-owner review while understood and disclosed CI failures or generated drift remain. After explicit project-owner approval and before merging, require the exact current head to pass the project's complete merge-gate verification, including zero generated drift when generated canonical output is part of the project contract.

### Human review gate

#### `CCW-006` — Do not merge without explicit project-owner approval

Keep a review PR or equivalent change set open until the project owner explicitly approves the reviewed result.

### Accepted baseline

#### `CCW-008` — Close the post-merge baseline checkpoint before new development

After a reviewed change is successfully merged into the accepted branch, reconcile the durable repository state that records the accepted baseline before starting the next coherent development block. Record the merge outcome in `PLAN.md`, update `STATE.md` or equivalent current-state documentation, and refresh README/CHANGELOG or review-status wording made stale by the merge when applicable.

## Rules from ai-workstation

### Onboarding placement

#### `ONB-6566E6E85D48` — Repository is the installation specification

The repository is the installation specification; running containers and manually modified hosts are not the source of truth.

#### `ONB-504C6A92475F` — Develop inside the WSL filesystem

Work inside the WSL Linux filesystem, not under `/mnt/c`.

#### `ONB-02E2C1B8C47B` — Keep versions documentation and tests aligned

Update `config/versions.json`, documentation and tests together.

#### `ONB-BE08FE3A5E3D` — Run release check before committing

Run `./tools/release-check.sh` before committing.

#### `ONB-DCF5EB952F7D` — Keep secrets out of Git images and Compose

Secrets must not be committed, copied into images or stored in Compose files.

## Rules from Bootstrap

### Onboarding placement

#### `ONB-14050ED3235E` — Keep installation entry points thin

Keep installation entry points thin and move implementation into modules.

#### `ONB-F02E76A8ECF4` — Preserve installer idempotency

Preserve idempotency: a second run must be safe.

#### `ONB-DDE1BB850066` — No automatic destructive migration

Never introduce an automatic destructive migration.

## Local Rules

### Onboarding placement

#### `ONB-B139299ADE50` — Conflicting container packages are not removed automatically

Existing conflicting container packages are reported, not removed automatically.

#### `ONB-4D9D0588DD63` — Docker daemon stays on the local Unix socket

The Docker daemon is exposed only through its local Unix socket.

#### `ONB-FE26E55B301A` — Only the interactive user joins the docker group

Only the interactive Linux user joins the powerful `docker` group.

## Topics from Development Workflow

### Executing a development block

When planning, resuming, checkpointing, reviewing, testing, finalizing, merging, or closing the accepted baseline for a coherent development block:

**Required**

- [`CONTEXT/references/c4c94726-3cc7-4df6-b779-72bbf9c06f40/nodes/library/development-workflow/docs/change-workflow.md`](CONTEXT/references/c4c94726-3cc7-4df6-b779-72bbf9c06f40/nodes/library/development-workflow/docs/change-workflow.md)

## Topics from ai-workstation

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
