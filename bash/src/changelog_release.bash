#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Josef Andersson
#
# SPDX-License-Identifier: MIT

# Glues together operations for
# * Setting or increase git tag,
# * Setting the version in the project file
# * Generate a changelog
# * Commit the changelog and updated project file in "release commit" which con.
#
# At least add support for gradle,
# Add support for generating GitHub/Lab release
#

# abort on nonzero exitstatus
set -o errexit
# don't hide errors within pipes
set -o pipefail
# Allow error traps on function calls, subshell environment, and command substitutions
set -o errtrace

INPUT_GIT_BRANCH_NAME="none"
INPUT_GIT_HOST_NAME="gitlab.com"
INPUT_IS_INTERACTIVE=""
INPUT_PROJECT_TYPE=""
INPUT_SEMVER_SCOPE="minor"
INPUT_TAG=""

# ---
PROJECT_FILE=""
NEXT_TAG=""
SKIP_ACTION='n'

# - Fancy colours
readonly RED=$'\e[31m'
readonly NC=$'\e[0m'
readonly GREEN=$'\e[32m'
readonly YELLOW=$'\e[0;33m'

check_interactive() {

  if [[ "${INPUT_IS_INTERACTIVE}" == 'y' ]]; then
    SKIP_ACTION=''
    local user_info=$1
    read -r -n 1 -p "${user_info}" SKIP_ACTION
    #TODO verify char is y or n
  fi
}

err() {
  printf "\n"
  printf "%s\n" "$* ----- [$(date +'%Y-%m-%dT%H:%M:%S%z')]" >&2
  exit 1
}

info() {
  printf "\n"
  printf "%s\n" "$@"
}

validate_semver() {

  local ver=$1
  local is_tag_semver="valid"

  is_tag_semver=$(semver validate "${ver}")

  if [[ "${is_tag_semver}" == "invalid" ]]; then
    err "Tag ${ver} is invalid semver, can't calculate next tag from that, sorry."
  fi
}

validate_input() {

  local current_branch
  current_branch=$(git branch --show-current)

  # Warn for potential git branch mismatch
  if [[ "${INPUT_GIT_BRANCH_NAME}" != "none" && "${INPUT_GIT_BRANCH_NAME}" != "${current_branch}" ]]; then

    err "${RED} You are running the script from branch: ${current_branch} and would like to push to: ${INPUT_GIT_BRANCH_NAME}.${NC}" \
      "${GREEN} To help avoid misfortunes with pushes, run the script from same branch you will push to. Use with${NC} -b /--git-branch-name option."
  fi

  #Validate given tag
  if [[ -n "${INPUT_TAG}" ]]; then
    validate_semver "${INPUT_TAG}"
  fi

}

usage() {

  info \
    "${GREEN}Usage:${NC} changelog_release [-h][-d][-i][-s semver-scope][-p project-type][-b git-branch-name]" \
    "" \
    "changelog_release is a glue for the process of bumping git tag, generate a changelog, update project file version" \
    " and generating a release commit." \
    "Using conventional commits." \
    "Run it from the root of your git project structure." \
    "" \
    "Available options:" \
    "" \
    " -h --help            Print this help and exit" \
    " -d --debug           Output extra script run information" \
    " -s --semver-scope    Semver scope for next tag when autoidentify <major|minor|patch>. Default: minor" \
    " -t --next-tag        Specify next tag instead of autoidentify" \
    " -p --project-type    Which project type <npm|mvn|gradle>. Default: try autoidentify by existing file." \
    " -b --git-branch-name Git branch name to push to (any_name). 'none' skips push. Default: none. " \
    " --git-host-name   Git host for Changelog diff links. Default: 'gitlab.com'. " \
    " -i --interactive     The script asks for tag naming input instead of calculating next, etc."
  exit 0
}

is_command_installed() {

  local prog=$1
  local link=$2

  if ! [[ -x "$(command -v "${prog}")" ]]; then
    info "Tool ${RED}${prog} could not be found${NC}, make sure it is installed!" \
      "**Highly** recommended to use the asdf-vm version if there is a plugin for the tool." \
      "**Highly** recommended that you speed up the changelog generation by pre-installing global 'git-changelog-command-line'." \
      "Otherwise npx will build deps etc for every script run, minutes instead of seconds.)"
    info "See ${GREEN}${link}${NC} or your package manager for install options."
    exit 1
  fi
}

calculate_next_version() {

  #Tag was explictly given
  if [[ -n "${INPUT_TAG}" ]]; then
    NEXT_TAG="${INPUT_TAG}"
    readonly NEXT_TAG
    return 0
  fi

  local latest_tag=""
  latest_tag=$(git tag | tr -d v | sort -V | tail -1)
  if [[ -z $latest_tag ]]; then
    latest_tag='0.0.0'
    #err "Could not find any existing tags in project. You might want to run with -t/--next-tag. Or just git tag -s x.y.z"
  fi

  info "Auto calculating next tag with semver scope: ${INPUT_SEMVER_SCOPE}."
  validate_semver "${latest_tag}"
  NEXT_TAG=$(semver bump "${INPUT_SEMVER_SCOPE}" "${latest_tag}")
  readonly NEXT_TAG

  info "Will use tag version ${NEXT_TAG}"
}

tag_with_next_version() {

  check_interactive "Do you want to skip git tag action? (y/n). Tag definied is ${NEXT_TAG}: "

  if [[ "${SKIP_ACTION}" == 'n' ]]; then

    git tag -s "${NEXT_TAG}" -m "v${NEXT_TAG}"
    info "Git tagged (signed): ${NEXT_TAG}"

  else
    info "Skipped Git tagging!"
  fi
}

generate_changelog() {
  check_interactive "Do you want to skip changelog generation? (y/n)"

  if [[ "${SKIP_ACTION}" == 'n' ]]; then

    local oldest_tag
    local scriptdir
    scriptdir=$(dirname -- "$0")
    oldest_tag=$(git tag | tr -d v | sort -V | head -1)

    local gitlog_extras="{\"oldest_tag\": \"${oldest_tag}\",\"host\": \"${INPUT_GIT_HOST_NAME}\"}"
    local gitlog_template="${scriptdir}/changelog_release.mustache"

    info "Generate changelog ........"
    npx git-changelog-command-line -ex "${gitlog_extras}" -t "${gitlog_template}" -of CHANGELOG.md
    info "Generated changelog as ./CHANGELOG.md"
  else
    info "Changelog generation skipped!"
  fi
}

update_npm_version() {
  npm --no-git-tag-version --allow-same-version version "${NEXT_TAG}"
  info "Updated package.json version to ${NEXT_TAG}"
}

update_pom_version() {
  mvn -q versions:set -DnewVersion="${NEXT_TAG}"
  info "Updated pom.xml version to ${NEXT_TAG}"
}

update_gradle_version() {
  #./gradlew properties -q | grep "version:" | awk '{print $2}'
  sed -i -E 's/version=.+/version='"${NEXT_TAG}"'/g' gradle.properties
  info "Updated gradle.properties version to ${NEXT_TAG}"
}

update_projectfile_version() {
  check_interactive "Do you want to skip updating project version? (y/n). Version definied is ${NEXT_TAG}: "

  if [[ "${SKIP_ACTION}" == 'n' ]]; then

    local project_type='?'
    local project_file_path="$1"
    local mvnfile="${project_file_path}pom.xml"
    local npmfile="${project_file_path}package.json"
    local gradlefile="${project_file_path}gradle.properties"

    if [[ -n ${INPUT_PROJECT_TYPE} ]]; then
      project_type="${INPUT_PROJECT_TYPE}"
      readonly project_type
      #elif [[ -e "${mvnfile}" && -e "${npmfile}" && -e "${gradlefile}" ]]; then TODO: check if more than one project file of any kind
      #  project_type="?"
      #  readonly project_type
    elif [[ -e "${npmfile}" ]]; then
      project_type="npm"
      readonly project_type
    elif [[ -e "${mvnfile}" ]]; then
      project_type="mvn"
    elif [[ -e "${gradlefile}" ]]; then
      project_type="gradle"
    fi

    if [[ "${project_type}" == "mvn" && -e "${mvnfile}" ]]; then
      PROJECT_FILE="${mvnfile}"
      update_pom_version "${mvnfile}"
    elif [[ "${project_type}" == "npm" && "${npmfile}" ]]; then
      PROJECT_FILE="${npmfile}"
      update_npm_version "${npmfile}"
    elif [[ "${project_type}" == "gradle" && "${gradlefile}" ]]; then
      PROJECT_FILE="${gradlefile}"
      update_gradle_version "${gradlefile}"
    else
      err "Could not find project file for project type ${project_type}."
    fi

  else
    info "Updating project version skipped!"
  fi
}

commit_changelog_and_projectfile() {
  check_interactive "Do you want to skip release commit of changelog and projectfile? (y/n): "

  if [[ "${SKIP_ACTION}" == 'n' ]]; then

    local commit_msg="chore: release v${NEXT_TAG}"
    git add CHANGELOG.md "${PROJECT_FILE}" && git commit --signoff --gpg-sign -m "${commit_msg}"
    info "git add && git commit --signoff --gpg-sign: CHANGELOG.md, ${PROJECT_FILE}. Commit message: ${commit_msg}"

  else

    info "Skipped git commit of changelog and projectfile!"

  fi
}

move_tag_to_release_commit() {
  check_interactive "Do you want to skip moving tag ${NEXT_TAG} to the latest commit?"

  if [[ "${SKIP_ACTION}" == 'n' ]]; then

    local latest_commit
    latest_commit=$(git rev-parse HEAD)

    git tag -f "${NEXT_TAG}" "${latest_commit}"
    info "Moved tag ${NEXT_TAG} to latest commit ${latest_commit}"
  else
    info "Skipped git commit of changelog and projectfile step!"
  fi
}

push_release_commit() {

  check_interactive "Do you want to skip Git push of your latest commit (and tag)? (y/n). Would push to origin, branch: ${INPUT_GIT_BRANCH_NAME}."

  if [[ "${INPUT_GIT_BRANCH_NAME}" == "none" ]]; then
    info "${YELLOW}No Git branch was given (option -b | --git-branch-name). Skipping final Git push. ${NC}"
  elif [[ "${SKIP_ACTION}" == 'n' ]]; then
    if [[ -z "${INPUT_GIT_BRANCH_NAME}" ]]; then
      info "INPUT_GIT_BRANCH_NAME was empty, skipping git push. Set branch with -b/--git-branch-name"
      return 0
    fi

    git push --atomic origin "${INPUT_GIT_BRANCH_NAME}" "${NEXT_TAG}"
    info "git: pushed tag and release commit to branch ${INPUT_GIT_BRANCH_NAME}"
  else
    info "Skipped git push step!"
  fi
}

run_flow() {

  validate_input
  calculate_next_version
  tag_with_next_version
  generate_changelog
  update_projectfile_version './'
  commit_changelog_and_projectfile
  move_tag_to_release_commit
  push_release_commit

}

parse_params() {

  local args=("$@")
  local arrlength=${#args[@]}
  #    echo $arrlength
  #[[ arrlength -eq 0 ]] && usage

  for ((var = 0; var < arrlength; var++)); do
    #        echo "${args[$var]}"
    case "${args[$var]}" in
    -h | --help)
      usage
      ;;
    -d | --debug)
      set -x
      ;;
    -t | --next-tag)
      INPUT_TAG="${args[$var + 1]}"
      readonly INPUT_TAG
      var=$var+1
      ;;
    -s | --semver-scope)
      INPUT_SEMVER_SCOPE="${args[$var + 1]}"
      readonly INPUT_SEMVER_SCOPE
      var=$var+1
      ;;
    -p | --project-type)
      INPUT_PROJECT_TYPE="${args[$var + 1]}"
      readonly INPUT_PROJECT_TYPE
      var=$var+1
      ;;
    -b | --git-branch-name)
      INPUT_GIT_BRANCH_NAME="${args[$var + 1]}"
      readonly INPUT_GIT_BRANCH_NAME
      var=$var+1
      ;;
    --git-host-name)
      INPUT_GIT_HOST_NAME="${args[$var + 1]}"
      readonly INPUT_GIT_HOST_NAME
      var=$var+1
      ;;
    -i | --interactive)
      INPUT_IS_INTERACTIVE="y"
      readonly INPUT_IS_INTERACTIVE
      ;;
    -?*)
      printf "\n%s\n\n" "${RED}**Unknown option**:${NC} ${args[var]}" && usage && exit 1
      ;;
    *)
      break
      ;;
    esac
  done

  return 0
}

main() {

  is_command_installed "git" "https://git-scm.com/"
  is_command_installed "semver" "https://github.com/mathew-fleisch/asdf-semver"
  is_command_installed "git-changelog-command-line" "https://www.npmjs.com/package/git-changelog-command-line"
  is_command_installed "npm" "https://github.com/asdf-vm/asdf-nodejs"
  is_command_installed "mvn" "https://github.com/Proemion/asdf-maven"

  printf "%s\n" "Running ${GREEN} changelog_release${NC}... -h or --help for help."
  parse_params "$@"
  run_flow
}

# Only runs main if not sourced.
# For easier testing with bats
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # abort on unbound variable
  set -o nounset
  if ! main "$@"; then
    exit 1
  fi
fi
