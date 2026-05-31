The ship commit step failed (git commit did not complete or the agent could not finish).

Review `git status`, resolve blockers (empty commit, hooks, conflicts, unstaged files), then stage and commit with an appropriate message.

Respond with JSON on success: `{"status":"ok","signals":{"fix_complete":true}}`
