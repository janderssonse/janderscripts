#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Josef Andersson
#
# SPDX-License-Identifier: MIT

# abort on nonzero exitstatus
set -o errexit
# don't hide errors within pipes
set -o pipefail
# Allow error traps on function calls, subshell environment, and command substitutions
set -o errtrace

GPG_EXPORT_PATH="$HOME/.gnupg/.exported-keyring"

create_export_dir() {
  if [[ -d "${GPG_EXPORT_PATH}" ]]; then
    chmod 0700 "${GPG_EXPORT_PATH}"
  else
    mkdir -p "${GPG_EXPORT_PATH}"
    chmod 0700 "${GPG_EXPORT_PATH}"
  fi
}

export_keys() {

  if [[ ! -d "${GPG_EXPORT_PATH}" ]]; then
    printf "%s\n" "Unable to create dir ${GPG_EXPORT_PATH}"
    exit 1
  else
    printf "%s\n" "Exporting private key to ${GPG_EXPORT_PATH}"
    gpg -a --export-secret-key -o "${GPG_EXPORT_PATH}/private-key.asc"
    printf "%s\n" "Exporting public keyring to ${GPG_EXPORT_PATH}"

    for key in $(gpg -k --with-colons | grep pub -A 1 | grep fpr | cut -d: -f10); do
      printf "%s\n" "  Key: $key"
      gpg -a --export "${key}" >>"${GPG_EXPORT_PATH}/${key}.asc"
      chmod 0600 "${GPG_EXPORT_PATH}/${key}.asc"
    done

    printf "%s\n" "Exporting ownertrust to ${GPG_EXPORT_PATH}"
    gpg --export-ownertrust >"${GPG_EXPORT_PATH}/ownertrust.txt"
    chmod 0600 "${GPG_EXPORT_PATH}/ownertrust.txt"
  fi
}

create_export_dir
export_keys
