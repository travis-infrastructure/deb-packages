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

ARCH=$(uname -m)

if [ "$ARCH" == "x86_64" ];then ARCH=amd64; fi
if [ "$ARCH" == "aarch64" ];then ARCH=arm64; fi

if [ -z "$MONGODB_VERSION" ];then
  MONGODB_VERSION=4.0.13
  echo "No provide MONGODB_VERSION env, setting it to ${MONGODB_VERSION}"
fi

if [ -z "$MONGODB_DEBIAN_VERSION" ];then
  MONGODB_DEBIAN_VERSION=${VERSION_CODENAME}
  echo "No provide MONGODB_DEBIAN_VERSION env, setting it to ${MONGODB_DEBIAN_VERSION}"
fi

install_packages(){
  apt-get update
  apt-get install -y --no-install-recommends gcc clang-6.0 libcurl4-gnutls-dev build-essential libboost-filesystem-dev libboost-program-options-dev libboost-system-dev libboost-thread-dev  python2.7 python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg8-dev zlib1g-dev python-setuptools wget 
}

build_mongodb(){
  wget https://fastdl.mongodb.org/src/mongodb-src-r${MONGODB_VERSION}.tar.gz
  tar -xf mongodb-src-r${MONGODB_VERSION}.tar.gz
  pushd mongodb-src-r${MONGODB_VERSION}
  pip2 install -r buildscripts/requirements.txt
  python2 buildscripts/scons.py --prefix=/opt/mongo install --use-s390x-crc32=off
  popd
}

install_packages
build_mongodb

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
EOF

chmod +x DEBIAN/postinst

cat <<EOF >DEBIAN/control
Package: mongodb-server
Version: ${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}
Section: database
Priority: optional
Architecture: ${ARCH}
Depends: libc6 (>= 2.18), libcurl3 (>= 7.16.2), libgcc1 (>= 1:4.2), libssl1.0.0 (>= 1.0.1), adduser, tzdata
Maintainer: Artur Rupp <arturrupp@travis-ci.org>
Description: Mongodb database server
EOF

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
cp -a /opt/mongo/bin mongodb-${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}-${ARCH}/opt/mongo/

dpkg-deb --build "mongodb-${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}-${ARCH}"

prepare_deb_file "$(realpath "mongodb-${MONGODB_VERSION}~${MONGODB_DEBIAN_VERSION}-${ARCH}.deb")" "${DIR_DEB_PACKAGES}/${VERSION_CODENAME}"
