#!/usr/bin/env bash
set -o errexit
APT_REPO_CODENAMES="bionic xenial"

#IN VARIABLES
# APT_GPG_PRV_KEY # encoded with base64 with new lines as \n
# APT_GPG_PUB_KEY # encoded with base64 with new lines as \n
# export AWS_ACCESS_KEY_ID=""
# export AWS_SECRET_ACCESS_KEY=""
# export AWS_DEFAULT_REGION=us-east-2
# export DIR_DEB_PACKAGES='/root/deb'

APT_GPG_PRV_KEY=$(echo "$APT_GPG_PRV_KEY" | base64 -d)
APT_GPG_PUB_KEY=$(echo "$APT_GPG_PUB_KEY" | base64 -d)

install_awscli(){
  if ! command -v aws &> /dev/null
  then
    echo "Installing aws cli"
    curl -O https://bootstrap.pypa.io/get-pip.py
    sudo -H python3 get-pip.py
    sudo -H pip3 install 'awscli==1.16' && \
    rm get-pip.py
  fi
}

import_prv_key(){
  echo -en  "$APT_GPG_PRV_KEY" | gpg2 --allow-secret-key-import --import
}

generate_apt_repo(){
  mkdir -p repo/conf

  cat /dev/null > repo/conf/distributions
  for APT_REPO_CODENAME in $APT_REPO_CODENAMES; do
    cat <<EOF >>repo/conf/distributions
Origin: travis-ci-deb.s3.us-east-2.amazonaws.com
Label: travis-ci-deb.s3.us-east-2.amazonaws.com
Codename: ${APT_REPO_CODENAME}
Architectures: amd64 s390x ppc64le arm64
Components: main
Description: Travis CI APT  ubuntu xenial repo
SignWith: ABF8D524

EOF
  done

  for SUB_DIR_DEB_PACKAGES in "$DIR_DEB_PACKAGES"/*; do
    APT_VERSION_CODE_NAME=$(basename "$SUB_DIR_DEB_PACKAGES")
    if [ -d "$SUB_DIR_DEB_PACKAGES" ];then
      for DEB_FILE_PATH in "$SUB_DIR_DEB_PACKAGES"/*; do
        if [ -f "$DEB_FILE_PATH" ];then
          reprepro -b repo/ includedeb "${APT_VERSION_CODE_NAME}" "${DEB_FILE_PATH}" && rc=$? || rc=$?
          if [ $rc -ne 0 ];then
            echo "There was some problems while generating repo"
          fi
        fi
      done
    fi
  done
}

get_repo_folders_from_s3(){
  mkdir -p repo repo/db repo/dists repo/conf
  aws s3 cp --recursive  s3://travis-ci-deb/db/ repo/db
  aws s3 cp --recursive  s3://travis-ci-deb/dists/ repo/dists
  aws s3 cp --recursive  s3://travis-ci-deb/conf/ repo/conf
}

get_repo_deb_build_folder_from_s3(){
  aws s3 cp --recursive  s3://travis-ci-deb/deb-builds-tmp "${DIR_DEB_PACKAGES}"
}

sync_repo_to_s3(){
  if [ -d repo/dists/ ];then
    aws s3 sync repo/dists/. s3://travis-ci-deb/dists/ --acl public-read
  else
    echo "Nothind to send to repo/dists"
  fi
  if [ -d repo/pool/ ];then
    aws s3 sync repo/pool/. s3://travis-ci-deb/pool/ --acl public-read
  else
    echo "Nothind to send to repo/pool"
  fi
  if [ -f repo/pub-key.gpg ];then
    aws s3 cp repo/pub-key.gpg s3://travis-ci-deb/ --acl public-read
  else
    echo "Nothind gpg public key to send"
  fi
  if [ -d repo ];then
    aws s3 sync repo/. s3://travis-ci-deb/
  else
    echo "Nothing to repo"
  fi
}

save_publi_gpg_key(){
  echo -en  "$APT_GPG_PUB_KEY" > repo/pub-key.gpg
}

sudo apt-get update
sudo apt-get -y install reprepro wget
install_awscli
import_prv_key
get_repo_folders_from_s3
get_repo_deb_build_folder_from_s3
generate_apt_repo
save_publi_gpg_key
sync_repo_to_s3

echo "USAGE example for redis-server on xenial
echo 'deb http://travis-ci-deb.s3.us-east-2.amazonaws.com xenial main' > /etc/apt/sources.list.d/travis-packages.list;
echo -e \"Package: redis-server\nPin: release o=travis-ci-deb.s3.us-east-2.amazonaws.com\nPin-Priority: 900\" > /etc/apt/preferences.d/redis
wget -qO - https://travis-ci-deb.s3.us-east-2.amazonaws.com/pub-key.gpg | apt-key add -"
