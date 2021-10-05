#!/usr/bin/env bash

# WARNING: DO NOT EDIT!
#
# This file was generated by plugin_template, and is managed by it. Please use
# './plugin-template --github galaxy_ng' to update this file.
#
# For more info visit https://github.com/pulp/plugin_template

# make sure this script runs at the repo root
cd "$(dirname "$(realpath -e "$0")")"/../../..
REPO_ROOT="$PWD"

set -euv

source .github/workflows/scripts/utils.sh

if [[ "$TEST" = "docs" || "$TEST" = "publish" ]]; then
  pip install -r ../pulpcore/doc_requirements.txt
  pip install -r doc_requirements.txt
fi

pip install -r functest_requirements.txt

cd .ci/ansible/

TAG=ci_build

if [ -e $REPO_ROOT/../pulp_ansible ]; then
  PULP_ANSIBLE=./pulp_ansible
else
  PULP_ANSIBLE=git+https://github.com/pulp/pulp_ansible.git@0.9.2
fi

if [ -e $REPO_ROOT/../pulp_container ]; then
  PULP_CONTAINER=./pulp_container
else
  PULP_CONTAINER=git+https://github.com/pulp/pulp_container.git@2.7.1
fi

if [ -e $REPO_ROOT/../galaxy-importer ]; then
  GALAXY_IMPORTER=./galaxy-importer
else
  GALAXY_IMPORTER=git+https://github.com/ansible/galaxy-importer.git@v0.3.4
fi
if [[ "$TEST" == "plugin-from-pypi" ]]; then
  PLUGIN_NAME=galaxy_ng
elif [[ "${RELEASE_WORKFLOW:-false}" == "true" ]]; then
  PLUGIN_NAME=./galaxy_ng/dist/galaxy_ng-$PLUGIN_VERSION-py3-none-any.whl
else
  PLUGIN_NAME=./galaxy_ng
fi
if [[ "${RELEASE_WORKFLOW:-false}" == "true" ]]; then
  # Install the plugin only and use published PyPI packages for the rest
  # Quoting ${TAG} ensures Ansible casts the tag as a string.
  cat >> vars/main.yaml << VARSYAML
image:
  name: pulp
  tag: "${TAG}"
plugins:
  - name: pulpcore
    source: pulpcore
  - name: galaxy_ng
    source:  "${PLUGIN_NAME}"
  - name: pulp_ansible
    source: pulp_ansible
  - name: pulp_container
    source: pulp_container
  - name: galaxy-importer
    source: galaxy-importer
services:
  - name: pulp
    image: "pulp:${TAG}"
    volumes:
      - ./settings:/etc/pulp
VARSYAML
else
  cat >> vars/main.yaml << VARSYAML
image:
  name: pulp
  tag: "${TAG}"
plugins:
  - name: galaxy_ng
    source: "${PLUGIN_NAME}"
  - name: pulp_ansible
    source: $PULP_ANSIBLE
  - name: pulp_container
    source: $PULP_CONTAINER
  - name: galaxy-importer
    source: $GALAXY_IMPORTER
  - name: pulpcore
    source: ./pulpcore
services:
  - name: pulp
    image: "pulp:${TAG}"
    volumes:
      - ./settings:/etc/pulp
VARSYAML
fi

cat >> vars/main.yaml << VARSYAML
pulp_settings: {"allowed_export_paths": "/tmp", "allowed_import_paths": "/tmp", "rh_entitlement_required": "insights"}
pulp_scheme: http

pulp_container_tag: latest

VARSYAML

if [ "$TEST" = "s3" ]; then
  export MINIO_ACCESS_KEY=AKIAIT2Z5TDYPX3ARJBA
  export MINIO_SECRET_KEY=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
  sed -i -e '/^services:/a \
  - name: minio\
    image: minio/minio\
    env:\
      MINIO_ACCESS_KEY: "'$MINIO_ACCESS_KEY'"\
      MINIO_SECRET_KEY: "'$MINIO_SECRET_KEY'"\
    command: "server /data"' vars/main.yaml
  sed -i -e '$a s3_test: true\
minio_access_key: "'$MINIO_ACCESS_KEY'"\
minio_secret_key: "'$MINIO_SECRET_KEY'"' vars/main.yaml
fi

ansible-playbook build_container.yaml
ansible-playbook start_container.yaml

echo ::group::PIP_LIST
cmd_prefix bash -c "pip3 list && pip3 install pipdeptree && pipdeptree"
echo ::endgroup::
