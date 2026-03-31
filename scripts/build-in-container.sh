#!/usr/bin/env bash
set -euo pipefail

target_os="${TARGETOS:-linux}"
target_arch="${TARGETARCH:?TARGETARCH is required}"
source_dir="${SOURCE_DIR:-/src}"
work_dir="${WORK_DIR:-/tmp/tor-static}"
output_dir="${OUTPUT_DIR:-/out/${target_os}/${target_arch}}"

# Build in a disposable work tree so the host checkout stays clean.
rm -rf "${work_dir}"
mkdir -p "${work_dir}" "${output_dir}"
cp -a "${source_dir}/." "${work_dir}/"

cd "${work_dir}"

# A recursive checkout is mandatory because the real source code lives in git submodules.
test -f openssl/Configure
test -f libevent/autogen.sh
test -f tor/configure.ac
test -f xz/configure.ac
test -f zlib/configure

go run build.go -verbose build-all
go run build.go package-libs
go run build.go show-libs > "${output_dir}/show-libs.txt"

cp libs.tar.gz "${output_dir}/tor-static-${target_os}-${target_arch}.tar.gz"
cp libs.zip "${output_dir}/tor-static-${target_os}-${target_arch}.zip"
