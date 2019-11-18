# Info
Project consists of the:
1. APT repository located on Amzoan s3 bucket - travis-ci-deb.s3.us-east-2.amazonaws.com.
Repository handle multi codename versions at main software.
2. Deb package builder for that repository

**DIR_DEB_PACKAGES**=~/deb/ # directory synchronized via s3 bucker between deb package and apt repo, don't change if you don't have to
**DEB_PACKAGE_NAME**=redis  # name of active builder, equal to redis or NEW_BUILDER_NAME in this doc examples
**REDIS_VERSION**=5.0.6     # version of package to build
**REDIS_DEBIAN_VERSION**    # version od debian-like system package, example: xenial, xenial1

#Adding new builder
- Create new appropriate builder
Create new builder in **dir deb-builders/[NEW_BUILDER_NAME]/build-deb-[NEW_BUILDER_NAME].sh**
Example: `deb-builders/redis/build-deb-redis.sh`
Each builder should be able to handle this input variables:
  - **[NEW_BUILDER_NAME]_VERSION**
  - **[NEW_BUILDER_NAME]_DEBIAN_VERSION**
  - **DIR_DEB_PACKAGES** - builded debs should be placed in DIR_DEB_PACKAGES/vesion_codename, example DIR_DEB_PACKAGES/xenial

# Adding new vesion_codename in APT repository

If you want to define new apt version codename, pls edit variable **APT_REPO_CODENAMES**, defined in update-apt-repo.sh.
Builders also must place deb into new version_codename subfolder (DIR_DEB_PACKAGES/vesion_codename).

# Communication flow

Travis call build deb [DEB_PACKAGE_NAME=redis] **-->** build_router.sh **-->** build-deb-redis.sh [save builded deb to DIR_DEB_PACKAGES] **-->** send deb to s3 deb-builds-tmp dir

Travis call build APT repo [DEB_PACKAGE_NAME=redis] **-->** update-apt-repo.sh [get deb from s3 deb-builds-tmp dir, build repo, send repo to s3]

Please see .travis.yml for more details.


# Configure Apt repo for usage
Example for redis-server and xenial codename

    echo 'deb http://travis-ci-deb.s3.us-east-2.amazonaws.com xenial main' > /etc/apt/sources.list.d/travis-packages.list;
    echo -e "Package: redis-server\nPin: release o=travis-ci-deb.s3.us-east-2.amazonaws.com\nPin-Priority: 900" > /etc/apt/preferences.d/redis
    wget -qO - https://travis-ci-deb.s3.us-east-2.amazonaws.com/pub-key.gpg | apt-key add -"
