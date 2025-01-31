#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2025 Josef Andersson
#
# SPDX-License-Identifier: MIT

# git-data-generator.sh - Generate Git branches, tags and commits
#
# Script for generating test data in Git repositories:
# - Creates specified number of branches with random files
# - Adds realistic-looking tags across commit history
# - Generates commits with random content
#
# Usage: ./git-data-generator.sh [--branches|--tags|--commits] count

set -o errexit
set -o pipefail
set -o nounset

readonly DEFAULT_BRANCH="main"

usage() {
  printf "Usage: %s [--branches|--tags|--commits] count\n" "$0" >&2
  exit 1
}

validate_count() {
  local count=$1
  if [[ ! $count =~ ^[1-9][0-9]*$ ]]; then
    printf "Error: Count must be a positive number\n" >&2
    exit 1
  fi
}

parse_args() {
  if (($# != 2)); then
    printf "Error: Expected 2 arguments\n" >&2
    usage
  fi

  case "$1" in
  --branches | --tags | --commits)
    declare -g mode="${1#--}"
    ;;
  *)
    printf "Error: Invalid mode %s\n" "$1" >&2
    usage
    ;;
  esac

  validate_count "$2"
  declare -g count="$2"
}

validate_repository() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf "Error: Not in a git repository\n" >&2
    exit 1
  fi

  if [[ ! "$(git symbolic-ref --short HEAD 2>/dev/null)" == "$DEFAULT_BRANCH" ]]; then
    printf "Error: Branch %s not found\n" "$DEFAULT_BRANCH" >&2
    exit 1
  fi

}

generate_random_file() {
  local filename=$1
  local size=${2:-300}
  head -c "$size" /dev/urandom | base64 >"$filename"
}

generate_branches() {
  local branch_name filename
  local i=1

  while ((i <= count)); do
    branch_name="feature_branch_$i"
    filename="branch_file_$i.txt"

    git checkout -b "$branch_name" || continue
    generate_random_file "$filename" 200
    git add "$filename"
    git commit -m "Add file to branch $branch_name"
    git checkout "$DEFAULT_BRANCH"

    if ((i % 20 == 0)); then
      printf "Created %d branches\n" "$i"
    fi
    ((i++))
  done
}

generate_version() {
  local major=$((RANDOM % 20))
  local minor=$((RANDOM % 50))
  local patch=$((RANDOM % 100))

  if ((RANDOM % 100 < 30)); then
    printf "%d.%d" "$major" "$minor"
  else
    printf "%d.%d.%d" "$major" "$minor" "$patch"
  fi
}

generate_tag_name() {
  local -ra prefixes=("v" "release-" "version-" "" "stable-" "prod-")
  local -ra suffixes=("" "-stable" "-release" "-LTS" "-beta" "-rc1" "-final")

  local prefix=${prefixes[$((RANDOM % ${#prefixes[@]}))]}
  local suffix=${suffixes[$((RANDOM % ${#suffixes[@]}))]}
  local version
  version=$(generate_version)

  printf "%s%s%s" "$prefix" "$version" "$suffix"
}

generate_tag_message() {
  local version=$1
  local -ra messages=(
    "Release %s"
    "Version %s release"
    "Stable release %s"
    "Production release %s"
    "Release candidate %s"
    "Long term support release %s"
  )
  random_index=$((RANDOM % ${#messages[@]}))
  message="${messages[$random_index]}"
  formatted_message="$(printf "%s" "$message" "$version")"
  printf "%s\n" "$formatted_message"
}

generate_tags() {
  local -a commit_hashes
  mapfile -t commit_hashes < <(git log --format="%H" "$DEFAULT_BRANCH")
  local total_commits=${#commit_hashes[@]}
  local i=1

  while ((i <= count)); do
    local tag_name version commit_hash
    version=$(generate_version)
    tag_name=$(generate_tag_name)

    if ((i % 20 == 0)) && ((i > 20)); then
      commit_hash=${commit_hashes[$((RANDOM % 20))]}
    else
      commit_hash=${commit_hashes[$((RANDOM % total_commits))]}
    fi

    if git tag -a "$tag_name" "$commit_hash" -m "$(generate_tag_message "$version")"; then
      if ((i % 25 == 0)); then
        printf "Created %d tags\n" "$i"
      fi
      ((i++))
    fi
  done

  printf "Created %d tags\n" "$count"
  printf "Sample of last 10 tags:\n%s\n" "$(git tag | tail -n 10)"
}

generate_commits() {
  local i=1
  local filename

  while ((i <= count)); do
    filename="random_file_$i.txt"
    generate_random_file "$filename"

    if git add "$filename" && git commit -m "Random commit number $i"; then
      if ((i % 100 == 0)); then
        printf "Created %d commits\n" "$i"
      fi
      ((i++))
    fi
  done
}

main() {
  parse_args "$@"
  validate_repository

  case "$mode" in
  branches) generate_branches ;;
  tags) generate_tags ;;
  commits) generate_commits ;;
  *)
    printf "Error: Invalid mode\n" >&2
    exit 1
    ;;
  esac
}

main "$@"
