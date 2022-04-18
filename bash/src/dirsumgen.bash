#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Josef Andersson
# SPDX-FileCopyrightText: 2020 Maciej Radzikowski
#
# SPDX-License-Identifier: MIT

# A no-thrills bash script to generate a md5 and sha256 for every directory in a structure.
# in the future , make it more extensible with a few options and better fail-saftey
# It will overwrite any existing checksums

#Bash Template based on https://gist.github.com/m-radzikowski/53e0b39e9a59a1518990e76c2bff8038

# abort on nonzero exitstatus
set -o errexit
# don't hide errors within pipes
set -o pipefail
# Allow error traps on function calls, subshell environment, and command substitutions
set -o errtrace

#trap cleanup SIGINT SIGTERM ERR EXIT

#SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {

  printf "%s\n" \
    "Usage: dirsumgen [-h][-g][-v][-p path]" \
    "" \
    "dirsumgen is a bash script for adding md5 and sha256 sums for directories." \
    "" \
    "Available options:" \
    "" \
    " -h --help         Print this help and exit" \
    " -d --debug        Output extra script run information" \
    " -v --verify       Verify md5 and sha256 files in the WORKDIR dir tree" \
    " -g --generate     Generate md5 and sh256 sums for a directory tree. One sum file for each dir." \
    " -w --workdir      Set the root of dir tree to create sums for and travers. Default \$PWD."
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

# script logic here
is_command_installed() {

  local -r sumprog=$1

  if ! [[ -x "$(command -v "${sumprog}")" ]]; then
    echo "${sumprog} could not be run, make sure it is installed and executable"
    return 1
  fi
}

generate_sum() {

  echo "${WORKDIR}"
  local -r sumprog=$1
  local -r outputfile=$2

  find "${WORKDIR}" -type d | sort | while read -r dir; do

    (
      cd "${dir}" || return 2

      echo "Processing ${dir} with ${sumprog}"
      local results=$(find . -maxdepth 1 -type f -not -name '*.md5' -not -name '*.sha256' -not -name 'dirsumgen.bash' -not -name 'dirsumgen' -exec "${sumprog}" {} \;)

      if [[ -n "${results}" ]]; then
        echo "${results}" >"${outputfile}"
        chmod a=rw "${outputfile}"
      else
        echo "Skipped creating a sum for directory "${dir}" as it contained no files!"
      fi
    )

  done
  return 0

}

verify_sum() {

  local -r sumprog=$1
  local -r outputfile=$2

  find "${WORKDIR}" -name "${outputfile}" | sort | while read -r afile; do

    (
      cd "${afile%/*}" || return 3
      eval "${sumprog}" -c "${outputfile}"
    )
  done

}

parse_params() {

  declare WORKDIR="${PWD}"
  local args=("$@")

  [[ ${#args[@]} -eq 0 ]] && usage

  #handle -w first
  for var in "${!args[@]}"; do
    case "${args[$var]}" in
    -w | --workdir)
      workdir="${args[$var + 1]:-${PWD}}"
      echo "Setting workdir to ${workdir}"
      WORKDIR="${workdir}"
      [[ ! -d "${WORKDIR}" ]] && die "Directory "${WORKDIR}" is not valid. Check -w option or \$PWD"
      ;;
    esac
  done

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -d | --debug) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -w | --workdir) shift ;;
    -v | --verify)
      echo "Verifying sums starting from rootdir ${WORKDIR}"
      verify_sum "md5sum" "md5Sum.md5"
      verify_sum "sha256sum" "sha256Sum.sha256"
      ;;
    -g | --generate)
      echo "Generating sums starting from rootdir ${WORKDIR}"
      generate_sum "md5sum" "md5Sum.md5"
      generate_sum "sha256sum" "sha256Sum.sha256"
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  return 0
}

main() {

  is_command_installed "md5sum"
  is_command_installed "sha256sum"

  parse_params "$@"
  setup_colors
}

# Only runs main if not sourced.
# For easier testing with bats
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # abort on unbound variable
  set -o nounset
  main "$@"
  if [ $? -gt 0 ]; then
    exit 1
  fi
fi
