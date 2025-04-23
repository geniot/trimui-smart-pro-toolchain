# Golang/Rust Trimui Smart Pro Toolchain Docker Image

Initially based on the [anibaldeboni TSP Toolchain](https://github.com/anibaldeboni/trimui-smart-pro-toolchain).

The toolchain and sysroot files used here are
originally [here](https://github.com/trimui/toolchain_sdk_smartpro/releases/tag/20231018).

The image supports cross-compilation of `arm64` binaries on `amd64` systems. It works on WSL. The image includes:

- Official Trimui SDK
- Recommended linaro aarch64 gcc compiler
- SDL2 version provided by Trimui
- Golang 1.24 support and related configurations
- Latest Stable Rust

## Installation

```bash
$ docker build -f Dockerfile -t trimui-sdk .
```

## Example Workflow

- On your host machine keep your TSP projects in `/opt/TrimuiProjects` and make changes as usual.
- Start a container based on the image:

```bash
docker run -d --name trimui-sdk -it --volume=/opt/TrimuiProjects/:/work/ --workdir=/work/ trimui-sdk
```

This makes your TSP projects visible to the container.
You can log in into the container and check Go, Rust versions and visibility of your /opt/TrimuiProjects folder.

- Create a Makefile in your project. A Go example:

```makefile
PROJECT_NAME := tsp-hardware-test
PROGRAM_NAME := hwt
DEPLOY_PATH := /mnt/SDCARD/Apps/HardwareTest

IP := 192.168.0.102
USN := root
PWD := tina

all: clean docker deploy

clean:
	rm bin/${PROGRAM_NAME} -f

docker:
	docker exec trimui-sdk /bin/bash -c 'cd ${PROJECT_NAME} && make build'

build:
	go build -tags="sdl es2" -o bin/${PROGRAM_NAME} ${PROJECT_NAME}/src/

deploy:
	sshpass -p ${PWD} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USN}@${IP} "rm ${DEPLOY_PATH}/${PROGRAM_NAME} -f"
	sshpass -p ${PWD} scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null bin/${PROGRAM_NAME} ${USN}@${IP}:${DEPLOY_PATH}
	sshpass -p ${PWD} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USN}@${IP} "chmod 777 ${DEPLOY_PATH}/${PROGRAM_NAME}"
	sshpass -p ${PWD} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USN}@${IP} "if pgrep ${PROGRAM_NAME}; then pkill -f ${PROGRAM_NAME}; fi"
	sshpass -p ${PWD} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USN}@${IP} "sh -c 'cd /tmp; ${DEPLOY_PATH}/${PROGRAM_NAME}'" &
```
The tags here `sdl es2` are used for a project based on RayLib. See https://github.com/gen2brain/raylib-go

A Rust project would be very similar except the build part:
```makefile
	rustup target add aarch64-unknown-linux-gnu
	CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="aarch64-linux-gnu-g++" \
		CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUSTFLAGS="-C link-arg=--sysroot=${SYSROOT}" \
		cargo build --target=aarch64-unknown-linux-gnu --target-dir bin --bin ${PROJECT_NAME}
```

Deployment with such make also restarts the app on TSP.  

## TSP MainUI

Using this approach, you will get your application running and fighting at the same time for the screen with the MainUI
which cannot be stopped
easily.

If you know how to stop/start MainUI from the command line, let me know through a ticket here on GitHub.

So for testing I created a Dummy App https://github.com/geniot/tsp-dummy-banner that draws on the screen only once when
started,
and then it just waits for the exit button combination (Menu+Start).

I start this Dummy App from the MainUI, and now MainUI is not drawing because it thinks there is an app running.
Because MainUI has forked this Dummy App process.

I can now run `make` on my project. When deployed, my project app is not fighting for the screen with the Dummy
App or MainUI because Dummy App draws on the screen only once and MainUI still thinks there is an app running.

To exit both the project app and the Dummy App I use the same Menu+Start combo. They both poll for button events.

I'm back to the MainUI!

## Docker for Mac

This image is still not running properly on Mac (M1) the SDL2 build process fail.

## Using with GitHub Actions

Here's an example of how to integrate this image on a GitHub release
workflow: [https://github.com/anibaldeboni/screech/blob/master/.github/workflows/release.yml](https://github.com/anibaldeboni/screech/blob/master/.github/workflows/release.yml)
