#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Josef Andersson
#
# SPDX-License-Identifier: MIT

# Run a code quality check

declare -A EXITCODES
declare -A SUCCESS_MESSAGES

# Colour
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#Terminal chars
CHECKMARK="\xE2\x9C\x94"
MISSING="\xE2\x9D\x8C"

is_command_available() {
  local COMMAND="${1}"
  local INFO="${2}"

  if ! [ -x "$(command -v "${COMMAND}")" ]; then
    printf '%b Error:%b %s is not availble in path/installed.\n' "${RED}" "${NC}" "${COMMAND}" >&2
    printf 'See %s for more info about the command.\n' "${INFO}" >&2
    exit 1
  fi
}

print_header() {
  local HEADER="$1"
  printf '%b\n************ %s ***********%b\n\n' "${YELLOW}" "$HEADER" "${NC}"
}

store_exit_code() {
  declare -i STATUS="$1"
  local KEY="$2"
  local INVALID_MESSAGE="$3"
  local VALID_MESSAGE="$4"

  if [[ "${STATUS}" -ne 0 ]]; then
    EXITCODES["${KEY}"]="${INVALID_MESSAGE}"
  else
    SUCCESS_MESSAGES["${KEY}"]="${VALID_MESSAGE}"
  fi
}

lint() {
  export MEGALINTER_DEF_WORKSPACE='/repo'
  print_header 'LINTER HEALTH (MEGALINTER)'
  podman run --rm --volume "$(pwd)":/repo -e MEGALINTER_CONFIG='configs/mega-linter.yml' -e DEFAULT_WORKSPACE=${MEGALINTER_DEF_WORKSPACE} -e LOG_LEVEL=INFO oxsecurity/megalinter-java:v6.19.0
  store_exit_code "$?" "Lint" "${MISSING} ${RED}Lint check failed, see logs (std out and/or ./megalinter-reports) and fix problems.${NC}\n" "${GREEN}${CHECKMARK}${CHECKMARK} Lint check passed${NC}\n"
  sed -i 's|uri": "/repo/|uri": "|g' ./megalinter-reports/sarif/*.sarif
  printf '\n\n'
}

license() {
  print_header 'LICENSE HEALTH (REUSE)'
  podman run --rm --volume "$(pwd)":/data fsfe/reuse lint
  store_exit_code "$?" "License" "${MISSING} ${RED}License check failed, see logs and fix problems.${NC}\n" "${GREEN}${CHECKMARK}${CHECKMARK} License check passed${NC}\n"
  printf '\n\n'
}

commit() {
  print_header 'COMMIT HEALTH (CONFORM)'
  podman run --rm -i --volume "$(pwd)":/repo -w /repo ghcr.io/siderolabs/conform:v0.1.0-alpha.27 enforce
  store_exit_code "$?" "Commit" "${MISSING} ${RED}Commit check failed, see logs (std out) and fix problems.${NC}\n" "${GREEN}${CHECKMARK}${CHECKMARK} Commit check passed${NC}\n"
  printf '\n\n'
}

check_exit_codes() {
  printf '%b********* CODE QUALITY RUN SUMMARY ******%b\n\n' "${YELLOW}" "${NC}"

  for key in "${!EXITCODES[@]}"; do
    printf '%b' "${EXITCODES[$key]}"
  done
  printf "\n"

  for key in "${!SUCCESS_MESSAGES[@]}"; do
    printf '%b' "${SUCCESS_MESSAGES[$key]}"
  done
  printf "\n"
}

is_command_available 'podman' 'https://podman.io/'

lint
license
commit

check_exit_codes
