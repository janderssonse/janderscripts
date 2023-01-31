# SPDX-FileCopyrightText: 2023 Josef Andersson
#
# SPDX-License-Identifier: MIT

# Bats integration test, operations are run in the distrubtions tmp folder
# https://github.com/bats-core/bats-core

function verify_that_basic_tools_is_accessible() {

  #Integration test won't mock dependencies, so first do a basic sanity check
  _is_command_installed "git" "https://git-scm.com/"
  _is_command_installed "semver" "https://github.com/mathew-fleisch/asdf-semver"
  _is_command_installed 'git-changelog-command-line' "https://www.npmjs.com/package/git-changelog-command-line"
  _is_command_installed "npm" "https://github.com/asdf-vm/asdf-nodejs"
  _is_command_installed "mvn" "https://github.com/Proemion/asdf-maven"

}

#Bats specific function
function setup_file() {

  load './testutils'
  _init_bats

  # vars from setup_file() has to be exported.
  export _is_command_installed

  verify_that_basic_tools_is_accessible

  TEST_TEMP_DIR="$(temp_make)"

  # Dive in and prepare a bare repo, acting on behalf of a remote git service, to serve our push and clone operations.
  (
    cd "${TEST_TEMP_DIR}/" || exit 1
    git init --bare integtest.git
  )

  export TEST_TEMP_DIR

}

# has to be done as bats cant find the assert_output etc, they are not exported from setup_file. Investigate with bats if bug or feature.
function setup() {

  load './testutils'
  _init_bats
}

function setup_git_test_branch() {

  local -r project_name="$1"
  local -r branch_name="$2"
  local -r tag_name="$3"

  printf "%s\n" "$(pwd)"
  #set up project for testing in the temp dir
  cp -R "bash/src/test/resources/${project_name}" "${TEST_TEMP_DIR}/"
  cp ./bash/src/changelog_release.bash "${TEST_TEMP_DIR}/${project_name}/"
  cp ./bash/src/changelog_release.mustache "${TEST_TEMP_DIR}/${project_name}/"

  cd "${TEST_TEMP_DIR}/${project_name}" || exit 1

  # local git prep
  git init -b "${branch_name}"
  git config user.email "test@tester.com"
  git config user.name "Test Testsson"
  git config gpg.format ssh
  ssh-keygen -b 1024 -t rsa -f "${TEST_TEMP_DIR}/${project_name}/sshkey" -q -N ''
  git config user.signingkey "${TEST_TEMP_DIR}/${project_name}/sshkey.pub"
  git add . && git commit -m 'chore: initial commit'

  touch dummy{1..6}

  git add dummy1 && git commit -m 'feat: a feat commit'
  git add dummy2 && git commit -m 'fix: a fix commit'
  git add dummy3 && git commit -m 'fix!: a breaking fix commit'
  git add dummy4 && git commit -m 'docs: a doc commit'
  git add dummy5 && git commit -m 'chore: a chore commit'
  git add dummy6 && git commit -m 'fix: another fix commit'

  git tag -s "${tag_name}" -m "v${tag_name}"

}

function git_tag_delete() {

  git push origin --delete $(git tag -l)
  git tag -d $(git tag -l)
}

function clone_and_verify_result() {

  # Correct tags are set
  # Changelog is generated
  # The Commit with the tag consists of the Changelog and correct commit message only
  # pom.xml/package.json-version is updated

  local project_type="$1"
  local project_name=$2
  local expected_changed_files=$3
  local branch_name=$4

  # checkout the pushed end result from our bare service repo
  cd "${TEST_TEMP_DIR}/" || exit 1
  git clone integtest.git "testresult_${project_name}"
  cd "testresult_${project_name}"
  git checkout "${branch_name}"

  echo $(pwd)
  local tag_version
  local commithash_tag_points_to
  local commit_message

  local project_version

  if [[ "${project_type}" == 'mvn' ]]; then
    project_version=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
  elif [[ "${project_type}" == 'npm' ]]; then
    project_version=$(npm pkg get version | sed 's/"//g')
  elif [[ "${project_type}" == 'gradle' ]]; then
    project_version=$(gradle properties -q | grep "version:" | awk '{print $2}')
  fi

  tag_version=$(git tag | tr -d v | sort -V | tail -1)
  commithash_tag_points_to=$(git rev-parse 1.1.0)
  changed_files=$(git diff-tree --no-commit-id --name-only -r "${commithash_tag_points_to}" | sort | tr -d '\n')
  commit_message=$(git show -s --format=%B "${commithash_tag_points_to}" | head -1)

  assert_equal '1.1.0' "${tag_version}"

  # sha-hashes in the changelog are non deterministic, we want to compare all but hashes
  sed -i -E 's/[0-9a-f]{5,15}//g' ./CHANGELOG.md
  sed -i -E 's/[0-9a-f]{5,15}//g' ./CHANGELOG-test.md
  sed -i -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}//g' ./CHANGELOG.md
  sed -i -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}//g' ./CHANGELOG-test.md
  run diff <(sort CHANGELOG.md) <(sort CHANGELOG-test.md)

  assert_success

  assert_equal '1.1.0' "${project_version}"
  assert_equal "${expected_changed_files}" "${changed_files}"

  assert_equal 'chore: release v1.1.0' "${commit_message}"
  git_tag_delete

}

function assert_scriptrun_output() {

  local -r project_name=$1
  local -r branch_name=$2
  local -r project_file_name=$3

  # all setup, now run it
  cd "${TEST_TEMP_DIR}/${project_name}" || exit 1
  git remote add origin ../integtest.git
  run ./changelog_release.bash --git-branch-name "${branch_name}"

  assert_output --partial "Auto calculating next tag with semver scope: minor."
  assert_output --partial "Will use tag version 1.1.0"
  assert_output --partial "Git tagged (signed): 1.1.0"
  assert_output --partial "Generate changelog"
  assert_output --partial "Generated changelog as ./CHANGELOG.md"
  assert_output --partial "Updated ${project_file_name} version to 1.1.0"
  assert_output --partial "Updated tag '1.1.0'"
  assert_output --partial "Moved tag 1.1.0 to latest commit"
  assert_output --partial "git: pushed tag and release commit to branch ${branch_name}"

  assert_success

}

function mvn_project_is_tagged_and_updated_correctly() { #@test

  local -r project_name='java-project'
  local -r branch_name='mvn_test'
  local -r tag_name='1.0.1'

  setup_git_test_branch "${project_name}" "${branch_name}" "${tag_name}"
  assert_scriptrun_output "${project_name}" "${branch_name}" 'pom.xml'
  clone_and_verify_result 'mvn' "${project_name}" 'CHANGELOG.mdpom.xml' "${branch_name}"

}

function npmproject_is_tagged_and_updated_correctly() { #@test

  local -r project_name='npm-project'
  local -r branch_name='npm_test'
  local -r tag_name='1.0.1'

  setup_git_test_branch "${project_name}" "${branch_name}" "${tag_name}"
  assert_scriptrun_output "${project_name}" "${branch_name}" 'package.json'
  clone_and_verify_result 'npm' "${project_name}" 'CHANGELOG.mdpackage.json' "${branch_name}"

}

function gradle_project_is_tagged_and_updated_correctly() { #@test
  local -r project_name='gradle-project'
  local -r branch_name='gradle_test'
  local -r tag_name='1.0.1'

  setup_git_test_branch "${project_name}" "${branch_name}" "${tag_name}"
  assert_scriptrun_output "${project_name}" "${branch_name}" 'gradle.properties'
  clone_and_verify_result 'gradle' "${project_name}" 'CHANGELOG.mdgradle.properties' "${branch_name}"
}
