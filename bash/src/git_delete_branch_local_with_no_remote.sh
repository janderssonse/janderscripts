#!/bin/bash
#
# SPDX-FileCopyrightText: 2025 Josef Andersson
#
# SPDX-License-Identifier: MIT

# git-delete-branch-local-with-no-remote.sh
#
# Remove local git branches that no longer exist on remote
#
# Options:
#   --dry-run  Show what would be deleted without actually deleting
#   --force-delete Force delete branches even if not merged
#
# Usage: ./git-delete-branch-local-with-no-remote.sh [--dry-run] [--force-delete] /path/to/git/repository

set -euo pipefail

declare -g DRY_RUN=false
declare -g DELETE_FLAG="-d"
declare -g REPO_PATH=""
declare -g -a DELETED_BRANCHES=()

# Define colors
declare -g RED='\033[0;31m'
declare -g GREEN='\033[0;32m'
declare -g YELLOW='\033[1;33m'
declare -g NC='\033[0m' # No Color

# Update error messages with red
parse_args() {
  local has_path=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
    --dry-run)
      export DRY_RUN=true
      ;;
    --force-delete)
      export DELETE_FLAG="-D"
      ;;
    -*)
      printf "${RED}Error: Unknown option: %s${NC}\n" "$1" >&2
      printf "Usage: %s [--dry-run] [--force-delete] /path/to/git/repository\n" "$0" >&2
      exit 1
      ;;
    *)
      if [ "$has_path" = true ]; then
        printf "%sError: Multiple paths provided. Path must be the last argument.%s\n" "$RED" "$NC" >&2
        exit 1
      fi
      export REPO_PATH="$1"
      has_path=true
      ;;
    esac
    shift
  done
}

check_repository() {
  if [ -z "${REPO_PATH:-}" ]; then
    printf "%sError: Path argument is required%s\n" "$RED" "$NC" >&2
    printf "Usage: %s [--dry-run] [--force-delete] /path/to/git/repository\n" "$0" >&2
    exit 1
  fi
  REPO_PATH=$(realpath -q "$REPO_PATH" 2>/dev/null || printf '%s' "$REPO_PATH")
  if [ ! -d "$REPO_PATH" ]; then
    printf "${RED}Error: Directory '%s' does not exist${NC}\n" "$REPO_PATH" >&2
    exit 1
  fi
  if [ ! -d "$REPO_PATH/.git" ] && [ ! -f "$REPO_PATH/.git" ]; then
    printf "${RED}Error: '%s' is not a git repository${NC}\n" "$REPO_PATH" >&2
    exit 1
  fi
  if [ ! -x "$REPO_PATH" ]; then
    printf "${RED}Error: No permission to access '%s'${NC}\n" "$REPO_PATH" >&2
    exit 1
  fi
  cd "$REPO_PATH" || exit 1
}

get_deleted_branches() {
  mapfile -t DELETED_BRANCHES < <(LANG=C git branch -vv | grep '\[.*: gone\]' | awk '{print $1}')
}

delete_branches() {
  local branch
  for branch in "${DELETED_BRANCHES[@]}"; do
    if [ -z "$branch" ]; then
      continue
    fi
    if git branch "${DELETE_FLAG}" "${branch}"; then
      printf "%sDeleted branch: %s%s\n" "$GREEN" "${branch}" "$NC"
    else
      printf "%sFailed to delete branch: %s%s\n" "$RED" "${branch}" "$NC" >&2
    fi
  done

  printf "%sBranch cleanup complete.%s\n" "$GREEN" "$NC"
}

main() {
  parse_args "$@"
  check_repository
  if ! git fetch -p; then
    printf "%sError: Failed to fetch from remote%s\n" "$RED" "$NC" >&2
    exit 1
  fi

  get_deleted_branches

  if [ ${#DELETED_BRANCHES[@]} -eq 0 ]; then
    printf "%sNo stale branches found.%s\n" "$GREEN" "$NC"
    exit 0
  fi

  printf "%sThe following branches will be deleted:%s\n" "$YELLOW" "$NC"
  printf "%s\n" "${DELETED_BRANCHES[@]}"
  printf "\n"

  if [ "$DRY_RUN" = true ]; then
    printf "%sDry run complete. No branches were deleted.%s\n" "$YELLOW" "$NC"
    exit 0
  fi

  read -rp "Proceed with deletion? (y/n): " confirm
  if [ "${confirm,,}" = "y" ]; then
    delete_branches
  else
    printf "%sOperation cancelled.%s\n" "$YELLOW" "$NC"
  fi
}

main "$@"
