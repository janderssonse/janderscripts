![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/janderssonse/janderscripts)
[![REUSE status](https://api.reuse.software/badge/github.com/janderssonse/janderscripts)](https://api.reuse.software/info/github.com/janderssonse/janderscripts)

# Janderscripts

Intented to gather a mixed collection of small helpers and scripts, mostly for use by myself, but maybe someone else will find something of worth.

## Description

- bash/src/reuse_addheader_filetree.bash - A wrapper for the addheader function of the [REUSE](https://github.com/fsfe/reuse-tool) project.
- bash/src/dirsumgen.bash - A wrapper for the creating md5 and sha256 sums for directory trees. One of each for each dir.

## Dependencies

These have most likely only been tested in an Linux environment.

For Bash scripts, Tests are written with [Bats-core](https://github.com/bats-core/bats-core) test.

## Running the bash tests

First install bats-core

To Install the Bats-core dependencies where the bats scripts can find them (<projectdir>/bash/lib):

```console
$ bash/install_bats.bash
```

```console
$ bash/lib/bats-core/bin/bats bash/tests
```


## Getting involved


See [CONTRIBUTING](docs/CONTRIBUTING.adoc).

----

## License

Scripts in this project are licensed under the [MIT LICENSE](LICENSE).

----

