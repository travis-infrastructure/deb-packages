#!/usr/bin/env bash
set -o errexit

if [ "$(id -u 2>/dev/null)" -ne 0 ];then
  echo "Need to run as root"
  exit 1
fi

source /etc/os-release
source deb-builders/lib.sh
#DIR_DEB_PACKAGES=~/deb
#MONGODB_VERSION=
#MONGODB_DEBIAN_VERSION=
#MONGODB_DEBIAN_VERSION_EPOCH=


# apt-get install -y  git
# git clone https://github.com/travis-infrastructure/deb-packages.git
# cd deb-packages
# git checkout mongodb
# export MONGODB_DEBIAN_VERSION=bionic
# export MONGODB_VERSION=4.2.1
# export DIR_DEB_PACKAGES=~/deb/
# export DEB_PACKAGE_NAME=mongodb
# export MONGODB_DEBIAN_VERSION_EPOCH=1

ARCH="$(get_arch)"

if [ -z "$MONGODB_VERSION" ];then
  MONGODB_VERSION=4.0.13
  echo "No provide MONGODB_VERSION env, setting it to ${MONGODB_VERSION}"
fi

if [ -z "${VERSION_CODENAME}" ];then
  echo "Please provice VERSION_CODENAME var, couldn't read from os-release"
  exit 1
fi

if [ -z "$MONGODB_DEBIAN_VERSION" ];then
  MONGODB_DEBIAN_VERSION=${VERSION_CODENAME}
  echo "No provide MONGODB_DEBIAN_VERSION env, setting it to ${MONGODB_DEBIAN_VERSION}"
fi

if [ ! -z "${MONGODB_DEBIAN_VERSION_EPOCH}" ];then
  MONGODB_DEBIAN_VERSION_EPOCH="${MONGODB_DEBIAN_VERSION_EPOCH}:"
fi

install_packages(){
  apt-get update
  apt-get install -y --no-install-recommends gcc clang-6.0 libcurl4-gnutls-dev build-essential libboost-filesystem-dev libboost-program-options-dev libboost-system-dev libboost-thread-dev  python2.7 python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg8-dev zlib1g-dev python-setuptools wget
}

install_packages_s390x(){
  apt-get update
  apt-get install -y software-properties-common
  add-apt-repository universe
  apt-get install -y --no-install-recommends gcc clang-3.8 libcurl4-gnutls-dev build-essential libboost-filesystem-dev libboost-program-options-dev libboost-system-dev libboost-thread-dev  python2.7 python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg8-dev zlib1g-dev python-setuptools wget
}

install_packages_bionic(){
  apt-get update
  apt-get install -y software-properties-common
  add-apt-repository universe
  apt-get install -y --no-install-recommends gcc-8-powerpc-linux-gnu clang-7 libcurl4-gnutls-dev build-essential libboost-filesystem-dev libboost-program-options-dev libboost-system-dev libboost-thread-dev  python3-pip python3-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg8-dev zlib1g-dev python3-setuptools wget libc6-dev-powerpc-cross gcc-8 g++-8
}

get_mongodb_src(){
  wget https://fastdl.mongodb.org/src/mongodb-src-r${MONGODB_VERSION}.tar.gz
  tar -xf mongodb-src-r${MONGODB_VERSION}.tar.gz
}

build_mongodb_bionic(){
  get_mongodb_src
  pushd mongodb-src-r${MONGODB_VERSION}
  pip3 install -r buildscripts/requirements.txt
  TARGET_ARCH=ppc64le python3 buildscripts/scons.py --prefix=/opt/mongo install CC=gcc-8 CXX=g++-8
  popd
}

build_mongodb(){
  get_mongodb_src
  pushd mongodb-src-r${MONGODB_VERSION}
  pip2 install -r buildscripts/requirements.txt
  python2 buildscripts/scons.py --prefix=/opt/mongo install --use-s390x-crc32=off
  popd
}

create_deb_control_file(){
  cat <<EOF >DEBIAN/control
Package: mongodb-server
Version: ${MONGODB_DEBIAN_VERSION_EPOCH}${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}
Section: database
Priority: optional
Architecture: ${ARCH}
Depends: libc6 (>= 2.18), libcurl3 (>= 7.16.2), libgcc1 (>= 1:4.2), libssl1.0.0 (>= 1.0.1), adduser, tzdata
Maintainer: Artur Rupp <arturrupp@travis-ci.org>
Description: Mongodb database server
EOF
}

create_deb_control_file_bionic(){
  cat <<EOF >DEBIAN/control
Package: mongodb-server
Version: ${MONGODB_DEBIAN_VERSION_EPOCH}${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}
Section: database
Priority: optional
Architecture: ${ARCH}
Depends: libc6 (>= 2.27), libcurl4 (>= 7.58.0), libgcc1 (>= 1:8.3), libssl1.0.0 (>= 1.0.2), adduser, tzdata
Maintainer: Artur Rupp <arturrupp@travis-ci.org>
Description: Mongodb database server
EOF
}

create_deb_control_file(){
  cat <<EOF >DEBIAN/control
Package: mongodb-server
Version: ${MONGODB_DEBIAN_VERSION_EPOCH}${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}
Section: database
Priority: optional
Architecture: ${ARCH}
Depends: libc6 (>= 2.18), libcurl3 (>= 7.16.2), libgcc1 (>= 1:4.2), libssl1.0.0 (>= 1.0.1), adduser, tzdata
Maintainer: Artur Rupp <arturrupp@travis-ci.org>
Description: Mongodb database server
EOF
}

call_build_function func_name="install_packages"
call_build_function func_name="build_mongodb"


#main
mkdir "mongodb-${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}-${ARCH}"
pushd "mongodb-${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}-${ARCH}"

#mkdir -p etc/init.d DEBIAN etc/redis usr/src/redis-tmp usr/local/bin/ var/log/redis/
mkdir -p DEBIAN lib/systemd/system opt/mongo/etc

cat <<\EOF >DEBIAN/postinst
#!/bin/bash
mkdir -p /var/lib/mongodb
adduser --system --no-create-home --group --home /var/lib/mongodb mongodb
chown mongodb:mongodb /var/lib/mongodb
mkdir -p /var/log/mongodb
chown mongodb:mongodb /var/log/mongodb

update-alternatives --install /usr/local/bin/mongo mongo /opt/mongo/bin/mongo 50
update-alternatives --install /usr/local/bin/mongod mongod /opt/mongo/bin/mongod 50
update-alternatives --install /usr/local/bin/mongos mongos /opt/mongo/bin/mongos 50

EOF

chmod +x DEBIAN/postinst

call_build_function func_name="create_deb_control_file"

cat <<\EOF >lib/systemd/system/mongod.service
[Unit]
Description=MongoDB Database Server
Documentation=https://docs.mongodb.org/manual
After=network.target

[Service]
User=mongodb
Group=mongodb
EnvironmentFile=-/etc/default/mongod
ExecStart=/opt/mongo/bin/mongod --config /opt/mongo/etc/mongod.conf
PIDFile=/var/run/mongodb/mongod.pid
# file size
LimitFSIZE=infinity
# cpu time
LimitCPU=infinity
# virtual memory size
LimitAS=infinity
# open files
LimitNOFILE=64000
# processes/threads
LimitNPROC=64000
# locked memory
LimitMEMLOCK=infinity
# total threads (user+kernel)
TasksMax=infinity
TasksAccounting=false

[Install]
WantedBy=multi-user.target

EOF

chmod 644 lib/systemd/system/mongod.service

cat <<\EOF >opt/mongo/etc/mongod.conf
# for documentation of all options, see:
#   http://docs.mongodb.org/manual/reference/configuration-options/

storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
#  engine:
#  mmapv1:
#  wiredTiger:

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# network interfaces
net:
  port: 27017
  bindIp: 127.0.0.1

# how the process runs
processManagement:
  timeZoneInfo: /usr/share/zoneinfo

EOF
chmod 644 opt/mongo/etc/mongod.conf
popd

echo "cp from /opt/mongo/bin"
cp -a /opt/mongo/bin "mongodb-${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}-${ARCH}/opt/mongo/"

dpkg-deb --build "mongodb-${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}-${ARCH}"

prepare_deb_file "$(realpath "mongodb-${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}-${ARCH}.deb")" "${DIR_DEB_PACKAGES}/${VERSION_CODENAME}"
