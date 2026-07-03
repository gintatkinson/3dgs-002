# Implementation Plan: Native GitHub Onboarding and Script Cleanup

This plan details the changes to remove the upstream-only bootstrapping script `scripts/bootstrap_downstream.py`, update `README.md` and `wiki/Configuration.md` to use the native GitHub template onboarding, and ensure generic placeholders are used for direct copy and submodule installation methods.

---

## Proposed Changes

### 1. Delete bootstrapping script
- **File**: `scripts/bootstrap_downstream.py`
- **Action**: Delete the file from the workspace using `git rm`.

### 2. Update README.md
- **File**: `README.md`
- **Action**: 
  - Replace Option 1 under the Installation section with the native GitHub template onboarding.
  - Make the clone/submodule commands in Option 2 and Option 3 use generic placeholders: `https://github.com/<owner>/<template-repo>.git`.
  - Remove any mention or usage of `bootstrap_downstream.py` in the document (including references in Step 0 of BDD workflow and the entire Seeding subsection under Downstream Baseline Seeding and Compliance).
  - Rename the section "Downstream Baseline Seeding and Compliance" to "Downstream Baseline Compliance".

### 3. Update wiki/Configuration.md
- **File**: `wiki/Configuration.md`
- **Action**:
  - Restructure Option 1 in the wiki setup guide to match the README format exactly (native GitHub template onboarding).
  - Make the clone/submodule commands in Option 2 and Option 3 use generic placeholders: `https://github.com/<owner>/<template-repo>.git`.
  - Remove any mention or usage of `bootstrap_downstream.py` in the document.

---

## Verification Plan

### Step 1: Verify the changes locally
- Check that `git diff` shows the correct edits in `README.md` and `wiki/Configuration.md`.
- Verify that `scripts/bootstrap_downstream.py` is successfully removed.

### Step 2: Commit and push changes
- Commit the changes.
- Push to `origin/main`.
- Verify that `git diff origin/main` is empty.
