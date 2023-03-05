FROM cgr.dev/chainguard/wolfi-base

RUN apk update && apk add --no-cache --update-cache \
  curl \
  acl \
  bash \
  git \
  libstdc++ \
  gpg \
  openssh-client \
  openssh-keygen \
  && ln -sf /bin/bash /bin/sh

SHELL ["/bin/bash", "-c"]

RUN mkdir -p /app/repo && git clone https://github.com/asdf-vm/asdf.git /app/.asdf --branch v0.11.2 \
  && echo '. /app/.asdf/asdf.sh' >> /etc/bash.bashrc


ENV ASDF_DIR=/app/.asdf
ENV ASDF_DATA_DIR=/app/.asdf

RUN export ASDF_DIR='/app/.asdf' && export ASDF_DATA_DIR='/app/.asdf' \
  && source "/app/.asdf/asdf.sh" \
  && asdf plugin add nodejs \
  && asdf install nodejs 18.4.0 \
  && asdf global nodejs 18.4.0 \
  && asdf plugin add maven \
  && asdf install maven 3.8.7 \
  && asdf global maven 3.8.7 \
  && asdf plugin add java \
  && asdf install java adoptopenjdk-17.0.4+101 \
  && asdf global java adoptopenjdk-17.0.4+101 \
  && asdf plugin add semver \
  && asdf install semver 3.4.0 \
  && asdf global semver 3.4.0 \
  && asdf plugin add git-chglog \
  && asdf install git-chglog 0.15.4 \
  && asdf global git-chglog 0.15.4

COPY /.tool-versions /app/.tool-versions
COPY /bash/src/changelog_release.bash /app/changelog_release.bash
COPY /bash/src/changelog_release_templates /app/changelog_release_templates 

CMD ["/bin/bash", "-c","source /etc/bash.bashrc;/app/changelog_release.bash"]
