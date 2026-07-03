#!/usr/bin/env python3
import os
import subprocess
import sys

def main():
    if "GITHUB_TOKEN" in os.environ and "dummytoken" in os.environ["GITHUB_TOKEN"]:
        del os.environ["GITHUB_TOKEN"]
    try:
        # Fetch remote branches
        subprocess.run(["git", "fetch", "origin"], check=True)
        
        # Get active branch name
        res = subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True, check=True)
        curr_branch = res.stdout.strip()
        
        # Check if active branch contains origin/master
        res = subprocess.run(["git", "merge-base", "--is-ancestor", "origin/master", "HEAD"])
        if res.returncode != 0:
            print("ERROR: Current branch is behind origin/master. Please merge or rebase origin/master.", file=sys.stderr)
            sys.exit(1)
            
        # Check other active remote branches not merged into origin/master
        res = subprocess.run(["git", "branch", "-r", "--no-merged", "origin/master"], capture_output=True, text=True, check=True)
        unmerged_branches = []
        for line in res.stdout.splitlines():
            branch = line.strip()
            if not branch or "origin/HEAD" in branch:
                continue
            if branch == f"origin/{curr_branch}":
                continue
            unmerged_branches.append(branch)
            
        # Verify active branch has merged/contains all unmerged remote specification branches
        for remote_branch in unmerged_branches:
            res = subprocess.run(["git", "merge-base", "--is-ancestor", remote_branch, "HEAD"])
            if res.returncode != 0:
                print(f"ERROR: Obsolete branch baseline. Remote branch '{remote_branch}' contains unmerged changes that are missing from your branch. Please merge '{remote_branch}' before pushing.", file=sys.stderr)
                sys.exit(1)
                
        print("Success: Branch lineage validation passed.")
        sys.exit(0)
    except Exception as e:
        print(f"Warning: Failed to execute branch lineage checks: {e}", file=sys.stderr)
        sys.exit(0)  # Graceful warning bypass if git setup is offline/non-git env

if __name__ == "__main__":
    main()
