#!/usr/bin/env bash
set -o errexit

if [ -z $DEB_PACKAGE_NAME ];then
  echo "No DEB_PACKAGE_NAME env provided, pls provide with value like:[all|redis|...] "
  exit 1
fi

BUILDER_SCRIPT="deb-builders/${DEB_PACKAGE_NAME}/build-deb-${DEB_PACKAGE_NAME}.sh"
if [ ! -f $BUILDER_SCRIPT ];then
  echo "Building deb script for ${DEB_PACKAGE_NAME} should be at ${BUILDER_SCRIPT}, not seeing it there, sorry.."
  exit 1
fi

echo "Executing ${BUILDER_SCRIPT}"
exec $BUILDER_SCRIPT
