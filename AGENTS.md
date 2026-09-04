# Dockerize Skill Authoring Rules

When changing this repository's user documentation or its `dockerize` skill, follow the relevant ordered workflow below.

## README translations

- `README.md` is the English document and `README-ko.md` is its Korean counterpart. They must have the same meaning and strength, structure, commands, paths, identifiers, and constraints. Neither language is a fixed source.
- For an existing tracked README pair, after modifying the intended source and before translating the counterpart, snapshot both files' `git status --short` output and filesystem mtimes once. A normal modification candidate is a file with exactly ` M`, `M `, or `MM` status. If only one file is a candidate, use it as the source; if both are candidates, use the file with the newer mtime.
- A clean README pair is not a synchronization target. If the mtimes are equal or either file has an `A`, `D`, `R`, `U`, untracked, or other non-`M` change, do not select a source arbitrarily; stop and obtain the user's explicit choice.
- Keep the README source selection fixed until that synchronization task finishes. Do not select it again after editing the counterpart. If either file changes unexpectedly, stop rather than overwrite it.
- Translate the counterpart with the same meaning and strength while preserving commands, paths, identifiers, enum values, and YAML or JSON keys. Compare the complete documents, then pass `tests/test-readme-sync.sh`. This test does not replace semantic review.

## Skill translations

1. Before editing either `SKILL.md`, inspect the Git status and filesystem mtime of `locales/ko/dockerize/SKILL.md` and `skills/dockerize/SKILL.md` once. Only an existing file that is modified in the index or working tree relative to `HEAD` is a source candidate.
2. If there is one candidate, select it as the source of the user's intent for that task. If there are two, select the candidate with the newer mtime. If neither is modified, begin in the natural language of the request. If candidate mtimes are exactly equal, a file is missing, or Git reports an unsafe state such as deletion, rename, or unmerged content, do not edit; ask the user which source or recovery path to use.
3. Use the selected source to make the other language's `SKILL.md` semantically equivalent. Do not select the source again based on mtimes changed by the agent during the task.
4. Preserve rules, conditions, precedence, and list order. Do not translate paths, commands, environment variables, or code keywords. Do not edit the globally installed copy at `$HOME/.agents/skills/dockerize` directly.
5. After reviewing semantic equivalence, run `scripts/record-sync.sh` or `scripts/record-sync.ps1`.
6. Run `scripts/check-sync.sh` or `scripts/check-sync.ps1`, `quick_validate.py` for both `SKILL.md` files, and the full regression suite.
7. If the change affects skill scope or the default prompt, review the English-only `skills/dockerize/agents/openai.yaml` separately.

Changes limited to references, assets, `agents/openai.yaml`, installation tools, or repository documentation do not require Korean-English skill synchronization. The synchronization manifest proves only that neither skill file has changed since the last semantic review; it does not prove translation quality.
