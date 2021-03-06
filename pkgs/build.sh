#!/bin/bash

NFPM_VERSION=1.8.0

if [ -z ${SFTPGO_VERSION} ]
then
  LATEST_TAG=$(git describe --tags $(git rev-list --tags --max-count=1))
  NUM_COMMITS_FROM_TAG=$(git rev-list ${LATEST_TAG}.. --count)
  #COMMIT_HASH=$(git rev-parse --short HEAD)
  VERSION=$(echo "${LATEST_TAG}" | awk -F. -v OFS=. '{$NF++;print}')-dev.${NUM_COMMITS_FROM_TAG}
else
  VERSION=${SFTPGO_VERSION}
fi

mkdir dist
echo -n ${VERSION} > dist/version
cd dist
BASE_DIR="../.."

cp ${BASE_DIR}/sftpgo.json .
sed -i "s|sftpgo.db|/var/lib/sftpgo/sftpgo.db|" sftpgo.json
sed -i "s|\"users_base_dir\": \"\",|\"users_base_dir\": \"/var/lib/sftpgo/users\",|" sftpgo.json
sed -i "s|\"templates\"|\"/usr/share/sftpgo/templates\"|" sftpgo.json
sed -i "s|\"static\"|\"/usr/share/sftpgo/static\"|" sftpgo.json
sed -i "s|\"backups\"|\"/var/lib/sftpgo/backups\"|" sftpgo.json
sed -i "s|\"credentials\"|\"/var/lib/sftpgo/credentials\"|" sftpgo.json

$BASE_DIR/sftpgo gen completion bash > sftpgo-completion.bash
$BASE_DIR/sftpgo gen man -d man1

cat >nfpm.yaml <<EOF
name: "sftpgo"
arch: "amd64"
platform: "linux"
version: ${VERSION}
release: 1
section: "default"
priority: "extra"
maintainer: "Nicola Murino <nicola.murino@gmail.com>"
provides:
  - sftpgo
description: |
  Fully featured and highly configurable SFTP server
  SFTPGo has optional FTP/S and WebDAV support.
  It can serve local filesystem, S3 (Compatible) Object Storages
  and Google Cloud Storage
vendor: "SFTPGo"
homepage: "https://github.com/drakkan/sftpgo"
license: "GPL-3.0"
files:
  ${BASE_DIR}/sftpgo: "/usr/bin/sftpgo"
  ./sftpgo-completion.bash: "/usr/share/bash-completion/completions/sftpgo"
  ./man1/*: "/usr/share/man/man1/"
  ${BASE_DIR}/init/sftpgo.service: "/lib/systemd/system/sftpgo.service"
  ${BASE_DIR}/examples/rest-api-cli/sftpgo_api_cli: "/usr/bin/sftpgo_api_cli"
  ${BASE_DIR}/templates/*: "/usr/share/sftpgo/templates/"
  ${BASE_DIR}/static/**/*: "/usr/share/sftpgo/static/"

config_files:
  ./sftpgo.json: "/etc/sftpgo/sftpgo.json"

empty_folders:
  - /var/lib/sftpgo

overrides:
  deb:
    recommends:
      - bash-completion
      - python3-requests
      - python3-pygments
    scripts:
      postinstall: ../scripts/deb/postinstall.sh
      preremove: ../scripts/deb/preremove.sh
      postremove: ../scripts/deb/postremove.sh
  rpm:
    recommends:
      - bash-completion
      # centos 8 has python3-requests, centos 6/7 python-requests
    scripts:
      postinstall: ../scripts/rpm/postinstall
      preremove: ../scripts/rpm/preremove
      postremove: ../scripts/rpm/postremove

rpm:
  compression: lzma

  config_noreplace_files:
    ./sftpgo.json: "/etc/sftpgo/sftpgo.json"

EOF

curl --retry 5 --retry-delay 2 --connect-timeout 10 -L -O \
  https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_Linux_x86_64.tar.gz
tar xvf nfpm_1.8.0_Linux_x86_64.tar.gz nfpm
chmod 755 nfpm
mkdir deb
./nfpm -f nfpm.yaml pkg -p deb -t deb
mkdir rpm
./nfpm -f nfpm.yaml pkg -p rpm -t rpm