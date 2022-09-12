#!/bin/bash

shopt -s expand_aliases

if [[ "" = "$DOCFX_EXE" ]]; then
    shopt -s expand_aliases
    if [[ -f "~/.bash_aliases" ]]; then
    	source "${HOME}/.bash_aliases"
	fi
else
    alias docfx="mono $DOCFX_EXE"
fi

commands_to_test=(doxygen mono docfx jq)

# verify all the commands required in the automation exist before trying to run the full suite
for cmd in "${commands_to_test[@]}"
do
    # checking all commands are on the path before continuing...
    result="$(type ${cmd} &>/dev/null && echo "Found" || echo "Not Found")"

    if [ "Not Found" = "${result}" ]; then
        missing_requirements="${missing_requirements}    * ${cmd}\n"
    fi
done

# are requirements ? if yes, stop here and help 'em out
if ! [[ "" = "${missing_requirements}" ]]; then
    echo " "
    echo "The commands listed below are required to be on the path for this script to function properly."
    echo "Please ensure the commands listed are on the path and then try again."
    printf "\n${missing_requirements}"
    echo " "
    echo "If any of these commands are declared as aliases (docfx is a common one) ensure your alias is"
    echo "declared inside of ~/.bash_aliases - or modify this script to add the aliases you require"
    exit 1
fi

set -e

script_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "$script_root"

SKIP_GIT=""
SKIP_LINKED_DOC=""
SKIP_CLEAN=""
WARNINGS_AS_ERRORS=""
ZITI_DOC_GIT_LOC="docfx_project"

echo "- processing opts"

while getopts ":gwlcdf" opt; do
  case ${opt} in
    g ) # skip git
      echo "- skipping git cleanup"
      SKIP_GIT="yes"
      ;;
    l ) # skip linked doc gen
      echo "- skipping linked doc generation"
      SKIP_LINKED_DOC="yes"
      ;;
    c ) # skip clean steps
      echo "- skipping clean step"
      SKIP_CLEAN="yes"
      ;;
    w ) # process option t
      echo "- treating warnings as errors"
      WARNINGS_AS_ERRORS="--warningsAsErrors"
      ;;
    d ) # docusaurus
      echo "- building docusaurs"
      ZITI_DOCUSAURS="true"
      ZITI_DOC_GIT_LOC="${script_root}/docusaurus/OpenZiti/remotes"
      echo "- building docusaurs to ${ZITI_DOC_GIT_LOC}"
      ;;
    f ) # docfx
    #\? ) echo "Usage: cmd [-h] [-t]"
      echo "this would have been docfx"
      ;;
    *)
      ;;
  esac
done

echo "- done processing opts"

if [[ ! "${SKIP_GIT}" == "yes" ]]; then
  echo "updating dependencies by rm/checkout"
  mkdir -p "${ZITI_DOC_GIT_LOC}"
  rm -rf ${ZITI_DOC_GIT_LOC}/ziti-*
  git clone https://github.com/openziti/ziti --branch release-next --single-branch ${ZITI_DOC_GIT_LOC}/ziti-cmd
  git clone https://github.com/openziti/ziti-sdk-csharp --branch main --single-branch ${ZITI_DOC_GIT_LOC}/ziti-sdk-csharp
  git clone https://github.com/openziti/ziti-sdk-c --branch main --single-branch ${ZITI_DOC_GIT_LOC}/ziti-sdk-c
  git clone https://github.com/openziti/ziti-android-app --branch main --single-branch ${ZITI_DOC_GIT_LOC}/ziti-android-app
  git clone https://github.com/openziti/ziti-sdk-swift --branch main --single-branch ${ZITI_DOC_GIT_LOC}/ziti-sdk-swift
fi

DOC_ROOT=docs-local

if [[ ! "${SKIP_CLEAN}" == "yes" ]]; then
if test -d "./$DOC_ROOT"; then
  # specifically using ../ziti-doc just to remove any chance to rm something unintended
  echo removing previous build at: rm -r ./$DOC_ROOT
  rm -r ./$DOC_ROOT || true
fi
fi

pushd ${ZITI_DOC_GIT_LOC}
if [[ ! "${ZITI_DOCUSAURS}" == "true" ]]; then
  docfx build ${WARNINGS_AS_ERRORS}
else
  echo "running yarn install"
  yarn install
  echo "running npm run build"
  npm run build
fi
popd
exit
if [[ ! "${SKIP_LINKED_DOC}" == "yes" ]]; then
if test -f "${script_root}/${ZITI_DOC_GIT_LOC}/ziti-sdk-c/Doxyfile"; then
    pushd "${script_root}"/${ZITI_DOC_GIT_LOC}/ziti-sdk-c
    doxygen
    CLANG_SOURCE="${script_root}/${ZITI_DOC_GIT_LOC}/ziti-sdk-c/api"
    CLANG_TARGET="${script_root}/${DOC_ROOT}/api/clang"
    echo " "
    echo "Copying C SDK "
    echo "    from: ${CLANG_SOURCE}"
    echo "      to: ${CLANG_TARGET}"
    mkdir -p "${CLANG_TARGET}"
    cp -r "${script_root}"/${ZITI_DOC_GIT_LOC}/ziti-sdk-c/api "${CLANG_TARGET}"

    echo " "
    echo "Removing"
    echo "    ${script_root}/${ZITI_DOC_GIT_LOC}/ziti-sdk-c/api"
    rm -rf "${script_root}"/${ZITI_DOC_GIT_LOC}/ziti-sdk-c/api
    popd
else
    echo "ERROR: CSDK Doxyfile not located"
fi

if test -f "${script_root}/${ZITI_DOC_GIT_LOC}/ziti-sdk-swift/CZiti.xcodeproj/project.pbxproj"; then
    SWIFT_API_TARGET="./${DOC_ROOT}/api/swift"
    mkdir -p "./${SWIFT_API_TARGET}"
    pushd ${SWIFT_API_TARGET}
    swift_tgz=$(curl -s https://api.github.com/repos/openziti/ziti-sdk-swift/releases/latest | jq -r '.assets[] | select (.name=="ziti-sdk-swift-docs.tgz") | .browser_download_url')
    echo " "
    echo "Copying Swift docs"
    echo "    from: ${swift_tgz}"
    echo "      to: ${script_root}/${SWIFT_API_TARGET}"
    #echo "     via: wget -q -O - ${swift_tgz} | tar -zxvC ${SWIFT_API_TARGET}"
    echo "     via: wget -q -O - ${swift_tgz} | tar -zxv"
    pwd
    #wget -q -O - "${swift_tgz}" | tar -zxvC "${SWIFT_API_TARGET}"
    wget -q -O - "${swift_tgz}" | tar -zxv
    find "${script_root}/${SWIFT_API_TARGET}" -name "EnrollmentResponse*"
    popd
fi
fi
