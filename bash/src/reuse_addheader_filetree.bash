#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Josef Andersson
#
# SPDX-License-Identifier: MIT

# A simple script that acts as a wrapper to the REUSE projects addheader.
# It traverses dirs and add headers. This script functionality should be
# ported to Python and added to the RESUSE project in a PR in the future, so we can scrap this

# abort on nonzero exitstatus
set -o errexit
# don't hide errors within pipes
set -o pipefail
# Allow error traps on function calls, subshell environment, and command substitutions
set -o errtrace

shopt -s globstar nullglob

copyright=""
license=""
year=""
extensions=""
rootpath="."
skipun=""

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

is_command_installed() {

  local prog=$1
  local link=$2

  if ! [[ -x "$(command -v "${prog}")" ]]; then
    echo "${prog} could not be found, make sure it is installed!"
    echo "See ${link} for install options."
    exit 1
  fi
}

usage() {

  printf "%s\n" \
    "Usage: reuse_addheader_filetree [-h][-d][-c copyright][-l license][-year][-e extensions][-p rootpath][-s skipunrecognized" \
    "" \
    "reuse_addheader_filetree is a wrapper for adding reuse headers in rootdir." \
    "" \
    "Available options:" \
    "" \
    " -h --help         Print this help and exit" \
    " -d --debug        Output extra script run information" \
    " -c --copyright    Copyright owner" \
    " -l --license      License in spdx format." \
    " -y --year         Year of copyright." \
    " -e --extensions   File extensions to consider." \
    " -p --rootpath     Set the root of dir tree to create sums for and traverse."
}

printinput() {

  if [ -z "$skipun" ]; then
    echo "Settings: -c "${copyright}" -l ${license} -y ${year} -e ${extensions} -p ${rootpath} -s"
  else
    echo "Settings: -c "${copyright}" -l ${license} -y ${year} -e ${extensions} -p ${rootpath}"
  fi
}

addheader() {

  echo "Adding header data to file/s"
  printinput
  local count=0

  for ext in "${extensions[@]}"; do
    echo "$ext"

    for file in "${rootpath}"/**/*.$ext; do
      ((count++)) || true
      #echo "Finding file no. $count"
      echo "$file"
      eval "reuse addheader --license \""${license}\"" --year \"${year}\" --copyright \"${copyright}\" --skip-unrecognised ${file}"
    done
  done
}

parse_params() {

  local args=("$@")
  local arrlength=${#args[@]}
  echo $arrlength
  [[ arrlength -eq 0 ]] && usage

  for ((var = 0; var < ${arrlength}; var++)); do
    echo "${args[$var]}"
    case "${args[$var]}" in
    -h | --help) usage ;;
    -d | --debug) set -x ;;
    -c | --copyright)
      copyright="${args[$var + 1]}"
      var=$var+1
      echo "cip"
      ;;
    -l | --license)
      license="${args[$var + 1]}"
      echo "lciense"
      var=$var+1
      ;;
    -y | --year)
      year="${args[$var + 1]}"
      echo "ye"
      var=$var+1
      ;;
    -e | --extensions)
      extensions="${args[$var + 1]}"
      var=$var+1
      ;;
    -p | --rootpath)
      rootpath="${args[$var + 1]}"
      var=$var+1
      ;;
    -s | --skipun) skipun="skipun" ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
  done

  #Default folderpath = .
  if [[ -z "${rootpath}" ]]; then
    rootpath='.'
  fi

  #Default file extensions = *
  if [[ -z "${extensions[*]}" ]]; then
    extensions+='*'
  fi

  if [ -z "$copyright" ] || [ -z "$license" ] || [ -z "$year" ] || [ -z "$extensions" ] || [ -z "$rootpath" ]; then
    printinput
    usage
    die "Something went wrong: $1"
  fi

  addheader

  return 0
}

main() {

  is_command_installed "reuse" "https://github.com/fsfe/reuse-tool"

  parse_params "$@"
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
