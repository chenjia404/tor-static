# tor-static [![Build Status](https://travis-ci.org/cretz/tor-static.svg?branch=master)](https://travis-ci.org/cretz/tor-static) [![Build status](https://ci.appveyor.com/api/projects/status/su4pkdrmlki6jd7n?svg=true)](https://ci.appveyor.com/project/cretz/tor-static)

This project helps compile Tor into a static lib for use in other projects.

The dependencies are in this repository as submodules so this repository needs to be cloned with `--recursive`. The
submodules are:

- [OpenSSL](https://github.com/openssl/openssl/) - Checked out at tag `OpenSSL_1_1_1w`
- [Libevent](https://github.com/libevent/libevent) - Checked out at tag `release-2.1.12-stable`
- [zlib](https://github.com/madler/zlib) - Checked out at tag `v1.3.1`
- [XZ Utils](https://git.tukaani.org/?p=xz.git) - Checked out at tag `v5.6.2`
- [Tor](https://github.com/torproject/tor) - Checked out at tag `tor-0.4.8.23`

Many many bugs and quirks were hit while deriving these steps. Also many other repos, mailing lists, etc were leveraged
to get some of the pieces right. They are not listed here for brevity reasons.

**Note: Other versions of Tor may be available via tags (for current or previous versions) and branches (for future
versions)**

## Building

### Prerequisites

All platforms need Go installed and on the PATH.

#### Linux

Need:

- Normal build tools (e.g. `sudo apt-get install build-essential`)
- Libtool (e.g. `sudo apt-get install libtool`)
- autopoint (e.g. `sudo apt-get install autopoint`)
- po4a (e.g. `sudo apt-get install po4a`)

#### macOS

Need:

- Normal build tools (e.g. Xcode command line tools)
- go (e.g. `brew install go`)
- Libtool (e.g. `brew install libtool`)
- Autoconf and Automake (e.g. `brew install automake`)
- autopoint (can be found in gettext, e.g. `brew install gettext`)
  - Note, by default this is assumed to be at `/usr/local/opt/gettext/bin`. Use `-autopoint-path` to change it.
- po4a (e.g. `brew install po4a`)

#### Windows

Tor is not really designed to work well with MSVC so we use MinGW instead. In order to compile the dependencies,
Msys2 + MinGW should be installed.

Download and install the latest [MSYS2 64-bit](http://www.msys2.org/) that uses the `MinGW-w64` toolchains. Once
installed, open the "MSYS MinGW 64-bit" shell link that was created. Once in the shell, run:

    pacman -Syuu

Terminate and restart the shell if asked. Rerun this command as many times as needed until it reports that everything is
up to date. Then in the same mingw-64 shell, run:

    pacman -Sy --needed base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain \
                        git subversion mercurial libtool gettext-devel po4a automake autoconf automake-wrapper \
                        mingw-w64-i686-cmake mingw-w64-x86_64-cmake

This will install all the tools needed for building and will take a while. Once complete, MinGW is now setup to build
the dependencies.

### Executing the build

In the cloned directory, run:

    go run build.go build-all

This will take a long time. Pieces can be built individually by changing the command from `build-all` to
`build-<folder>`. To clean, run either `clean-all` or `clean-<folder>`. To see the output of all the commands as they
are being run, add `-verbose` before the command.

### Building with Docker

Docker support is aimed at Linux builds. The container runs the native Linux toolchain for the target architecture, so
it is a good fit for `linux/amd64` and `linux/arm64`.

Before using Docker, make sure the repository has been cloned with recursive submodules:

    git submodule update --init --recursive

Build Linux amd64:

    docker buildx build --platform linux/amd64 --target artifact --output type=local,dest=./dist/linux/amd64 .

Build Linux arm64:

    docker buildx build --platform linux/arm64 --target artifact --output type=local,dest=./dist/linux/arm64 .

Each output directory will contain:

- `tor-static-linux-<arch>.tar.gz`
- `tor-static-linux-<arch>.zip`
- `show-libs.txt`

### Building with docker-compose

`docker-compose` is provided as a convenient local wrapper around the Linux build container. It does not replace native
macOS or Windows builds, but it makes repeatable Linux builds easier.

Build Linux amd64:

    docker compose run --rm linux-amd64

Build Linux arm64:

    docker compose run --rm linux-arm64

Artifacts are written to `./dist/linux/<arch>`.

### Building Windows artifacts with Docker on a Windows host

This repository can also build the Windows static package inside a Windows container. This requires a Windows host that
can run Windows containers.

Requirements:

- Docker Desktop in Windows container mode
- Windows 10/11 Pro or Enterprise
- A repository checkout with recursive submodules

Build the Windows toolchain image:

    docker build -f Dockerfile.windows -t tor-static-windows-builder .

Run the Windows build:

    docker run --rm `
      -v ${PWD}:C:\src:ro `
      -v ${PWD}\dist\windows:C:\out `
      tor-static-windows-builder

Artifacts are written to `.\dist\windows`:

- `tor-static-windows-amd64.zip`
- `tor-static-windows-amd64.tar.gz`
- `show-libs.txt`

### GitHub Actions

A GitHub Actions workflow is included for CI builds across:

- Linux amd64 via Docker
- Linux arm64 via Docker + QEMU
- macOS amd64 via native GitHub-hosted runner
- macOS arm64 via native GitHub-hosted runner
- Windows amd64 via MSYS2/MinGW

The workflow uploads per-platform artifacts for every build. When a tag matching `v*` is pushed, it also creates or
updates the matching GitHub Release and uploads the packaged artifacts.

## Using

Once the libs have been compiled, they can be used to link with your program. Due to recent refactorings within the Tor
source, the libraries are not listed here but instead listed when executing:

    go run build.go show-libs

This lists directories (relative, prefixed with `-L`) followed by lib names (file sans `lib` prefix and sans `.a`
extension, prefixed with `-l`) as might be used in `ld`.

The OS-specific system libs that have to be referenced (i.e. `-l<libname>`) are:

- Linux/macOS - `m`
- Windows (MinGW) - `ws2_32`, `crypt32`, `gdi32`, `iphlpapi`, and `shlwapi`

The OS-specific system libs that have to be explicitly statically linked (i.e. `-Wl,-Bstatic -l<libname>`) are:

- Windows (MinGW) - `pthread`
