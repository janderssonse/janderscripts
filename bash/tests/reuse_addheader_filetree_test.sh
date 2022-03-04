# SPDX-FileCopyrightText: 2022 Josef Andersson
#
# SPDX-License-Identifier: MIT

setup() {
  TEST_BREW_PREFIX="$(brew --prefix)"
  load "${TEST_BREW_PREFIX}/lib/bats-support/load.bash"
  load "${TEST_BREW_PREFIX}/lib/bats-assert/load.bash"  
  load "${TEST_BREW_PREFIX}/lib/bats-file/load.bash"  
  # get the containing directory of this file
  # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
  # as those will point to the bats executable's location or the preprocessed file respectively
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  # make executables in src/ visible to PATH
  PATH="$DIR/../src:$PATH"

}


function witout_any_options_fails_with_usage_hint { #@test
  run reuse_addheader_filetree.sh

  assert_output --partial "Settings: -c  -l  -y  -e * -p . -s"
  assert_output --partial "-c COPYRIGHT -l LICENSE -y YEAR -e EXTENSIONS [-p ROOTPATH] [-s SKIPUNREGOGNIZED ]"
  assert_failure
}


function without_reuse_fails_with_usage_hint { #@test
  run reuse_addheader_filetree.sh -i "REUSE_NOT_FOUND" 
  assert_output --partial "REUSE_NOT_FOUND could not be found, make sure it is installed!";
  assert_output --partial "See https://github.com/fsfe/reuse-tool for install options.";
  assert_failure
}


function integrationtest_adds_file_headers_verify_options_was_written_to_header { #@test
  #create test files in tmp
  local now=$(date +"%s")
  local tmproot="${BATS_TMPDIR}/reusebats${now}"
  mkdir -p "${tmproot}/a/b"
  touch "${tmproot}/javafile.java"
  touch "${tmproot}/a/jsfile.js" 
  touch "${tmproot}/a/b/jsxfile.jsx" 

  local copyright="copyright"
  local license="license"
  local year="2022"

  run reuse_addheader_filetree.sh -c "$copyright" -l "$license" -y "${year}" -p "${tmproot}"

#assert reuse output
assert_output --partial "Successfully changed header of ${tmproot}/a/b/jsxfile.jsx"
assert_output --partial "Successfully changed header of ${tmproot}/javafile.java"
assert_output --partial "Successfully changed header of ${tmproot}/a/jsfile.js"


        #assert reuse headers exists in output
        local file_content=$(cat "${tmproot}/a/b/jsxfile.jsx")
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

