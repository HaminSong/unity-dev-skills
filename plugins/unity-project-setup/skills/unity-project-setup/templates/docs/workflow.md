# Workflow — from idea to shipped change

- **Created** {{DATE}}
- How an idea becomes a change in the game, where each document lives, and how the index stays readable. Branches, commits and parallel work are in [collaboration.md](collaboration.md).

## 1. Where documents go

| Folder | Holds | Naming |
|---|---|---|
| `docs/` (root) | Reference documents that describe the **current** state: index, architecture map, design, guidelines, collaboration, this file | Fixed names |
| `docs/intent/` | Plans: what we will do and why, scope, steps, done-when | `YYYY-MM-DD-short-title.md` |
| `docs/research/YYYY-MM-DD-topic/` | Investigations, comparisons, mockups, captures. A `README.md` inside summarises; images sit next to it | One folder per topic |
| `docs/tasks/` | Briefs for delegated work ([TEMPLATE.md](tasks/TEMPLATE.md)) | `NN-short-name.md` |
| `docs/archive/` | Finished, superseded or rejected documents, listed in `archive/README.md` | Original name, date prefix added if missing |

- Create a folder the first time it is needed; do not pre-create empty ones.
- Images and captures live next to the document that uses them, never under `Assets/`.
- Reference documents are rewritten to the current state. Plans and research are dated snapshots: once decided, they are not rewritten, only given a new status.

## 2. Status header

Every document in `intent/` and `research/` starts with:

```
- **Status** proposal | decided | in progress | applied | rejected | superseded
- **Date** YYYY-MM-DD   **Decided** (who, when — empty until decided)
- **Game changed** no | yes (branch or commit)
```

- `proposal` — written by an agent or a person. The game is not changed.
- `decided` — the user chose. Record the choice and, in one line each, the options not taken.
- `in progress` → `applied` — implementation started, then merged and verified.
- `rejected` / `superseded` — keep the document, link to whatever replaced it, move it to `archive/`.

## 3. Flow

1. **Request or idea.** If it changes game design, look, balance, scope or player-facing text, start with step 2. A small, unambiguous bug fix can go straight to step 5.
2. **Proposal.** Write it in `research/` (investigation, options) or `intent/` (plan). Offer two or three options with a recommendation. Throwaway prototypes and captures are fine if labelled as such; temporary code and test saves are removed afterwards. **The game is not changed at this stage.**
3. **Decision.** Only the user decides. Update the status header and the index line.
4. **Plan.** In the `intent/` document: steps, files touched, done-when. Work that can run in parallel becomes briefs in `tasks/` (see collaboration.md §3).
5. **Implement** on a `feat/` branch, with tests for any Core change.
6. **Verify.** EditMode tests, a Play check, captures where the change is visual. State plainly what was not verified.
7. **Update the docs** in the same change: `ARCHITECTURE_MAP.md` if structure changed, guidelines if a rule changed, the document's status → `applied`, and its index line.
8. **Archive** documents that no longer guide current work: move them to `archive/` and update both indexes.

An agent never turns a proposal into a game change without the user's decision, even when the recommendation seems obvious.

## 4. The index (`docs/README.md`)

The index is a map. Details belong in the documents themselves.

- **One line per document:** `- [Title](path) — YYYY-MM-DD · status · one-line summary`. Keep it under about 200 characters. If a line keeps growing, the document needs a better summary, not the index.
- **Three groups:** *Reference* (the fixed documents), *Active* (proposal, decided, in progress), *Recently applied*. Move an applied entry to `archive/README.md` once newer work has replaced its context.
- **Same commit:** add or update the index line in the same commit as the document.
- **Newest first** within each group.
