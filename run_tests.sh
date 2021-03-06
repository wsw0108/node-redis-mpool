#!/bin/sh

OPT_CREATE=yes # create the test environment
OPT_DROP=yes   # drop the test environment

cd $(dirname $0)
BASEDIR=$(pwd)
cd -

REDIS_PORT=`node -e "console.log(require('${BASEDIR}/test/support/config').redis_pool.port)"`
export REDIS_PORT

cleanup() {
  if test x"$OPT_DROP" = xyes; then
    if test x"$PID_REDIS" = x; then
      PID_REDIS=$(cat ${BASEDIR}/redis.pid)
      if test x"$PID_REDIS" = x; then
        echo "Could not find a test redis pid to kill it"
        return;
      fi
    fi
    echo "Cleaning up"
    kill ${PID_REDIS}
  fi
}

cleanup_and_exit() {
	cleanup
	exit
}

die() {
	msg=$1
	echo "${msg}" >&2
	cleanup
	exit 1
}

trap 'cleanup_and_exit' 1 2 3 5 9 13

while [ -n "$1" ]; do
        if test "$1" = "--nodrop"; then
                OPT_DROP=no
                shift
                continue
        elif test "$1" = "--nocreate"; then
                OPT_CREATE=no
                shift
                continue
        else
                break
        fi
done

if [ -z "$1" ]; then
        echo "Usage: $0 [<options>] <test> [<test>]" >&2
        echo "Options:" >&2
        echo " --nocreate   do not create the test environment on start" >&2
        echo " --nodrop     do not drop the test environment on exit" >&2
        exit 1
fi

TESTS=$@

if test x"$OPT_CREATE" = xyes; then
  echo "Starting redis on port ${REDIS_PORT}"
  echo "port ${REDIS_PORT}" | redis-server - > ${BASEDIR}/test.log &
  PID_REDIS=$!
  echo ${PID_REDIS} > ${BASEDIR}/redis.pid

  #echo "Preparing the environment"
  #cd ${BASEDIR}/test/support; sh prepare_db.sh || die "database preparation failure"; cd -
fi

PATH=node_modules/.bin/:$PATH

echo "Running tests"
mocha -t 500 -u tdd ${MOCHA_OPTS} ${TESTS}
ret=$?

cleanup

exit $ret
