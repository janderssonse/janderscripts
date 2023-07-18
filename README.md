![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/janderssonse/janderscripts)

# Janderscripts

Gather small helpers and scripts, in different languages, mostly for personal usage, but who knows, there might be something for you in there.

About the scripts:

- They should be glue scripts i.e. not use too much intricate logic, but serve as glueing a few specific commands and utils together.
- They should come with a fair amount of unit- and integration-tests.
- They should be structured enough for a non script expert to understand.
- If growing, or beneficial in a more general sense, make no mistake - they should be obsoleted, and rewritten in a more robust language. Even better - be submitted as a PR to any relevant project where the overall function itself would feel at home.

## Currently Maintained Script Descriptions

### Bash

- `bash/src/dirsumgen.bash` - A wrapper for the creating md5 and sha256 sums for directory trees. One of each for each dir.
- `bash/src/export_gpg.sh` - A script which exports your GPG private-, public keys and owner trust data (to a directory with locked down permissions).

_Note: The Changelog-tag script has moved to https://github.com/janderssonse/changelog-tag_

## Dependencies

### Bash

### General Usage

```console
./bash/src/<script>.bash -h
```

#### Usage

- Clone this repo

```console
git@github.com:janderssonse/janderscripts.git
```

### SCRIPT: export_gpg

A script which exports your private keys, public keys and owner trust data (to a directory with locked down permissions).

I use it with [YADM](https://yadm.io/) handle encryption/decryption of the export, and easily move between environments.

YADM-usage:
Put a pattern of `.gnupg/.exported-keyring/*` into `.config/yadm/config` and use YADM encrypt/decrypt.

### Importing the keys to a new location

```console
$ gpg --import "$HOME/.gnupg/.exported-keyring"/*.asc
$ gpg --import-ownertrust "$HOME/.gnupg/.exported-keyring"/ownertrust.txt
```

## Development

### Test and code style

### Bash

- [Code style](https://google.github.io/styleguide/shellguide.html)
- [Tests with Bats-core](https://github.com/bats-core/bats-core).

### Running the bash tests

Install bats-core with support libs.

1. To Install the Bats-core dependencies where the bats scripts can find them (<projectdir>/bash/lib):

```console
./bash/install_bats.bash
```

2. To run the tests:

```console
./bash/lib/bats/bin/bats bash/src/test
```

3. Run a script:

```console
./bash/src/<script>.bash -h
```

## Getting involved

See [CONTRIBUTING](CONTRIBUTING.adoc).

---

## License

Scripts in this project are licensed under the [MIT LICENSE](LICENSE).

---

## Credits

[The Bats project](https://github.com/bats-core/) - for making us create robust Bash-scripts.
