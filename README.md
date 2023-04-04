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

- `bash/src/changelog_release.bash` - A util script to making an atomic release commit including an tag, changelog, updated project file. mvn, npm or gradle. Relies on Conventional Commits-standard.
- `bash/src/dirsumgen.bash` - A wrapper for the creating md5 and sha256 sums for directory trees. One of each for each dir.

## Dependencies

### Bash

### General Usage

```console
./bash/src/<script>.bash -h
```

### SCRIPT: changelog_release usage

To make a nice release commit might need a few boring steps - adding a changelog, tagging, update project verison. Add Conventional commits, signing and signoffs. It is easy to forget and miss something. So why not make it easier, a one step process:

This script:

1. calculate and tags next semver tag
2. generates a changelog
3. updates the project file version with the version tag
4. commits the changelog and tag in a release commit

#### Requirements

1. Your project is following Conventional Commits Standard.
2. Your Git Settings is configured to sign and tag with SSH.
3. You need `asdf-vm` installed to easily download all dependencies for the script.

#### Usage

- Clone this repo

```console
git@github.com:janderssonse/janderscripts.git
```

#### ALTERNATIVE 1 - Running the Changelog_Release script directly

1. Install [asdf-vm](https://asdf-vm.com/guide/getting-started.html)

2. Install the needed dependencies. Here are two commands that adds the plugins and then installs them for you.

```console
cut -d' ' -f1 .tool-versions | xargs -i asdf plugin add {}
asdf install
```

3. From the root dir of the project you are about to update a changelog to, do

```console
/path/to/janderscriptsrepo/you/just/cloned/bash/src/changelog_release.bash --help
```

#### ALTERNATIVE 2 - Running the Container image (saves you installing asdf-vm and dependencies)

There is a helpscript which will mount ssh agent and more for you.

```console
/path/to/repo/you/just/cloned/scripts/run_changelog_release_container.sh '--help'
```

And you should get an overview of options. NOTE: as you run in an container, arguments will have to be given in one string surrounded by ''



**The script requires that you are following the [conventional commit](https://www.conventionalcommits.org) format, and the commits and tags will be gpg-signed and signed off.**

#### Examples

<figure>
<img src="./docs/img/changelog_release_cli.png " alt="changelog_release cli" width="800"/>  
<figcaption><em>changelog_release with --help option</em></figcaption>
</figure>

<figure>
<img src="./docs/img/changelog_release_run.png " alt="changelog_release cli" width="800"/>  
<figcaption ><em>changelog_release run</em></figcaption>
</figure>

<figure>
<img src="./docs/img/changelog_release_log.png " alt="changelog_release cli" width="800"/>  
<figcaption><em>changelog_release generated changelog example</em></figcaption>
</figure>

<figure>
<img src="./docs/img/changelog_release_commit_example.png " alt="changelog_release cli" width="800"/>  
<figcaption><em>changelog_release commit example - project file, changelog, tag and release commit message</em></figcaption>
</figure>

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
