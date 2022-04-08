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

#TO-DO
#function generate
#function verify
#function input_handler
#check defaults

function fails_without_command_installed_or_success_if_command_found { #@test
  
  source dirsumgen.bash

  run is_command_installed "a non existing program"
  assert_failure

  run is_command_installed "cat"
  assert_success
}

function outputs_usage_without_args { #@test

  run dirsumgen.bash 

  assert_output --partial "dirsumgen is a bash script for adding md5 and sha256 sums for directories.";
  assert_success

}

function flag_p_fails_if_no_val_or_non_accesible_dir_and_is_always_intrepreted_first_ { #@test

  local now
  now=$(date +"%s")

  local tmproot="${BATS_TMPDIR}/dirsumgen${now}"
  
  mkdir "${tmproot}"

  # fails if set to empty arg
  run dirsumgen.bash -p 
   
  assert_output --partial "Please set -p to a valid option"
  assert_failure
 
  #fails if not accesible dir
  run dirsumgen.bash -p "i_dont_exist"
 
  assert_output --partial "Directory i_dont_exist is not valid"
  assert_failure
 
  # success if accesible dir
  run dirsumgen.bash -p "${BATS_TMPDIR}"
 
  assert_output --partial "Setting workdir to ${BATS_TMPDIR}"
  assert_success
  
  # runs first wherever order it was set to as arg
  run dirsumgen.bash -v -g -p "${tmproot}"
 
  echo -e "-v -g -p ${tmproot} \nSetting workdir to ${tmproot} \nVerifying sums starting from rootdir . \nGenerating sums starting from rootdir | "assert_output --partial 
  assert_success
  
  run dirsumgen.bash -g -p "${tmproot}"
 
  echo -e "-g -p ${tmproot} \nSetting workdir to ${tmproot} \nGenerating sums starting from rootdir | "assert_output --partial 
  assert_success
  
  run dirsumgen.bash -p "${tmproot}" -g
 
  echo -e "-g -p ${tmproot} \nSetting workdir to ${tmproot} \nGenerating sums starting from rootdir | "assert_output --partial 
  assert_success

}


function integrationtest_generate_sums_and_then_validate_them() { #@test

  #create test files in tmp
  local now
  now=$(date +"%s")

  local tmproot="${BATS_TMPDIR}/dirsumgen${now}"
  mkdir -p "${tmproot}/a/b/c/d"
  mkdir -p "${tmproot}/e/b/c/d"

  local -r testFileArray=("${tmproot}/f1" "${tmproot}/a/f2" \
    "${tmproot}/a/f3" "${tmproot}/a/b/c/d/f4" "${tmproot}/e/b/c/f5")

  #create testfiles in temp dir
  for path in "${testFileArray[@]}"; do
    echo $((1 + "$RANDOM" % 10)) > "${path}"
  done

  run dirsumgen.bash -g -p "${tmproot}"

  # expected generated files found
  for path in "${testFileArray[@]}"; do
    assert_exist "${path}"
    assert_file_not_empty "${path}" 
  done

  #expected nr of created sum files 
  local count_sumfiles
  count_sumfiles=$(find "${tmproot}" -type f -name "*.md5" -or -name "*.sha256" | wc -l)

  assert_equal 8 "${count_sumfiles}"

  #expected verified files
  run dirsumgen.bash -v -p "${tmproot}"
  
  local count_sumOKs
  count_sumOKs=$(echo "$output" | wc -l)

  assert_equal 13 "${count_sumOKs}" #3 rows are added besides the OK ones, to fix
  
  assert_success
}

