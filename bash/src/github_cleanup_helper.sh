#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2025 Josef Andersson
#
# SPDX-License-Identifier: MIT

# github-cleanup-helper.sh
#
# Delete GitHub deployments, workflow runs, and caches interactively
#
# Script provides interactive selection and deletion of GitHub deployments,
# workflow runs, and caches using fzf for selection. Uses GitHub CLI for API calls.
#
# Required GitHub Token Permissions:
# - For deployments: 'deployments' (read/write)
# - For workflow runs and caches: 'actions' (read/write)
#
# Usage: ./github-cleanup-helper.sh [--deployments|--workflowruns|--caches] owner/repo
# Requires: gh CLI, jq, fzf and GITHUB_TOKEN environment variable

set -o errexit
set -o pipefail
set -o nounset

readonly RATE_LIMIT_DELAY=0.25
readonly REQUIRED_CMDS=("gh" "jq" "fzf")

# Global variables
declare -g MODE=""
declare -g REPO=""
declare -g API_BASE=""

usage() {
  printf "Usage: %s [--deployments|--workflowruns|--caches] owner/repo\n" "$0" >&2
  exit 1
}

validate_token_permissions() {
  local required_scope
  local permission_level

  # Set required scope based on MODE
  if [[ "$MODE" == "deployments" ]]; then
    required_scope="deployments"
  else
    required_scope="actions" # Both workflow runs and caches use actions scope
  fi

  # Check token scopes
  local scopes
  if ! scopes=$(gh api /user --jq '.permissions' 2>/dev/null); then
    printf "Error: Unable to fetch token permissions.\n" >&2
    exit 1
  fi

  # Check if required scope exists and has write permission
  permission_level=$(echo "$scopes" | jq -r ".$required_scope // \"none\"")

  if [[ "$permission_level" == "none" || "$permission_level" == "null" ]]; then
    printf "Error: Token does not have '%s' scope.\n" "$required_scope" >&2
    printf "Please ensure your token has '%s' write permission.\n" "$required_scope" >&2
    exit 1
  elif [[ "$permission_level" != "write" && "$permission_level" != "admin" ]]; then
    printf "Error: Token has '%s' scope but lacks write permission.\n" "$required_scope" >&2
    printf "Current permission level: %s\n" "$permission_level" >&2
    printf "Please ensure your token has '%s' write permission.\n" "$required_scope" >&2
    exit 1
  fi

  printf "Token permissions verified for %s operations.\n" "$required_scope"
  return 0
}

validate_dependencies() {
  local cmd
  for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf "Error: Required command '%s' not found\n" "$cmd" >&2
      exit 1
    fi
  done
}

validate_token() {
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    printf "Error: GITHUB_TOKEN environment variable is not set\n" >&2
    exit 1
  fi
}

validate_repo() {
  local repo=$1
  if [[ ! $repo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    printf "Error: Invalid repository format '%s'. Expected 'owner/repo'\n" "$repo" >&2
    usage
  fi
}

parse_args() {
  local -A args=()

  if (($# < 2)); then
    printf "Error: Missing required arguments\n" >&2
    usage
  fi

  while (($# > 0)); do
    case "$1" in
    --deployments | --workflowruns | --caches)
      args[mode]="${1#--}"
      shift
      ;;
    -*)
      printf "Error: Unknown option '%s'\n" "$1" >&2
      usage
      ;;
    *)
      if [[ -n "${args[repo]:-}" ]]; then
        printf "Error: Multiple repository arguments provided\n" >&2
        usage
      fi
      args[repo]="$1"
      shift
      ;;
    esac
  done

  if [[ -z "${args[mode]:-}" ]]; then
    printf "Error: Mode (--deployments, --workflowruns, or --caches) not specified\n" >&2
    usage
  fi

  if [[ -z "${args[repo]:-}" ]]; then
    printf "Error: Repository not specified\n" >&2
    usage
  fi

  validate_repo "${args[repo]}"

  MODE="${args[mode]}"
  REPO="${args[repo]}"
  API_BASE="/repos/$REPO/$MODE"
}

deployments_jqscript() {
  cat <<'EOF'
.[]
| [
   .id,
   .environment,
   .created_at,
   .sha[0:7],
   .ref
 ]
| @tsv
EOF
}

workflowruns_jqscript() {
  cat <<'EOF'
def symbol:
   sub("skipped"; "⏭️ ") |
   sub("success"; "✅") |
   sub("failure"; "❌") |
   sub("cancelled"; "⭕") |
   sub("null"; "🔄");
def tz:
   gsub("[TZ]"; " ");
.workflow_runs[]
   | [
       (.conclusion // "null" | symbol),
       (.created_at | tz),
       .id,
       .event,
       .name,
       .head_branch
     ]
   | @tsv
EOF
}

caches_jqscript() {
  cat <<'EOF'
.actions_caches
| sort_by(.last_accessed_at)
| reverse
| .[]
| [
    .id,
    .key,
    (.size_in_bytes / 1024 / 1024 | floor | tostring + "MB"),
    .last_accessed_at,
    .version
  ]
| @tsv
EOF
}

select_items() {
  local preview_cmd=""
  local api_data=""
  local sorted_data=""
  local api_endpoint=""

  # Set API endpoint and preview command based on MODE
  if [[ "$MODE" == "deployments" ]]; then
    api_endpoint="$API_BASE"
    preview_cmd="echo {} | cut -f1 | xargs -I{} gh api $API_BASE/{}"
  elif [[ "$MODE" == "caches" ]]; then
    api_endpoint="/repos/$REPO/actions/caches"
    preview_cmd="echo {} | cut -f1,2 | awk '{print \"Cache ID: \"\$1\"\nKey: \"\$2}'"
  else
    api_endpoint="/repos/$REPO/actions/runs"
    preview_cmd="echo {} | cut -f3 | xargs -I{} gh api /repos/$REPO/actions/runs/{} | jq -r '.head_commit.message // \"No commit message\"'"
  fi

  # Get and process API data
  if [[ "$MODE" == "deployments" ]]; then
    if ! api_data=$(gh api --paginate "$api_endpoint" 2>/dev/null); then
      echo "Error: Failed to fetch deployments. Please check your permissions." >&2
      exit 1
    fi
    sorted_data=$(echo "$api_data" | jq -r -f <(deployments_jqscript) | sort -k3)
  elif [[ "$MODE" == "caches" ]]; then
    if ! api_data=$(gh api --paginate "$api_endpoint" 2>/dev/null); then
      echo "Error: Failed to fetch caches. Please check your permissions." >&2
      exit 1
    fi
    sorted_data=$(echo "$api_data" | jq -r -f <(caches_jqscript))
  else
    if ! api_data=$(gh api --paginate "$api_endpoint" 2>/dev/null); then
      echo "Error: Failed to fetch workflow runs. Please check your permissions." >&2
      exit 1
    fi
    sorted_data=$(echo "$api_data" | jq -r -f <(workflowruns_jqscript) | sort -k2)
  fi

  # Only call fzf if we have data
  if [[ -n "$sorted_data" ]]; then
    echo "$sorted_data" | fzf --multi \
      --header="Select items to delete (Tab to multi-select)" \
      --preview-window="right:50%" \
      --preview="$preview_cmd" \
      --reverse
  else
    echo "No data found to display" >&2
    exit 1
  fi
}

delete_item() {
  local item=$1
  local id
  local delete_endpoint=""

  if [[ "$MODE" == "deployments" ]]; then
    id=$(cut -f1 <<<"$item")
    delete_endpoint="$API_BASE/$id"
  elif [[ "$MODE" == "caches" ]]; then
    id=$(cut -f1 <<<"$item")
    delete_endpoint="/repos/$REPO/actions/caches/$id"
  else
    id=$(cut -f3 <<<"$item")
    delete_endpoint="/repos/$REPO/actions/runs/$id"
  fi

  if ! gh api -X DELETE "$delete_endpoint" 2>/dev/null; then
    printf "Failed to delete item with ID: %s\n" "$id" >&2
    return 1
  fi
  printf "Deleted item with ID: %s\n" "$id"
  return 0
}

main() {
  validate_dependencies
  validate_token
  parse_args "$@"
  ##  validate_token_permissions

  local -a selected_items
  mapfile -t selected_items < <(select_items)

  if ((${#selected_items[@]} == 0)); then
    printf "No items selected for deletion\n"
    exit 0
  fi

  local count=0
  local item

  set +o errexit
  for item in "${selected_items[@]}"; do
    if delete_item "$item"; then
      ((count++))
      sleep "$RATE_LIMIT_DELAY"
    fi
  done
  set -o errexit

  printf "Successfully deleted %d %s\n" "$count" "$MODE"
}

main "$@"
