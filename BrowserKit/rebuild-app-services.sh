#!/usr/bin/env bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Uses a local version of application services xcframework

# This script allows switches the usage of application services to a local xcframework
# built from a local checkout of application services

set -e

# CMDNAME is used in the usage text below
CMDNAME=$(basename "$0")
USAGE=$(cat <<EOT
${CMDNAME}
Tarik Eshaq <teshaq@mozilla.com>

Rebuilds application services from the submodule

This script allows switches the usage of application services to a local xcframework
built from a local checkout of application services


USAGE:
    ${CMDNAME} [OPTIONS] <LOCAL_APP_SERVICES_PATH>

OPTIONS:
    -d, --disable           Disables local development on application services
    -h, --help              Display this help message.
EOT
)

msg () {
  printf "\033[0;34m> %s\033[0m\n" "${1}"
}

helptext() {
    echo "$USAGE"
}



THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SWIFT_SOURCE="$THIS_DIR/swift-source"
FRAMEWORK_PATH="$THIS_DIR/bin/MozillaRustComponents.xcframework"

APP_SERVICES_DIR="$THIS_DIR/application-services"
while (( "$#" )); do
    case "$1" in
        -h|--help)
            helptext
            exit 0
            ;;
        --) # end argument parsing
            shift
            break
            ;;
        --*=|-*) # unsupported flags
            echo "Error: Unsupported flag $1" >&2
            exit 1
            ;;
        *) # preserve positional arguments
            APP_SERVICES_DIR=$1
            shift
            ;;
    esac
done

if [ -z $APP_SERVICES_DIR ]; then
    msg "Please set the application-services path."
    msg "This is a path to a local checkout of the application services repository"
    msg "You can find the repository on $APP_SERVICES_REMOTE"
    exit 1
fi

## First we build the xcframework in the application services repository
msg "Building the xcframework in $APP_SERVICES_DIR"
msg "This might take a few minutes"
pushd $APP_SERVICES_DIR/megazords/ios-rust/
./build-xcframework.sh
popd

## Once built, we want to move the frameowork to this repository, then unzip it
rsync -a --delete $APP_SERVICES_DIR/megazords/ios-rust/MozillaRustComponents.xcframework/ $FRAMEWORK_PATH


## We should also get the swift-source code copied and staged as well
msg "Generating swift source code..."
./app-services-update.sh


msg "Done building application-services"
