#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Josef Andersson
#
# SPDX-License-Identifier: MIT

# A no-thrills bash script to generate a md5 and sha256 for every directory in a structure.
# in the future , make it more extensible with a few options and better fail-saftey
# It will overwrite any existing checksums

# abort on nonzero exitstatus
set -o errexit
# abort on unbound variable
set -o nounset
# don't hide errors within pipes
set -o pipefail

#Dir from where to start, is modified by the -p path option, or defaults to PWD

is_command_installed() {

  local -r sumprog=$1;

  if ! [[ -x "$(command -v "${sumprog}")" ]]; then
    echo "${sumprog} could not be run, make sure it is installed and executable";
    return 1;
  fi
}

generate_sum() {

  local -r sumprog=$1;
  local -r outputfile=$2;

  find "${WORKDIR}" -type d | sort | while read -r dir; do 

  cd "${dir}" || return 2;


  echo "Processing ${dir} with ${sumprog}";
  local results=$(find . -maxdepth 1 -type f -not -name '*.md5' -not -name '*.sha256' -not -name 'dirsumgen.bash' -not -name 'dirsumgen' -exec "${sumprog}" {} \;)

  if [[ -n "${results}" ]]; then
    echo "${results}" > "${outputfile}";
    chmod a=r "${dir}"/"${outputfile}" ;
  else
    echo "Skipped writing a sum for "${dir}" as it had no files!";
  fi
done 

}

verify_sum() {

  local -r sumprog=$1;
  local -r outputfile=$2;

  find "${WORKDIR}" -name "${outputfile}" | sort | while read -r afile; do 

  cd "${afile%/*}" || return 3; 
  eval "${sumprog}" -c "${outputfile}"; done

}

usage() { 

  printf "%s\n" \
  "usage: dirsumgen [-h][-g][-v][-p path]" \
  "" \
  "dirsumgen is a bash script for adding md5 and sha256 sums for directories." \
  "" \
  "arguments:" \
  " -h  help (this text)." \
  " -v  verify found md5 and sha256 files." \
  " -g  generate md5 and sh256 sums for a directory tree. One sum file for each dir." \
  " -p  define root of dir tree to create sums for. NOTE: Default value is PWD.";

}


input_handler() {
  #declare all getopts vars local
  local OPTIND  

  declare WORKDIR="${PWD}"

  #handle p first, in whatever order it was given as arg,
  while getopts "p:vglh" options; do

    case "${options}" in
      p)
        echo "Setting workdir to ${OPTARG}" ;
        WORKDIR="${OPTARG}"
        ;;
      v)
        ;;
      g)
        ;;
      l)
        ;;
      h)
        ;;
      ?)
        echo "Please set -p to a valid option"
        exit 1
        ;;
    esac
  done
 
  if [[ ! -d "${WORKDIR}" ]];then
    echo "Directory "${WORKDIR}" is not valid. Check -p option or PWD."
    exit 4
  fi

  OPTIND=1

  while getopts "p:vglh" options; do

    case "${options}" in
      p)
        ;;
      v) 
        echo "Verifying sums starting from rootdir ${WORKDIR}";
        verify_sum "md5sum" "md5Sum.md5";
        verify_sum "sha256sum" "sha256Sum.sha256";
        ;;
      g)
        echo "Generating sums starting from rootdir ${WORKDIR}" ;
        generate_sum "md5sum" "md5Sum.md5";
        generate_sum "sha256sum" "sha256Sum.sha256";
        ;;
      h)
        usage;
        ;;
      l)
        echo "generating with path...to do"; 
        #generate_sum "md5sum" "md5Sum.md5";
        #generate_sum "sha256sum" "sha256Sum.sha256";
        ;;
      *) usage;
    esac
  done
  
  shift $(($OPTIND - 1))

  if(( $OPTIND == 1 ));then
    usage;
  fi
}


main() {

  is_command_installed "md5sum"
  is_command_installed "sha256sum"


  echo "$@"
  input_handler "$@"

}

# Only runs main if not sourced.
# For easier testing with bats
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  main "$@"
  if [ $? -gt 0 ]
  then
    exit 1
  fi
fi
