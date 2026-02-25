# Git-Like Database Versioning System for PostgreSQL

A complete **Git-style version control system** implemented entirely in PostgreSQL, demonstrated through a full banking database with AI/ML model governance.

---

## Architecture Overview

This system mirrors Git's core concepts — **branches, commits, diffs, merges, tags, rollbacks** — but for database rows instead of files. Every row-level INSERT, UPDATE, and DELETE is tracked via triggers and stored as JSONB deltas, giving you full audit history and time-travel capability.

### Git ↔ Database Mapping

| Git Concept        | Database Equivalent                     | Function                        |
|--------------------|-----------------------------------------|---------------------------------|
| `git init`         | Register table for tracking             | `vcs_init('table_name')`        |
| `git status`       | View staged (uncommitted) changes       | `vcs_status()`                  |
| `git add + commit` | Commit staged changes                   | `vcs_commit('message')`         |
| `git log`          | View commit history                     | `vcs_log()`                     |
| `git diff`         | Compare two commits                     | `vcs_diff(commit_a, commit_b)`  |
| `git branch`       | Create a branch                         | `vcs_branch_create('name')`     |
| `git branch -a`    | List all branches                       | `vcs_branch_list()`             |
| `git checkout`     | Switch active branch                    | `vcs_checkout('branch')`        |
| `git merge`        | Merge branches (with conflict detection)| `vcs_merge('source')`           |
| `git tag`          | Tag a commit                            | `vcs_tag_create('v1.0')`        |
| `git revert`       | Rollback to a prior commit              | `vcs_rollback(commit_id)`       |
| `git show`         | Show commit details                     | `vcs_show(commit_id)`           |
| `git blame`        | Who last changed each row               | `vcs_blame('table')`            |
| `git log -- file`  | Full history of a single row            | `vcs_row_history('table','pk')` |
| `git checkout rev file` | View data at any point in time     | `vcs_time_travel('table', id)`  |

---

## Schema Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    VCS METADATA LAYER                        │
│                                                             │
│  vcs_config          vcs_repository        vcs_branch       │
│  ┌──────────┐        ┌──────────────┐      ┌────────────┐  │
│  │ key      │        │ table_name   │      │ branch_name│  │
│  │ value    │        │ pk_column    │      │ created_from│  │
│  └──────────┘        └──────────────┘      └────────────┘  │
│                           │                      │          │
│           ┌───────────────┴──────────────────────┘          │
│           ▼                                                  │
│  vcs_commit ──────── vcs_commit_parent (DAG)                │
│  ┌─────────────┐     ┌───────────────────┐                  │
│  │ commit_id   │────▶│ commit_id         │                  │
│  │ branch_name │     │ parent_commit_id  │                  │
│  │ hash        │     └───────────────────┘                  │
│  │ message     │                                             │
│  │ author      │                                             │
│  └──────┬──────┘                                             │
│         │                                                    │
│         ▼                                                    │
│  vcs_change (permanent)      vcs_staged_change (staging)    │
│  ┌──────────────────┐        ┌──────────────────┐           │
│  │ table_name       │        │ table_name       │           │
│  │ row_pk           │        │ row_pk           │           │
│  │ operation        │        │ operation        │           │
│  │ old_data (JSONB) │        │ old_data (JSONB) │           │
│  │ new_data (JSONB) │        │ new_data (JSONB) │           │
│  │ changed_columns  │        │ changed_columns  │           │
│  └──────────────────┘        └──────────────────┘           │
│                                                             │
│  vcs_tag                                                     │
│  ┌────────────┐                                              │
│  │ tag_name   │──────▶ commit_id                             │
│  │ message    │                                              │
│  └────────────┘                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  BANKING DATA LAYER                          │
│                                                             │
│  branch ──▶ employee ──▶ account ──▶ transaction            │
│                │              │                               │
│                ▼              ▼                               │
│  customer ──▶ customer_financials ──▶ loan_current           │
│      │              │                     │                   │
│      ▼              ▼                     ▼                   │
│  financials_history          loan_history, loan_payment      │
│                                           │                   │
│  dataset_versions ──▶ ai_models ──▶ ai_predictions          │
│                           │              │                    │
│                           ▼              ▼                    │
│                  governance_decisions  ai_model_features      │
└─────────────────────────────────────────────────────────────┘
```

---

## File Structure

| File | Purpose |
|------|---------|
| `setup.sql` | Banking database schema + seed data (15 tables) |
| `01_vcs_schema.sql` | VCS metadata tables (config, repo, branch, commit, change, tag) |
| `02_vcs_core_functions.sql` | Core: `vcs_init`, `vcs_commit`, `vcs_status`, trigger system |
| `03_vcs_branch_functions.sql` | Branching: `vcs_branch_create`, `vcs_checkout`, `vcs_merge` |
| `04_vcs_history_functions.sql` | History: `vcs_log`, `vcs_diff`, `vcs_show`, `vcs_blame`, `vcs_tag` |
| `05_vcs_rollback_functions.sql` | Rollback: `vcs_rollback`, `vcs_time_travel`, `vcs_snapshot` |
| `06_demo_walkthrough.sql` | End-to-end demo exercising every feature (auto-resets on re-run) |


---

## Quick Start

### Prerequisites
- PostgreSQL 13+ (uses JSONB, `to_jsonb`, `jsonb_populate_record`)

### Installation

```sql
-- 1. Create the banking database
\i setup.sql

-- 2. Install the VCS system (MUST run in this order)
\i 01_vcs_schema.sql
\i 02_vcs_core_functions.sql
\i 03_vcs_branch_functions.sql
\i 04_vcs_history_functions.sql
\i 05_vcs_rollback_functions.sql

-- 3. Run the full demo
\i 06_demo_walkthrough.sql



## Usage Guide

### 1. Track a Table

```sql
-- Auto-detects primary key
SELECT vcs_init('customer');
SELECT vcs_init('account');

-- Or specify PK explicitly
SELECT vcs_init('my_table', 'my_pk_column');
```

### 2. Snapshot Existing Data

```sql
-- Capture current state as baseline commit
SELECT vcs_snapshot('customer');      -- single table
SELECT vcs_snapshot_all('v1.0 baseline'); -- all tracked tables
```

### 3. Make Changes & Commit

```sql
-- Changes are auto-staged by triggers
INSERT INTO customer VALUES ('CUST011', 'New Person', ...);
UPDATE customer SET phone = '555-9999' WHERE customer_id = 'CUST001';

-- Check what's staged
SELECT * FROM vcs_status();

-- Commit
SELECT vcs_commit('Added CUST011, updated CUST001 phone');
```

### 4. Branching

```sql
-- Create a branch (and optionally checkout)
SELECT vcs_branch_create('feature/loans', NULL, 'Loan experiments', TRUE);

-- List branches
SELECT * FROM vcs_branch_list();

-- Switch branches
SELECT vcs_checkout('main');
```

### 5. Merge

```sql
-- Merge feature into main (with conflict detection)
SELECT vcs_checkout('main');
SELECT vcs_merge('feature/loans');

-- Check for conflicts first
SELECT * FROM vcs_merge_conflicts('feature/loans', 'main');
```

### 6. View History

```sql
-- Commit log
SELECT * FROM vcs_log();            -- current branch
SELECT * FROM vcs_log_all();        -- all branches

-- Commit details
SELECT * FROM vcs_show(5);

-- Diff between commits
SELECT * FROM vcs_diff(2, 5);

-- Diff between branches
SELECT * FROM vcs_diff_branch('feature/loans', 'main');

-- Who last changed each row
SELECT * FROM vcs_blame('customer');

-- Full history of one row
SELECT * FROM vcs_row_history('customer', 'CUST001');
```

### 7. Tags

```sql
SELECT vcs_tag_create('v1.0', NULL, 'First release');
SELECT * FROM vcs_tag_list();
```

### 8. Rollback & Time Travel

```sql
-- Dry run first
SELECT vcs_rollback(3, NULL, TRUE);

-- Actually rollback
SELECT vcs_rollback(3);

-- View data at any historical commit
SELECT * FROM vcs_time_travel('customer', 2);

-- Reconstruct a single row at a point in time
SELECT vcs_reconstruct_at('customer', 'CUST001', 2);
```

---

## How It Works

### Change Tracking
When you call `vcs_init('table')`, a **trigger** is created on that table. Every INSERT, UPDATE, or DELETE automatically captures:
- The **operation** type
- The **old row data** (as JSONB) — for UPDATE and DELETE
- The **new row data** (as JSONB) — for INSERT and UPDATE
- Which **columns changed** (for UPDATE)

These go into the **staging area** (`vcs_staged_change`), associated with the currently active branch.

### Committing
`vcs_commit()` moves all staged changes into permanent storage (`vcs_change`), links them to a new commit record with a hash, message, author, and parent pointer — forming a **directed acyclic graph (DAG)** just like Git.

### Branching & Merging
Branches are lightweight pointers. Creating a branch records the **fork point** (which commit it branched from). Merging replays changes from the source branch that occurred after the fork point. **Conflict detection** checks if the same row (table + PK) was modified on both branches.

### Rollback
`vcs_rollback()` walks backward through committed changes and applies **inverse operations** (INSERT→DELETE, DELETE→INSERT, UPDATE→restore old values). The rollback itself is recorded as a new commit for full auditability.

---

## Function Reference

| Function | Git Equivalent | Description |
|----------|---------------|-------------|
| `vcs_init(table, pk)` | `git init` | Start tracking a table |
| `vcs_status(branch)` | `git status` | Show staged changes |
| `vcs_commit(msg, author)` | `git commit` | Commit staged changes |
| `vcs_discard(table)` | `git checkout -- .` | Discard staged changes |
| `vcs_branch_create(name, from, desc, checkout)` | `git branch` / `git checkout -b` | Create branch |
| `vcs_branch_list()` | `git branch -av` | List branches |
| `vcs_branch_delete(name)` | `git branch -d` | Delete branch |
| `vcs_checkout(branch)` | `git checkout` | Switch branch |
| `vcs_merge(source, target, msg)` | `git merge` | Merge with conflict detection |
| `vcs_merge_conflicts(src, tgt)` | Conflict markers | Show conflicting rows |
| `vcs_log(branch, limit)` | `git log` | Commit history |
| `vcs_log_all(limit)` | `git log --all` | All-branch history |
| `vcs_show(commit_id)` | `git show` | Commit details |
| `vcs_diff(a, b)` | `git diff a..b` | Compare commits |
| `vcs_diff_branch(a, b)` | `git diff branch_a..branch_b` | Compare branches |
| `vcs_tag_create(name, commit, msg)` | `git tag` | Create tag |
| `vcs_tag_list()` | `git tag -l` | List tags |
| `vcs_blame(table, branch)` | `git blame` | Last modifier per row |
| `vcs_row_history(table, pk)` | `git log -p -- file` | Full row history |
| `vcs_rollback(commit, table, dry)` | `git revert` | Rollback changes |
| `vcs_time_travel(table, commit)` | `git checkout rev -- file` | View historical state |
| `vcs_reconstruct_at(table, pk, commit)` | `git show rev:file` | Reconstruct row at commit |
| `vcs_snapshot(table, msg)` | `git add . && commit` | Snapshot current data |
| `vcs_snapshot_all(msg)` | Full repo snapshot | Snapshot all tracked tables |
| `vcs_get_active_branch()` | `git branch --show-current` | Current branch name |
| `vcs_get_head_commit(branch)` | `git rev-parse HEAD` | Latest commit ID |

---

## Demo Walkthrough Summary

The `06_demo_walkthrough.sql` script runs through this scenario:

1. **Init** — Track 10 banking tables
2. **Snapshot** — Baseline all data as v1.0
3. **Commit** — Add new customer CUST011, update CUST001 credit score
4. **Branch** — Create `feature/new-loan-product`
5. **Feature work** — Add premium loan on the feature branch
6. **Parallel work** — New transaction + employee on `main`
7. **History** — View logs, diffs, blame, row history, tags
8. **Merge** — Merge feature branch into main (conflict-free)
9. **Rollback** — Simulate accidental deletion, then rollback
10. **Time Travel** — View customer data as it was at v1.0

---

## Technical Notes

- **PostgreSQL 13+** required (JSONB functions, `jsonb_populate_record`)
- All VCS metadata lives in `vcs_*` tables — no modifications to your business schema
- Triggers are `AFTER` triggers — they don't block or slow DML significantly
- JSONB storage means schema evolution is handled naturally
- Commit hashes use MD5 (demonstrative; swap for `pgcrypto`'s `gen_random_uuid()` in production)
- Rollback creates a new "undo commit" rather than rewriting history (append-only audit trail)
