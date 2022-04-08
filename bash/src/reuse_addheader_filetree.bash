#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Josef Andersson
#
# SPDX-License-Identifier: MIT

#set -ex
shopt -s globstar nullglob

unset copyright
unset license
unset year
unset extensions
unset rootpath
unset skipun
unset reusetool

is_command_installed() {

  local prog=$1;
  local link=$2;

  if ! [[ -x "$(command -v "${prog}")" ]]; then
    echo "${prog} could not be found, make sure it is installed!";
    echo "See ${link} for install options.";
    exit 1;
  fi
}

usage() { 

  echo "Usage: $0 -c COPYRIGHT -l LICENSE -y YEAR -e EXTENSIONS [-p ROOTPATH] [-s SKIPUNREGOGNIZED ]";
  exit 1;
}

printinput() { 


  if  [ -z "$skipun" ]; then
    echo "Settings: -c "${copyright}" -l ${license} -y ${year} -e ${extensions} -p ${rootpath} -s" ;
  else
    echo "Settings: -c "${copyright}" -l ${license} -y ${year} -e ${extensions} -p ${rootpath}";
  fi
}


while getopts c:l:y:e:p:si: opt; do
  case $opt in
    c) copyright=$OPTARG ;;
    l) license=$OPTARG ;;
    y) year=$OPTARG ;;
    e) extensions+=("$OPTARG") ;;
    p) rootpath=$OPTARG ;;
    s) skipun="skipun" ;;
    i) reusetool=$OPTARG ;;
    *) usage
  esac
done


#Default tool path is just the command
if  [[ -z "${reusetool}" ]]; then
  reusetool="reuse"
fi

#Default folderpath = .
if  [[ -z "${rootpath}" ]]; then
  rootpath='.'
fi 

#Default file extensions = *
if  [[ -z "${extensions[*]}" ]]; then
  extensions+='*'
fi 

is_command_installed "${reusetool}" "https://github.com/fsfe/reuse-tool"

shift "$(( OPTIND - 1 ))"



if [ -z "$copyright" ] || [ -z "$license" ] || [ -z "$year" ] || [ -z "$extensions" ] || [ -z "$rootpath" ]; then
  printinput;
  usage;
fi



addheader() {

  echo "Adding header data to file/s"
  printinput

  for ext in "${extensions[@]}"
  do
    echo "$ext"
    for file in "${rootpath}"/**/*.$ext
    do
      (( count++ )) || true
      #echo "Finding file no. $count"
      echo "$file"
      eval "${reusetool} addheader --license \""${license}\"" --year \"${year}\" --copyright \"${copyright}\" --skip-unrecognised ${file}"
    done
  done
}

addheader

