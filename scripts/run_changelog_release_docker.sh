#!/usr/bin/env bash

#WIP
docker run --volume \
  --volume ~/.ssh/known_hosts://etc/ssh/ssh_known_hosts \
  --user "$UID":"$GID" --network host \
  --workdir="/app/repo" \
  --volume="/etc/group:/etc/group:ro" \
  --volume="/etc/passwd:/etc/passwd:ro" \
  --volume="/etc/shadow:/etc/shadow:ro" \
  --volume="$HOME/.m2/repository:/app/.m2/repository:ro" \
  -v "$(pwd)":/app/repo \
  -v "$SSH_AUTH_SOCK:$SSH_AUTH_SOCK" \
  -e SSH_AUTH_SOCK="${SSH_AUTH_SOCK}" \
  -e LOCAL_MVN_REPO='/app/.m2/repository' \
  --rm -it ch /bin/bash <GITCONFIG >:/etc/gitconfig:ro
