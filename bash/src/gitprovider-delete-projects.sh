#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2025 Josef Andersson
#
# SPDX-License-Identifier: MIT

# shellcheck disable=SC2016  # Allow $ in printf formats
# shellcheck disable=SC2155  # Allow inline declarations
#
# Enhanced Project cleanup helper for GitHub and GitLab
# Allows selecting and deleting projects interactively using fzf
#
# Required Permissions:
# GitHub:
#   Fine-grained tokens (recommended):
#   - 'Delete repositories' (Read and Write)
#   - 'Metadata' (Read-only, automatically included)
#   Classic tokens:
#   - 'delete_repo' scope
#   - 'repo' scope
#
# GitLab:
#   - 'api' scope
#   - 'read_repository' scope
#   - 'read_api' scope
#   - Maintainer role or higher
#
# Usage: ./project-cleanup.sh --provider [github|gitlab]
#
set -o errexit
set -o pipefail
set -o nounset

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

readonly RATE_LIMIT_DELAY=0.25
readonly REQUIRED_CMDS=("jq" "fzf" "curl")

# Global variables
declare -g PROVIDER=""
declare -g DEBUG=false

# Logging functions
log_error() { printf "${RED}Error: %s${NC}\n" "$1" >&2; }
log_warning() { printf "${YELLOW}Warning: %s${NC}\n" "$1" >&2; }
log_success() { printf "${GREEN}%s${NC}\n" "$1"; }
log_info() { printf "${BLUE}%s${NC}\n" "$1"; }
log_debug() { [[ "$DEBUG" == "true" ]] && printf "Debug: %s\n" "$1" >&2; }

die() {
  log_error "$1"
  exit "${2:-1}"
}

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] --provider [github|gitlab]

Options:
    -h, --help              Show this help message
    -p, --provider TYPE     Specify provider (github or gitlab)
    -d, --debug            Enable debug output
    
Examples:
    $(basename "$0") --provider github
    $(basename "$0") --provider gitlab --quiet
    
For more information, visit: https://github.com/yourusername/project-cleanup
EOF
  exit 0
}

validate_dependencies() {
  local missing_deps=()

  for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_deps+=("$cmd")
    fi
  done

  # Check for provider-specific CLI tools
  if [[ "$PROVIDER" == "github" ]] && ! command -v gh >/dev/null 2>&1; then
    missing_deps+=("gh")
  elif [[ "$PROVIDER" == "gitlab" ]] && ! command -v glab >/dev/null 2>&1; then
    missing_deps+=("glab")
  fi

  if ((${#missing_deps[@]} > 0)); then
    log_error "Missing required dependencies: ${missing_deps[*]}"
    cat <<EOF

Please install the missing dependencies:
$(printf "  - %s\n" "${missing_deps[@]}")

Installation guides:
  - fzf: https://github.com/junegunn/fzf#installation
  - jq: https://stedolan.github.io/jq/download/
  - gh: https://cli.github.com/
  - glab: https://gitlab.com/gitlab-org/cli#installation
EOF
    exit 1
  fi
}

validate_token() {
  local token_var="${PROVIDER^^}_TOKEN"
  if [[ -z "${!token_var:-}" ]]; then
    die "${token_var} environment variable is not set" 1
  fi

  # Test token validity
  local test_response=""
  if [[ "$PROVIDER" == "github" ]]; then
    if ! test_response=$(gh api /user 2>&1); then
      die "Invalid GitHub token or API error: ${test_response}" 1
    fi
  elif [[ "$PROVIDER" == "gitlab" ]]; then
    if ! test_response=$(glab api /user 2>&1); then
      die "Invalid GitLab token or API error: ${test_response}" 1
    fi
  fi
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
    -h | --help)
      show_help
      ;;
    -p | --provider)
      shift
      if [[ "$1" != "github" && "$1" != "gitlab" ]]; then
        die "Invalid provider. Must be 'github' or 'gitlab'" 1
      fi
      PROVIDER="$1"
      ;;
    -d | --debug)
      DEBUG=true
      ;;
    *)
      die "Unknown option: $1" 1
      ;;
    esac
    shift
  done

  if [[ -z "$PROVIDER" ]]; then
    die "Missing required --provider argument" 1
  fi
}

format_preview() {
  local -r data="$1"
  local -r provider="$2"
  local id name description visibility url updated

  # Extract data fields
  id=$(cut -f1 <<<"$data")
  name=$(cut -f2 <<<"$data")
  visibility=$(cut -f3 <<<"$data")
  description=$(cut -f4 <<<"$data")
  updated=$(cut -f5 <<<"$data")
  url=$(cut -f6 <<<"$data")

  # Get terminal width for the preview window
  local width
  width=$(tput cols)
  # Adjust width for preview window (60% of terminal)
  width=$((width * 60 / 100 - 4))

  # Function to create a line of specified length
  create_line() {
    local char=$1
    local length=$2
    printf '%*s' "${length}" '' | tr ' ' "${char}"
  }

  # Function to create a horizontal border
  create_border() {
    local left=$1
    local middle=$2
    local right=$3
    echo "$left$(create_line "$middle" $((width - 2)))$right"
  }

  # Create borders
  local top_border=$(create_border "╭" "─" "╮")
  local bottom_border=$(create_border "╰" "─" "╯")
  local mid_border=$(create_border "├" "─" "┤")

  # Format visibility for display
  if [[ "$provider" == "github" ]]; then
    visibility=$(if [[ "$visibility" == "true" ]]; then echo "Private"; else echo "Public"; fi)
  else
    visibility="${visibility^}"
  fi

  # Format date
  local formatted_date
  formatted_date=$(date -d "$updated" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$updated")

  # Function to wrap text to width
  wrap_text() {
    local text=$1
    local prefix=$2
    local max_length=$((width - ${#prefix} - 2))

    if [[ -z "$text" ]]; then
      echo "${prefix}No description available"
      return
    fi

    local line=""
    for word in $text; do
      if ((${#line} + ${#word} + 1 < max_length)); then
        [[ -n "$line" ]] && line+=" "
        line+="$word"
      else
        echo "${prefix}${line}"
        line="$word"
      fi
    done
    [[ -n "$line" ]] && echo "${prefix}${line}"
  }

  # Create the preview with dynamic width and empty lines between fields
  {
    echo "$top_border"
    echo "│ 📁 Project:     $name"
    echo "│"
    echo "│ 🔒 Visibility:  $visibility"
    echo "│"
    if [[ "$provider" == "gitlab" ]]; then
      echo "│ 🆔 Project ID:   $id"
      echo "│"
    fi
    echo "$mid_border"
    echo "│ 📝 Description:"
    echo "│"
    wrap_text "$description" "│ "
    echo "│"
    echo "$mid_border"
    echo "│ 🔗 URL:"
    echo "│ $url"
    echo "│"
    echo "│ 🕒 Last Update:"
    echo "│ $formatted_date"
    if [[ "$provider" == "gitlab" ]]; then
      echo "│"
      echo "$mid_border"
      echo "│ 🛠️  Additional Details:"
      echo "│"
      echo "│ • Project Path:"
      echo "│   $name"
      echo "│"
      echo "│ • Access Level:"
      echo "│   Maintainer or higher"
    fi
    echo "$bottom_border"
  }
}

gitlab_projects_jqscript() {
  cat <<'EOF'
.[]
| [
    .id,
    .path_with_namespace,
    .visibility,
    .description,
    .last_activity_at,
    .web_url
  ]
| @tsv
EOF
}

github_projects_jqscript() {
  cat <<'EOF'
.[]
| [
    .id,
    .full_name,
    .private,
    .description,
    .updated_at,
    .html_url
  ]
| @tsv
EOF
}

select_projects() {
  local preview_cmd='echo {} | format_preview {} '"$PROVIDER"
  local api_data sorted_data
  local spinner=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local i=0

  # Show loading spinner
  printf "Fetching %s projects... " "$PROVIDER"
  tput sc # Save cursor position

  # Start spinner in background
  while :; do
    tput rc # Restore cursor position
    printf "%s" "${spinner[i]}"
    i=$(((i + 1) % ${#spinner[@]}))
    sleep 0.1
  done &
  local spinner_pid=$!

  # Fetch data
  if [[ "$PROVIDER" == "github" ]]; then
    if ! api_data=$(gh api --paginate "/user/repos?sort=updated&per_page=100" 2>/dev/null); then
      kill "$spinner_pid"
      die "Failed to fetch GitHub repositories. Please check your permissions." 1
    fi
    sorted_data=$(echo "$api_data" | jq -r -f <(github_projects_jqscript) | sort -k5)
  elif [[ "$PROVIDER" == "gitlab" ]]; then
    if ! api_data=$(glab api "projects?min_access_level=40&order_by=updated_at&per_page=100" --paginate 2>/dev/null); then
      kill "$spinner_pid"
      die "Failed to fetch GitLab projects. Please check your permissions." 1
    fi
    sorted_data=$(echo "$api_data" | jq -r -f <(gitlab_projects_jqscript) | sort -k5)
  fi

  # Kill spinner and clear line
  kill "$spinner_pid" 2>/dev/null || true
  wait "$spinner_pid" 2>/dev/null || true
  printf "\r\\033[K" # Clear line

  if [[ -z "$sorted_data" ]]; then
    log_warning "No projects found to display"
    exit 0
  fi

  echo "$sorted_data" | fzf --multi \
    --header="╭──── Project Selection ────────────────────────────────────────────╮
│ • Tab: Select/unselect   • Enter: Confirm   • Ctrl-A: Select all  │
│ • Ctrl-D: Deselect all   • Ctrl-P: Preview  • Q: Quit             │
╰───────────────────────────────────────────────────────────────────╯" \
    --preview="echo {} | $preview_cmd" \
    --preview-window="right:60%:wrap" \
    --bind="ctrl-a:toggle-all" \
    --bind="ctrl-d:deselect-all" \
    --bind="ctrl-p:toggle-preview" \
    --bind="ctrl-/:change-preview-window(right:80%|right:60%)" \
    --bind="esc:abort" \
    --bind="ctrl-c:abort" \
    --bind="q:abort" \
    --delimiter='\t' \
    --with-nth=2 \
    --reverse \
    --no-mouse \
    --exit-0
}

delete_project() {
  local item=$1
  local id name
  local response

  id=$(cut -f1 <<<"$item")
  name=$(cut -f2 <<<"$item")

  # Create confirmation dialog content
  local confirm_text
  confirm_text=$(
    cat <<EOF
╭──────────── WARNING ────────────╮
│                                 │
│  ⚠️  This cannot be undone!     │
│                                 │
│  Project: $name
│                                 │
│  Use arrows and Enter to select │
│                                 │
╰─────────────────────────────────╯
EOF
  )

  # Show confirmation dialog
  response=$(printf "No\nYes" | fzf \
    --height=15 \
    --reverse \
    --header="$confirm_text" \
    --pointer="▶" \
    --marker="✓" \
    --prompt="Delete this project? " \
    --border=rounded \
    --no-mouse \
    --no-info \
    --color='header:italic:red' \
    --bind="ctrl-c:abort" \
    --bind="esc:abort" \
    --bind="up:up,down:down" \
    --cycle) || response="No"

  # If no selection was made (Esc/Ctrl-C) or "No" was selected
  if [[ -z "$response" ]] || [[ "$response" != "Yes" ]]; then
    return 2 # Special return code for "No" selection
  fi

  # Only proceed with deletion if "Yes" was explicitly selected
  if [[ "$PROVIDER" == "github" ]]; then
    if ! gh api -X DELETE "/repos/$name" 2>/dev/null; then
      log_error "Failed to delete GitHub repository: $name"
      return 1
    fi
  elif [[ "$PROVIDER" == "gitlab" ]]; then
    if ! glab repo delete "$name" --yes 2>/dev/null; then
      log_error "Failed to delete GitLab project: $name"
      return 1
    fi
  fi

  log_success "✓ Successfully deleted project: $name"
  return 0
}

cleanup() {
  # Reset terminal
  tput cnorm         # Show cursor
  printf "\033[?25h" # Ensure cursor is visible
  exit 0
}
main() {
  # Set up trap for cleanup
  trap cleanup EXIT INT TERM

  parse_args "$@"
  validate_dependencies
  validate_token

  # Hide cursor during selection
  tput civis

  # Export required functions and variables for fzf
  export -f format_preview
  export RED GREEN YELLOW BLUE NC BOLD

  while true; do
    # Capture fzf exit code and output
    local fzf_output
    if ! fzf_output=$(select_projects); then
      # fzf was aborted
      tput cnorm # Show cursor
      log_info "Operation cancelled"
      exit 0
    fi

    # Create array from output only if we have data
    local -a selected_items=()
    if [[ -n "$fzf_output" ]]; then
      mapfile -t selected_items <<<"$fzf_output"
    fi

    # Exit cleanly if no items selected
    if ((${#selected_items[@]} == 0)); then
      tput cnorm
      log_info "No projects selected for deletion"
      exit 0
    fi

    local count=0
    local total=${#selected_items[@]}
    local item
    local continue_selection=false

    set +o errexit
    for item in "${selected_items[@]}"; do
      delete_project "$item"
      local delete_status=$?

      if [[ $delete_status -eq 2 ]]; then
        # User selected "No" in confirmation, continue selection
        continue_selection=true
        break
      elif [[ $delete_status -eq 0 ]]; then
        ((count++))
        sleep "$RATE_LIMIT_DELAY"
      fi
    done
    set -o errexit

    if [[ "$continue_selection" == "true" ]]; then
      # Return to selection view
      continue
    fi

    # Show final results and exit
    printf "\n"
    if ((count > 0)); then
      if ((count == total)); then
        log_success "Successfully deleted all $count projects"
      else
        log_warning "Deleted $count out of $total projects"
      fi
    fi
    break
  done

  tput cnorm
}

main "$@"
