# LEAN-CTX.md

## Purpose

This file documents the expected `lean-ctx` and `jcodemunch` workflow for this repository.

## Lean-CTX Usage

Default to `lean-ctx` for shell commands that read, search, or summarize repository state.

- Compressed mode (default): `lean-ctx -c "<command>"`
- Full output mode: `lean-ctx -c --raw "<command>"`

Typical examples:

- `lean-ctx -c "rg --files"`
- `lean-ctx -c "rg -n \"GitClient\" ."`
- `lean-ctx -c "sed -n '1,220p' AGENTS.md"`
- `lean-ctx -c "git status --short --branch"`

## jCodeMunch Workflow

Use jcodemunch as the primary code-intelligence layer for symbol-aware navigation.

1. `resolve_repo(path)` for O(1) repo lookup.
2. `index_folder(path, incremental=true)` when missing or outdated.
3. Use symbol-aware retrieval first:
   - `search_symbols`
   - `get_symbol_source`
   - `get_context_bundle`
4. Fall back to raw text search only if symbol search is insufficient.
5. After edits, refresh touched files with `index_file(path)`.

## Working Rules

- Prefer symbol-aware lookup before broad raw grep.
- Keep reads focused to specific files/line windows.
- Re-index after code edits so symbol results remain accurate.
