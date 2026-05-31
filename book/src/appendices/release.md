# Release maintainers

Push tag `definitively-vX.Y.Z` matching `definitively/mix.exs` `version`.

Workflow [release-definitively.yml](https://github.com/Industrial/definitively/blob/main/.github/workflows/release-definitively.yml):

1. **validate** — tag/version check, `mix test --cover`, `mix hex.build`
2. **build** — escript tarballs (linux-x86_64, darwin-arm64)
3. **github-release** — attach assets + `install.sh`
4. **hex-publish** — `mix hex.publish --yes` (`HEX_API_KEY`)
5. **homebrew-tap-bump** — update tap (`HOMEBREW_TAP_TOKEN`)

Re-run without re-tagging: Actions → Release definitively → Run workflow → enter tag.

Required secrets: `HEX_API_KEY`, `HOMEBREW_TAP_TOKEN` (optional until Homebrew automation enabled).
