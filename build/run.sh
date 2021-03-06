#!/bin/sh

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Author: Mathieu Parent <math.parent@gmail.com>

set -e

hindsight_dir="$PWD"
lsb_dir="$(dirname "$hindsight_dir")/lua_sandbox"

if [ ! -d "$lsb_dir" ]; then
    (   set -x;
        git clone https://github.com/mozilla-services/lua_sandbox "$lsb_dir"
        git rev-parse HEAD
    )
fi

. "$lsb_dir/build/functions.sh"

if [ "$1" != "build" -o $# -ge 2 ]; then
    usage
    exit 1
fi

build_lua_sandbox_extensions() {
    local packages
    local cmake_args
    local ext
    packages="git c++-compiler"
    cmake_args=""
    # todo add support for aws geoip jose kafka openssl parquet snappy systemd
    for ext in bloom_filter circular_buffer cjson compat cuckoo_filter \
            elasticsearch heka hyperloglog lfs lpeg lsb moz_ingest moz_pioneer \
            moz_security moz_telemetry postgres rjson sax socket ssl struct \
            syslog zlib; do
        case "$ext" in
            postgres)
                if [ "$CPACK_GENERATOR" = "DEB" ]; then
                    packages="$packages libpq-dev postgresql-server-dev-all"
                elif [ "$CPACK_GENERATOR" = "RPM" ]; then
                    packages="$packages postgresql-devel"
                else
                    cmake_args="$cmake_args -DEXT_$ext=false"
                fi
                ;;
            ssl)
                if [ "$CPACK_GENERATOR" = "DEB" ]; then
                    packages="$packages libssl-dev"
                elif [ "$CPACK_GENERATOR" = "RPM" ]; then
                    packages="$packages openssl-devel"
                else
                    cmake_args="$cmake_args -DEXT_$ext=false"
                fi
                ;;
            zlib)
                if [ "$CPACK_GENERATOR" = "DEB" ]; then
                    packages="$packages zlib1g-dev"
                elif [ "$CPACK_GENERATOR" = "RPM" ]; then
                    packages="$packages zlib-devel"
                else
                    cmake_args="$cmake_args -DEXT_$ext=false"
                fi
                ;;
            *)
                cmake_args="$cmake_args -DEXT_$ext=true";
                ;;
        esac
    done

    install_packages $packages
    (   set -x

        rm -rf ./release
        # From README.md:
        mkdir release
        cd release

        cmake -DCMAKE_BUILD_TYPE=release $cmake_args \
            "-DCPACK_GENERATOR=${CPACK_GENERATOR}" ..
        make

        ctest -V
        make packages
    )
}

build_function="build_lua_sandbox_extensions"
main
