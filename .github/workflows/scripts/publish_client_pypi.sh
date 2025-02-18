#!/bin/bash

# WARNING: DO NOT EDIT!
#
# This file was generated by plugin_template, and is managed by it. Please use
# './plugin-template --github galaxy_ng' to update this file.
#
# For more info visit https://github.com/pulp/plugin_template

set -euv

# make sure this script runs at the repo root
cd "$(dirname "$(realpath -e "$0")")"/../../..

pip install twine

export VERSION=$(ls dist | sed -rn 's/galaxy_ng-client-(.*)\.tar.gz/\1/p')

if [[ -z "$VERSION" ]]; then
  echo "No client package found."
  exit
fi

export response=$(curl --write-out %{http_code} --silent --output /dev/null https://pypi.org/project/galaxy-ng-client/$VERSION/)

if [ "$response" == "200" ];
then
  echo "galaxy_ng client $VERSION has already been released. Skipping."
  exit
fi

twine check dist/galaxy_ng_client-$VERSION-py3-none-any.whl || exit 1
twine check dist/galaxy_ng-client-$VERSION.tar.gz || exit 1
twine upload dist/galaxy_ng_client-$VERSION-py3-none-any.whl -u pulp -p $PYPI_PASSWORD
twine upload dist/galaxy_ng-client-$VERSION.tar.gz -u pulp -p $PYPI_PASSWORD

exit $?
