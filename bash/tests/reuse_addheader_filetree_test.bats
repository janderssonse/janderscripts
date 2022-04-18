# SPDX-FileCopyrightText: 2022 Josef Andersson
#
# SPDX-License-Identifier: MIT

setup() {
  TEST_BREW_PREFIX="${PWD}/bash/lib"
  load "${TEST_BREW_PREFIX}/bats-support/load.bash"
  load "${TEST_BREW_PREFIX}/bats-assert/load.bash"
  load "${TEST_BREW_PREFIX}/bats-file/load.bash"
  # get the containing directory of this file
  # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
  # as those will point to the bats executable's location or the preprocessed file respectively
  DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  # make executables in src/ visible to PATH
  PATH="$DIR/../src:$PATH"

  TEST_TEMP_DIR="$(temp_make --prefix 'reuse-addheader-')"
}

function without_any_options_fails_with_usage_hint { #@test
  run reuse_addheader_filetree.bash

  assert_output --partial "Usage: reuse_addheader_filetree [-h][-d][-c copyright][-l license][-year][-e extensions][-p rootpath][-s skipunrecognized" \
    assert_failure
}

function integrationtest_adds_file_headers_verify_options_was_written_to_header { #@test

  mkdir -p "${TEST_TEMP_DIR}/a/b"
  touch "${TEST_TEMP_DIR}/javafile.java"
  touch "${TEST_TEMP_DIR}/a/jsfile.js"
  touch "${TEST_TEMP_DIR}/a/b/jsxfile.jsx"

  local copyright="copyright"
  local license="license"
  local year="2022"

  run reuse_addheader_filetree.bash -c "$copyright" -l "$license" -y "${year}" -p "${TEST_TEMP_DIR}"

  #assert reuse output
  assert_output --partial "Successfully changed header of ${TEST_TEMP_DIR}/a/b/jsxfile.jsx"
  assert_output --partial "Successfully changed header of ${TEST_TEMP_DIR}/javafile.java"
  assert_output --partial "Successfully changed header of ${TEST_TEMP_DIR}/a/jsfile.js"

  #assert reuse headers exists in output
  local file_content=$(cat "${TEST_TEMP_DIR}/a/b/jsxfile.jsx")
  local header="PDX-FileCopyrightText: ${year} ${copyright}"
  local header2="PDX-License-Identifier: license"

  if [[ "${file_content}" != *"${header}"* ]]; then
    echo "Missing Reuse ${header} in ${file_content}" >&2
    return 1
  fi

  if [[ "${file_content}" != *"${header2}"* ]]; then
    echo "Missing Reuse ${header2} in ${file_content}" >&2
    return 1
  fi

  assert_success
}

#TO-DO write more tests for options etc
