# SPDX-FileCopyrightText: 2022 Josef Andersson
#
# SPDX-License-Identifier: MIT

setup() {
  TEST_LIB_PREFIX="${PWD}/bash/lib/"
  load "${TEST_LIB_PREFIX}bats-support/load.bash"
  load "${TEST_LIB_PREFIX}bats-assert/load.bash"
  load "${TEST_LIB_PREFIX}bats-file/load.bash"
  # get the containing directory of this file
  # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
  # as those will point to the bats executable's location or the preprocessed file respectively
  DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  # make executables in src/ visible to PATH
  PATH="$DIR/../src:$PATH"

  TEST_TEMP_DIR="$(temp_make --prefix 'dirsumgen-')"

}

#TO-DO
#function input_handler
#check defaults

function fails_without_command_installed_or_success_if_command_found { #@test

  source dirsumgen.bash

  run is_command_installed "a non existing program"
  assert_failure

  run is_command_installed "cat"
  assert_success
}

function generate_and_verify { #@test

  source dirsumgen.bash

  mkdir -p "${TEST_TEMP_DIR}/gensum/gen/empty"

  local -r testFileArray=("${TEST_TEMP_DIR}/gensum/g1" "${TEST_TEMP_DIR}/gensum/gen/g2")

  #create testfiles in temp dir
  for path in "${testFileArray[@]}"; do
    echo $((1 + "$RANDOM" % 10)) >"${path}"
  done

  local -r WORKDIR="${TEST_TEMP_DIR}/gensum"

  run generate_sum "md5sum" "md5Sum.md5"

  assert_success

  echo -e "Processing ${WORKDIR} with md5sum\nProcessing ${WORKDIR}/gen with md5sum\nProcessing ${WORKDIR}/gen/empty with md5sum\nSkipped creating a sum for directory ${WORKDIR}/gen/empty as it contained no files!" | assert_output

  run verify_sum "md5sum" "md5Sum.md5"

  assert_success
  echo -e "./g2: OK\n./g1: OK" | assert_output

}

function outputs_usage_without_args { #@test

  run dirsumgen.bash

  assert_output --partial "dirsumgen is a bash script for adding md5 and sha256 sums for directories."
  assert_success

}

function flag_w_fails_if_non_accesible_dir_and_is_always_intrepreted_first { #@test

  # workdir is default set (pwd) if no arg
  run dirsumgen.bash -h -w

  assert_output --partial "Setting workdir to ${PWD}"
  assert_success

  #fails if not accesible dir
  run dirsumgen.bash -w "i_dont_exist"

  assert_output --partial "Directory i_dont_exist is not valid"
  assert_failure

  # success if accesible dir
  run dirsumgen.bash -w "${BATS_TMPDIR}"

  assert_output --partial "Setting workdir to ${BATS_TMPDIR}"
  assert_success

  # runs first wherever order it was set to as arg
  run dirsumgen.bash -v -g -w "${TEST_TEMP_DIR}"

  echo -e "-v -g -w ${TEST_TEMP_DIR} \nSetting workdir to ${TEST_TEMP_DIR} \nVerifying sums starting from rootdir . \nGenerating sums starting from rootdir" | assert_output --partial
  assert_success

  run dirsumgen.bash -g -w "${TEST_TEMP_DIR}"

  echo -e "-g -w ${TEST_TEMP_DIR} \nSetting workdir to ${TEST_TEMP_DIR} \nGenerating sums starting from rootdir | "assert_output --partial
  assert_success

  run dirsumgen.bash -w "${TEST_TEMP_DIR}" -g

  echo -e "-g -w ${TEST_TEMP_DIR} \nSetting workdir to ${TEST_TEMP_DIR} \nGenerating sums starting from rootdir" | assert_output --partial
  assert_success

}

function integrationtest_generate_sums_and_then_validate_them() { #@test

  mkdir -p "${TEST_TEMP_DIR}/a/b/c/d"
  mkdir -p "${TEST_TEMP_DIR}/e/b/c/d"

  local -r testFileArray=("${TEST_TEMP_DIR}/f1" "${TEST_TEMP_DIR}/a/f2"
    "${TEST_TEMP_DIR}/a/f3" "${TEST_TEMP_DIR}/a/b/c/d/f4" "${TEST_TEMP_DIR}/e/b/c/f5")

  #create testfiles in temp dir
  for path in "${testFileArray[@]}"; do
    echo $((1 + "$RANDOM" % 10)) >"${path}"
  done

  run dirsumgen.bash -v -g -w "${TEST_TEMP_DIR}" -v

  # expected generated files found
  for path in "${testFileArray[@]}"; do
    assert_exist "${path}"
    assert_file_not_empty "${path}"
  done

  #expected nr of created sum files
  local count_sumfiles
  count_sumfiles=$(find "${TEST_TEMP_DIR}" -type f -name "*.md5" -or -name "*.sha256" | wc -l)

  assert_equal 8 "${count_sumfiles}"

  #expected verified files
  run dirsumgen.bash -v -w "${TEST_TEMP_DIR}"

  local count_sumOKs
  count_sumOKs=$(echo "$output" | wc -l)

  assert_equal 12 "${count_sumOKs}" #2 rows are added besides the OK ones, to fix

  assert_success
}
