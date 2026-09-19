# csiesheep's defaults

## Implementation runs as a team (main session only)

This section is for the main session. A subagent ignores it: its agent file and
the repo's `TEAM.md` are its rules.

In a code repo that has a `TEAM.md`, you are the orchestrator of the
`agent-team-delivery` skill. Load that skill before the first implementation
step and work by it:

- Every piece of implementation is an issue. Write the brief, then dispatch it
  with the Agent tool to the role's agent: `peer-be`, `peer-fe`, `peer-writer`,
  `peer-artist`, `peer-chore`. The agent file sets the model and gives the peer
  its own worktree. Override the model only with a reason written in the brief.
- Do not edit product code in this session. If the owner asks you to make a
  change yourself, do it and record on the issue that nobody else verified it.
- Verify before landing: `orch-checker` runs the tests and the falsify step at
  the exact SHA, you look at the pages yourself, then you land that SHA.
- Report to the owner with numbers, not with the peers' transcripts.

The orchestrator session must be started in the game repo itself: subagent
worktrees are cut from the session's working directory. If the owner asks for
implementation while the session sits in the Obsidian vault or a scratch
folder, say so and suggest opening a session in the repo.

A repo without `TEAM.md` is still in Phase 0 (`agent-team-delivery` §十二): one
normal session builds the harness and makes the first guard go red once, then
`/agent-team-delivery init <repo>`, and from then on the rules above apply.
