# syntax=docker/dockerfile:1

# слой с unrar, как в оригинале
FROM ghcr.io/linuxserver/unrar:latest AS unrar

# основной базовый образ linuxserver с s6
FROM ghcr.io/linuxserver/baseimage-ubuntu:noble

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CALIBREWEB_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="notdriz"

ENV \
  QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox"

RUN \
  echo "**** install build packages ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential \
    libldap2-dev \
    libsasl2-dev \
    python3-dev && \
  echo "**** install runtime packages ****" && \
  apt-get install -y --no-install-recommends \
    imagemagick \
    ghostscript \
    libasound2t64 \
    libldap2 \
    libmagic1t64 \
    libsasl2-2 \
    libxi6 \
    libxslt1.1 \
    libxfixes3 \
    python3-venv \
    sqlite3 \
    xdg-utils && \
  echo "**** install calibre-web ****" && \
  if [ -z ${CALIBREWEB_RELEASE+x} ]; then \
    CALIBREWEB_RELEASE=$(curl -sX GET "https://api.github.com/repos/janeczku/calibre-web/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  curl -o \
    /tmp/calibre-web.tar.gz -L \
    https://github.com/janeczku/calibre-web/archive/${CALIBREWEB_RELEASE}.tar.gz && \
  mkdir -p \
    /app/calibre-web && \
  tar xf \
    /tmp/calibre-web.tar.gz -C \
    /app/calibre-web --strip-components=1 && \
  cd /app/calibre-web && \
  python3 -m venv /lsiopy && \
  pip install -U --no-cache-dir \
    pip \
    wheel && \
  pip install -U --no-cache-dir --find-links https://wheel-index.linuxserver.io/ubuntu/ -r \
    requirements.txt -r \
    optional-requirements.txt && \
  echo "**** install kepubify ****" && \
  if [ -z ${KEPUBIFY_RELEASE+x} ]; then \
    KEPUBIFY_RELEASE=$(curl -sX GET "https://api.github.com/repos/pgaskin/kepubify/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  curl -o \
    /usr/bin/kepubify -L \
    https://github.com/pgaskin/kepubify/releases/download/${KEPUBIFY_RELEASE}/kepubify-linux-64bit && \
  echo "**** cleanup ****" && \
  apt-get -y purge \
    build-essential \
    libldap2-dev \
    libsasl2-dev \
    python3-dev && \
  apt-get -y autoremove && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /root/.cache

# add local files (s6 сервисы и init-скрипты linuxserver)
COPY root/ /

# add unrar
COPY --from=unrar /usr/bin/unrar-ubuntu /usr/bin/unrar

# ports and volumes
EXPOSE 8083
VOLUME /config

# подготовка к запуску под UID 1000 в Kubernetes:
# 1) /run принадлежит UID 1000, чтобы s6-preinit не падал
# 2) создаём пользователя calibreweb с UID 1000, чтобы не было "I have no name!"
RUN \
  mkdir -p /run && \
  chown 1000:1000 /run && \
  if ! id -u 1000 >/dev/null 2>&1; then \
    useradd -u 1000 -d /config -M calibreweb || true; \
  fi
