#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Josef Andersson
#
# SPDX-License-Identifier: MIT

function _init_bats() {

  TEST_LIB_PREFIX="${PWD}/bash/lib/"
  load "${TEST_LIB_PREFIX}bats-support/load.bash"
  load "${TEST_LIB_PREFIX}bats-assert/load.bash"
  load "${TEST_LIB_PREFIX}bats-file/load.bash"
  # get the containing directory of this file
  # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
  # as those will point to the bats executable's location or the preprocessed file respectively
  DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  # make executables in src/ visible to PATH
  PATH="$DIR/../../src:$PATH"

}

function _is_command_installed() {

  local prog=$1
  local link=$2

  if ! [[ -x "$(command -v "${prog}")" ]]; then
    info "Tool ${RED}${prog} could not be found${NC}, make sure it is installed!" \
      "**Highly** recommended to use the asdf-vm version if there is a plugin for the tool." \
      info "See ${GREEN}${link}${NC} or your package manager for install options."
    exit 1
  fi
}
