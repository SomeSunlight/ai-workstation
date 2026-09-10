from pathlib import Path

PLAN = Path('PLAN.md')
STATE = Path('STATE.md')

plan = PLAN.read_text(encoding='utf-8')
old_item = '- [ ] Record any resulting ContextCanon guidance or implementation change that AI Workstation should consume before its repository restructuring PR is finalized.'
new_item = '- [x] Record the resulting ContextCanon guidance consumed by AI Workstation: Development Workflow 0.3.0-draft is accepted at the root and all eight semantic Parent/Child relationships were reviewed and propagated with ContextCanon 0.7.3.'
if plan.count(old_item) != 1:
    raise SystemExit('Expected exactly one pending ContextCanon-guidance item')
plan = plan.replace(old_item, new_item)

old_checkpoint = 'Issue #1 implementation checkpoint: all nine authored Nodes now carry explicit canonical `ctx:node name` metadata, generated ContextCanon output was rebuilt with the exact PR #18 head `fbca8b2f5a6bfcf2aa040917e201674562d5c983`, and `contextcanon check --all .` plus diff hygiene passed. Draft PR #2 now presents the migration for owner review; no merge is authorized.'
new_checkpoint = 'Issue #1 implementation checkpoint: all nine authored Nodes now carry explicit canonical `ctx:node name` metadata. PR #2 was squash-merged to `main` as `db65575c415f18a8c81db6e1bfcb32a50a56fb32` and Issue #1 closed. Before that merge, the same review branch also completed the real ContextCanon 0.7.3 maintenance step: Development Workflow advanced to 0.3.0-draft, all eight Parent/Child relationships were reviewed and propagated, generated Context was rebuilt, `contextcanon check --all .` was clean across all nine Nodes, and the resulting maintenance flow was idempotent.'
if plan.count(old_checkpoint) != 1:
    raise SystemExit('Expected exactly one Issue #1 draft checkpoint')
plan = plan.replace(old_checkpoint, new_checkpoint)

marker = '## Post-merge baseline — Issue #3\n'
if marker not in plan:
    plan += """\n\n## Post-merge baseline — Issue #3\n\nPurpose: close the inherited Development Workflow post-merge checkpoint after PR #2 without starting the larger repository-alignment block.\n\n- [x] Record PR #2 squash merge `db65575c415f18a8c81db6e1bfcb32a50a56fb32` as the accepted ContextCanon migration/maintenance baseline.\n- [x] Record the completed Development Workflow 0.3.0-draft Source update and all eight reviewed Parent/Child propagation steps.\n- [x] Add a compact root `STATE.md` limited to facts proven by this maintenance run.\n- [x] Leave the richer runtime/architecture State population and repository restructuring in their existing planned blocks.\n\nCheckpoint: Issue #3 is documentation-only baseline reconciliation after PR #2; it does not change runtime or Context semantics.\n"""
PLAN.write_text(plan, encoding='utf-8')

if STATE.exists():
    raise SystemExit('STATE.md unexpectedly already exists')
STATE.write_text("""# AI Workstation Current State\n\n## Accepted repository baseline\n\nPR #2 was squash-merged to `main` as `db65575c415f18a8c81db6e1bfcb32a50a56fb32`. Issue #1 is complete.\n\nThis baseline contains nine authored ContextCanon Nodes: the root plus eight nested Nodes. Canonical Node names use explicit `ctx:node name` metadata.\n\n## Accepted ContextCanon maintenance state\n\nThe root `ai-workstation` Node uses Development Workflow `0.3.0-draft`. The Source update was reviewed and accepted with ContextCanon 0.7.3, then all eight semantic Parent/Child relationships were reviewed and propagated top-down.\n\nThe resulting Context was rebuilt, and the project owner verified `contextcanon check --all .` as `ok` for the root and all eight Child Nodes. Repeating the completed maintenance flow is idempotent.\n\n`contextcanon.yaml` is the visible project-level Source discovery configuration; accepted Source and Parent package identities remain pinned locally in the consuming Nodes.\n\n## Scope of this State file\n\nThis first `STATE.md` intentionally records only facts established by the completed ContextCanon migration/maintenance run. The broader accepted operational baseline for host platforms, Goose, Open WebUI, provider recovery, and local-model connectivity remains an explicit unfinished block in `PLAN.md`; those facts should be populated there through the planned review rather than reconstructed here from old chat history.\n\n## Next planned work\n\nContinue from `PLAN.md` with the post-onboarding repository alignment and the explicitly deferred architecture blocks. New implementation work should start only after selecting a coherent issue-backed block.\n""", encoding='utf-8')
