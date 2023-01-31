#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Josef Andersson
#
# SPDX-License-Identifier: MIT

# A no-thrills bash script to generate a md5 and sha256 for every directory in a structure.
# in the future , make it more extensible with a few options and better fail-saftey
# It will overwrite any existing checksums

# abort on nonzero exitstatus
set -o errexit
# don't hide errors within pipes
set -o pipefail
# Allow error traps on function calls, subshell environment, and command substitutions
set -o errtrace

err() {
  printf "\n"
  printf "%s\n" "$* ----- [$(date +'%Y-%m-%dT%H:%M:%S%z')]" >&2
  exit 1
}

info() {
  printf "\n"
  printf "%s\n" "$@"
}

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
      local results
      results=$(find . -maxdepth 1 -type f -not -name '*.md5' -not -name '*.sha256' -not -name 'dirsumgen.bash' -not -name 'dirsumgen' -exec "${sumprog}" {} \;)

      if [[ -n "${results}" ]]; then
        echo "${results}" >"${outputfile}"
        chmod a=rw "${outputfile}"
      else
        echo "Skipped creating a sum for directory ${dir} as it contained no files!"
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
      [[ ! -d "${WORKDIR}" ]] && err "Directory ${WORKDIR} is not valid. Check -w option or \$PWD"
      ;;
    esac
  done

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -d | --debug) set -x ;;
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
