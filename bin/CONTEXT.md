# aiw operator interface — Official Context

> [!CAUTION]
> **GENERATED FILE — DO NOT EDIT.**
> This is the compact official entry for this Context Node.
> Together with `CONTEXT/` it forms the human/agent-facing Official Context Package.
>
> Edit [CONTEXT.src.md](CONTEXT.src.md) instead.

**Node:** aiw operator interface  
**Context version:** `0.1.0-draft`

**Parent Context Node:** [ai-workstation](.context/sources/1c6e06d2a2c5a14edeb3df79c18673169bf4aebdd00916398b5463dc6efc7cfa/CONTEXT.md) — `0.1.0`  
**Accepted Parent package:** `1c6e06d2a2c5a14edeb3df79c18673169bf4aebdd00916398b5463dc6efc7cfa`

**Resulting imported Contexts:**

- **Development Workflow** — `0.2.0-draft` — via Parent Context Node **ai-workstation** — Why: We want to use the same successful development workflow from context-canon for this project too. Feel free to use also other workflowss, if you like. Then put it here. — [inspect accepted carrier](.context/sources/1c6e06d2a2c5a14edeb3df79c18673169bf4aebdd00916398b5463dc6efc7cfa/CONTEXT.md)
- **ai-workstation** — `0.1.0` — direct Parent Context Node — [inspect accepted carrier](.context/sources/1c6e06d2a2c5a14edeb3df79c18673169bf4aebdd00916398b5463dc6efc7cfa/CONTEXT.md)

## Local Overview

<!-- contextcanon-placement-overview:start -->
<!-- cc:placement-overview id="ONB-C952C6C6635C" -->
- `aiw` is the stable user interface for installation and operation.
<!-- contextcanon-placement-overview:end -->

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
