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
INPUT_IS_INTERACTIVE=""
INPUT_PROJECT_TYPE=""
INPUT_SEMVER_SCOPE="minor"
INPUT_REPOURL=''
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

#Terminal chars
readonly CHECKMARK=$'\xE2\x9C\x94'
readonly MISSING=$'\xE2\x9D\x8C'

check_interactive() {

  if [[ "${INPUT_IS_INTERACTIVE}" == 'y' ]]; then
    local user_info=$1

    while true; do
      read -r -n 1 -p "${user_info}" SKIP_ACTION
      case "${SKIP_ACTION}" in
      [y]*)
        break
        ;;
      [n]*)
        break
        ;;
      *) echo "Please answer y or n." ;;
      esac
    done

    #TODO verify char is y or n
  fi
}

err() {
  printf "\n"
  printf "%s\n" "${MISSING} ${RED} $* ${NC} ----- [$(date +'%Y-%m-%dT%H:%M:%S%z')]" >&2
  exit 1
}

info() {
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

    info "${GREEN} To help avoid misfortunes with pushes, run the script from same branch you will push to. Use with${NC} -b /--git-branch-name option."
    err "You are running the script from branch: ${current_branch} and would like to push to: ${INPUT_GIT_BRANCH_NAME}"
  fi

  #Validate given tag
  if [[ -n "${INPUT_TAG}" ]]; then
    validate_semver "${INPUT_TAG}"
  fi

}

usage() {

  info \
    "${YELLOW}Usage:${NC} changelog_release [-h][-d][-i][-s semver-scope][-p project-type][-b git-branch-name]" \
    "" \
    "changelog_release is a glue for the flow of" \
    " bumping a git tag " \
    " generating a changelog " \
    " update project file version" \
    " generating a release commit (CHANGELOG and project file)" \
    " " \
    "Run it from the root of your git project structure, see README for more info." \
    "" \
    "${YELLOW}Available options:${NC}" \
    "" \
    " -h --help            Print this help and exit" \
    " -d --debug           Output extra script run information" \
    " -s --semver-scope    Semver scope for next tag when autoidentify <major|minor|patch>. Default: minor" \
    " -t --next-tag        Specify next tag instead of autoidentify" \
    " -p --project-type    Which project type <npm|mvn|gradle|none>. Default: try autoidentify by existing file." \
    " -b --git-branch-name Git branch name to push to (any_name). 'none' skips push. Default: none. " \
    " -r --repository-url  Full repository url. Default: autoidentify from git remote url." \
    " -i --interactive     The script asks for tag naming input instead of calculating next, etc." \
    " "
  exit 0
}

is_command_installed() {

  local prog=$1
  local link=$2

  if ! [[ -x "$(command -v "${prog}")" ]]; then
    info "Tool ${YELLOW}${prog}${NC} could not be found, make sure it is installed!" \
      "**Highly** recommended to use the asdf-vm version if there is a plugin for the tool."
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

  info "... Calculating next tag from semver scope: ${YELLOW}${INPUT_SEMVER_SCOPE}${NC}"
  validate_semver "${latest_tag}"
  NEXT_TAG=$(semver bump "${INPUT_SEMVER_SCOPE}" "${latest_tag}")
  readonly NEXT_TAG

  info "$GREEN $CHECKMARK ${NC} Calculated tag version: ${YELLOW}${NEXT_TAG}${NC}"
}

tag_with_next_version() {

  check_interactive "Do you want to skip git tag action? (y/n). Tag definied is ${NEXT_TAG}: "

  if [[ "${SKIP_ACTION}" == 'n' ]]; then

    git tag -s "${NEXT_TAG}" -m "v${NEXT_TAG}"
    info "${GREEN} ${CHECKMARK} ${NC} Tagged (signed): ${YELLOW}${NEXT_TAG}${NC}"

  else
    info "${YELLOW} Skipped Git tagging!${NC}"
  fi
}

generate_changelog() {
  check_interactive "Do you want to skip changelog generation? (y/n)"

  if [[ "${SKIP_ACTION}" == 'n' ]]; then

    # git-chlglog needs a repourl to generate links
    local repourl

    if [[ -n "${INPUT_REPOURL}" ]]; then
      repourl="${INPUT_REPOURL}"
    else
      repourl=$(git config --get remote.origin.url)
      repourl="${repourl::-4}" #remove.git
      repourl=$(echo "${repourl}" | sed "s/git@gitlab.com:/https:\/\/gitlab.com\//")
      repourl=$(echo "${repourl}" | sed "s/git@github.com:/https:\/\/github.com\//")

    fi

    local scriptdir
    scriptdir=$(dirname -- "$0")

    local git_chglog_conf="${scriptdir}/git-chglog-gl.yml"

    # Different styles for gitlab/github
    if [[ "${repourl}" == *'github'* ]]; then
      git_chglog_conf="${scriptdir}/git-chglog-gh.yml"
    fi

    #info "Generate changelog ........ ${repourl}"
    git-chglog --repository-url "${repourl}" -c "${git_chglog_conf}" -o CHANGELOG.md
    info "${GREEN} ${CHECKMARK} ${NC} Generated changelog as ${YELLOW}./CHANGELOG.md${NC}"
  else
    info "${YELLOW} Skipped Changelog generation!${NC}"
  fi
}

update_npm_version() {
  npm --no-git-tag-version --allow-same-version version "${NEXT_TAG}"
  info "${GREEN} ${CHECKMARK} ${NC} Updated package.json version to ${YELLOW}${NEXT_TAG}${NC}"
}

update_pom_version() {
  mvn -q versions:set -DnewVersion="${NEXT_TAG}"
  info "${GREEN} ${CHECKMARK} ${NC} Updated pom.xml version to ${YELLOW}${NEXT_TAG}${NC}"
}

update_gradle_version() {
  #./gradlew properties -q | grep "version:" | awk '{print $2}'
  sed -i -E 's/version=.+/version='"${NEXT_TAG}"'/g' gradle.properties
  info "${GREEN} ${CHECKMARK} ${NC} Updated gradle.properties version to ${YELLOW}${NEXT_TAG}${NC}"
}

update_projectfile_version() {
  check_interactive "Do you want to skip updating project version? (y/n). Version definied is ${NEXT_TAG}: "

  if [[ "${SKIP_ACTION}" == 'n' ]]; then

    local project_type='?'
    local project_file_path="$1"
    local mvnfile="${project_file_path}pom.xml"
    local npmfile="${project_file_path}package.json"
    local gradlefile="${project_file_path}gradle.properties"

    #TODO: check if more than one project file of any kind
    if [[ -n ${INPUT_PROJECT_TYPE} ]]; then
      project_type="${INPUT_PROJECT_TYPE}"
      readonly project_type
    elif [[ -e "${npmfile}" ]]; then
      project_type="npm"
      readonly project_type
    elif [[ -e "${mvnfile}" ]]; then
      project_type="mvn"
    elif [[ -e "${gradlefile}" ]]; then
      project_type="gradle"
    else
      project_type="none"
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
    elif [[ "${project_type}" == "none" ]]; then
      PROJECT_FILE=''
    fi

  else
    info "${YELLOW} Skipped project file version update!${NC}"
  fi
}

commit_changelog_and_projectfile() {
  check_interactive "Do you want to skip release commit of changelog and projectfile? (y/n): "

  if [[ "${SKIP_ACTION}" == 'n' ]]; then

    local commit_msg="chore: release v${NEXT_TAG}"
    if [[ -n "${PROJECT_FILE}" ]]; then
      git add CHANGELOG.md "${PROJECT_FILE}" 1>/dev/null && git commit -q --signoff --gpg-sign -m "${commit_msg}"
    else
      git add CHANGELOG.md 1>/dev/null && git commit -q --signoff --gpg-sign -m "${commit_msg}"
    fi
    info "${GREEN} ${CHECKMARK} ${NC} Added and committed ${YELLOW}CHANGELOG.md ${PROJECT_FILE}${NC}. Commit message: ${YELLOW}${commit_msg}${NC}"
  else
    info "${YELLOW} Skipped git commit of changelog and project file!${NC}"
  fi
}

move_tag_to_release_commit() {
  check_interactive "Do you want to skip moving tag ${NEXT_TAG} to the latest commit?"

  if [[ "${SKIP_ACTION}" == 'n' ]]; then

    local latest_commit
    latest_commit=$(git rev-parse HEAD)

    git tag -f "${NEXT_TAG}" "${latest_commit}" -m "v${NEXT_TAG}" 1>/dev/null
    info "${GREEN} ${CHECKMARK} ${NC} Moved tag ${YELLOW}${NEXT_TAG}${NC} to latest commit ${YELLOW}${latest_commit}${NC}"
  else
    info "${YELLOW} Skipped git commit of changelog and projectfile step!${NC}"
  fi
}

push_release_commit() {

  check_interactive "Do you want to skip Git push of your latest commit (and tag)? (y/n). Would push to origin, branch: ${INPUT_GIT_BRANCH_NAME}."

  if [[ "${INPUT_GIT_BRANCH_NAME}" == "none" ]]; then
    info "${YELLOW}No Git branch was given (option -b | --git-branch-name). Skipping final Git push. ${NC}"
  elif [[ "${SKIP_ACTION}" == 'n' ]]; then
    if [[ -z "${INPUT_GIT_BRANCH_NAME}" ]]; then
      info "${YELLOW}INPUT_GIT_BRANCH_NAME was empty, skipping git push. Set branch with -b/--git-branch-name${NC}"
      return 0
    fi

    git push --atomic origin "${INPUT_GIT_BRANCH_NAME}" "${NEXT_TAG}"
    info "${GREEN} ${CHECKMARK} ${NC} Git pushed tag and release commit to branch ${INPUT_GIT_BRANCH_NAME}"
  else
    info "${YELLOW} Skipped git push!${NC}"
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
    -r | --repository-url)
      INPUT_REPOURL="${args[$var + 1]}"
      readonly INPUT_REPOURL
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
  is_command_installed "git-chglog" "https://github.com/git-chglog/git-chglog"
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
