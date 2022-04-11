![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/janderssonse/janderscripts)
[![REUSE status](https://api.reuse.software/badge/github.com/janderssonse/janderscripts)](https://api.reuse.software/info/github.com/janderssonse/janderscripts)

# Janderscripts

Intended to gather a mixed collection of small helpers and scripts, in different languages over time, for use by myself, but maybe someone else will find something of worth, who knows.

## Description

- bash/src/reuse_addheader_filetree.bash - A wrapper for the addheader function of the [REUSE](https://github.com/fsfe/reuse-tool) project.
- bash/src/dirsumgen.bash - A wrapper for the creating md5 and sha256 sums for directory trees. One of each for each dir.

## Dependencies

For Bash scripts, Tests are written with [Bats-core](https://github.com/bats-core/bats-core).

## Running the bash tests

First install bats-core with support libs.

To Install the Bats-core dependencies where the bats scripts can find them (<projectdir>/bash/lib):

```console
$ ./bash/install_bats.bash
```

And to run the tests:

```console
$ bash/lib/bats-core/bin/bats bash/tests
```

To run a script:

```console
$ bash/src/<script>.bash
```

## Getting involved


See [CONTRIBUTING](docs/CONTRIBUTING.adoc).

----

## License

Scripts in this project are licensed under the [MIT LICENSE](LICENSE).

----

## Credits:

Base Bash template used are based on the small:

Bash Template Gist 2020 [Maciej Radzikowski](https://gist.github.com/m-radzikowski/53e0b39e9a59a1518990e76c2bff8038)


