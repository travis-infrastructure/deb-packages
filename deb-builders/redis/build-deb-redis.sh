#!/usr/bin/env bash
set -o errexit
source /etc/os-release
source deb-builders/lib.sh
#DIR_DEB_PACKAGES=~/deb
#REDIS_VERSION= - redis version, def 5.0.6
#REDIS_DEBIAN_VERSION= def to xenial (usage as xenial1, xenial2)

ARCH="$(get_arch)"

if [ -z "$REDIS_VERSION" ];then
  REDIS_VERSION=5.0.6
  echo "No provide REDIS_VERSION env, setting it to 5.0.6"
fi

if [ -z "$REDIS_DEBIAN_VERSION" ];then
  REDIS_DEBIAN_VERSION=${VERSION_CODENAME}
  echo "No provide REDIS_DEBIAN_VERSION env, setting it to ${REDIS_DEBIAN_VERSION}"
fi

build_redis(){
  wget http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz
  tar -xf redis-${REDIS_VERSION}.tar.gz
  pushd redis-${REDIS_VERSION}
  make
  popd
}

build_redis

#main
mkdir "redis-${REDIS_VERSION}~${REDIS_DEBIAN_VERSION}-${ARCH}"
pushd "redis-${REDIS_VERSION}~${REDIS_DEBIAN_VERSION}-${ARCH}"

mkdir -p etc/init.d DEBIAN etc/redis usr/src/redis-tmp usr/local/bin/ var/log/redis/

cat <<\EOF >DEBIAN/postinst
#!/bin/bash
useradd -rm -d /var/lib/redis -s /usr/sbin/nologin redis
chown redis:redis /etc/redis/redis.conf /var/log/redis
ln -s  /usr/local/bin/redis-server /usr/local/bin/redis-sentinel
EOF

chmod +x DEBIAN/postinst

cat <<EOF >DEBIAN/control
Package: redis-server
Version: ${REDIS_VERSION}~${REDIS_DEBIAN_VERSION}
Section: base
Priority: optional
Architecture: ${ARCH}
Depends: libjemalloc1 (>=3.0), passwd, coreutils, libc6 (>=2.23)
Maintainer: Artur Rupp <arturrupp@travis-ci.org>
Description: Redis server
EOF


cat <<\EOF >etc/init.d/redis-server
#! /bin/sh
### BEGIN INIT INFO
# Provides:		redis-server
# Required-Start:	$syslog $remote_fs
# Required-Stop:	$syslog $remote_fs
# Should-Start:		$local_fs
# Should-Stop:		$local_fs
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	redis-server - Persistent key-value db
# Description:		redis-server - Persistent key-value db
### END INIT INFO


PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/local/bin/redis-server
DAEMON_ARGS=/etc/redis/redis.conf
NAME=redis-server
DESC=redis-server

RUNDIR=/var/run/redis
PIDFILE=$RUNDIR/redis-server.pid

test -x $DAEMON || exit 0

if [ -r /etc/default/$NAME ]
then
	. /etc/default/$NAME
fi

. /lib/lsb/init-functions

set -e

if [ "$(id -u)" != "0" ]
then
	log_failure_msg "Must be run as root."
	exit 1
fi

case "$1" in
  start)
	echo -n "Starting $DESC: "
	mkdir -p $RUNDIR
	touch $PIDFILE
	chown redis:redis $RUNDIR $PIDFILE
	chmod 755 $RUNDIR

	if [ -n "$ULIMIT" ]
	then
		ulimit -n $ULIMIT || true
	fi

	if start-stop-daemon --start --quiet --oknodo --umask 007 --pidfile $PIDFILE --chuid redis:redis --exec $DAEMON -- $DAEMON_ARGS
	then
		echo "$NAME."
	else
		echo "failed"
	fi
	;;
  stop)
	echo -n "Stopping $DESC: "

	if start-stop-daemon --stop --retry forever/TERM/1 --quiet --oknodo --pidfile $PIDFILE --exec $DAEMON
	then
		echo "$NAME."
	else
		echo "failed"
	fi
	rm -f $PIDFILE
	sleep 1
	;;

  restart|force-reload)
	${0} stop
	${0} start
	;;

  status)
	status_of_proc -p ${PIDFILE} ${DAEMON} ${NAME}
	;;

  *)
	echo "Usage: /etc/init.d/$NAME {start|stop|restart|force-reload|status}" >&2
	exit 1
	;;
esac

exit 0

EOF

chmod 755 etc/init.d/redis-server

cat <<\EOF >etc/redis/redis.conf
daemonize yes
pidfile /var/run/redis/redis-server.pid
bind 127.0.0.1
protected-mode yes
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300
supervised no
loglevel notice
logfile /var/log/redis/redis-server.log
databases 16
always-show-logo yes
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
replica-priority 100
lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no
appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
EOF
chmod 640 etc/redis/redis.conf

popd

echo "cp from redis-${REDIS_VERSION}"
cp -a redis-${REDIS_VERSION}/src/redis-check-aof redis-${REDIS_VERSION}/src/redis-check-rdb redis-${REDIS_VERSION}/src/redis-cli redis-${REDIS_VERSION}/src/redis-benchmark redis-${REDIS_VERSION}/src/redis-server redis-${REDIS_VERSION}~${REDIS_DEBIAN_VERSION}-${ARCH}/usr/local/bin/

dpkg-deb --build "redis-${REDIS_VERSION}~${REDIS_DEBIAN_VERSION}-${ARCH}"

prepare_deb_file "$(realpath "redis-${REDIS_VERSION}~${REDIS_DEBIAN_VERSION}-${ARCH}.deb")" "${DIR_DEB_PACKAGES}/${VERSION_CODENAME}"
