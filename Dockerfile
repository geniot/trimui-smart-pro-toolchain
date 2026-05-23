FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# Set timezone
ENV TZ=America/Sao_Paulo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install dependencies and update CA certificates
RUN dpkg --add-architecture arm64 && \
    apt-get update && apt-get install -y --no-install-recommends \
        wget \
        curl \
        build-essential \
        cmake \
        cmake-curses-gui \
        libclang-dev \
        ca-certificates \
        linux-libc-dev-arm64-cross \
        libc6-arm64-cross \
        libc6-dev-arm64-cross \
        binutils-aarch64-linux-gnu \
        libsdl2-gfx-dev:arm64 \
        libsdl2-image-dev:arm64 \
        libsdl2-mixer-dev:arm64 \
        libsdl2-net-dev:arm64 \
        libsdl2-ttf-dev:arm64 \
        libegl1-mesa-dev \
        libgles2-mesa-dev \
        pkg-config \
        zip \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update

# Install Go 1.24.2
COPY downloads/go1.24.2.linux-arm64.tar.gz .
#RUN wget https://go.dev/dl/go1.24.2.linux-arm64.tar.gz && \
RUN tar -C /usr/local -xzf go1.24.2.linux-arm64.tar.gz && \
    rm go1.24.2.linux-arm64.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
# Check cargo is visible
RUN cargo --help
RUN rustup target add aarch64-unknown-linux-gnu

# Download and install Linaro toolchain
COPY downloads/aarch64-linux-gnu-7.5.0-linaro.tgz .
#RUN wget https://github.com/trimui/toolchain_sdk_smartpro/releases/download/20231018/aarch64-linux-gnu-7.5.0-linaro.tgz && \
RUN tar -C /usr/local -xzf aarch64-linux-gnu-7.5.0-linaro.tgz && \
    rm aarch64-linux-gnu-7.5.0-linaro.tgz

# Download and install additional libc files
COPY downloads/SDK_usr_tg5040_a133p.tgz .
#RUN wget https://github.com/trimui/toolchain_sdk_smartpro/releases/download/20231018/SDK_usr_tg5040_a133p.tgz && \
RUN tar -xzf SDK_usr_tg5040_a133p.tgz -C /tmp && \
    mkdir -p /usr/local/aarch64-linux-gnu-7.5.0-linaro/sysroot/usr && \
    cp -r /usr/local/aarch64-linux-gnu-7.5.0-linaro/aarch64-linux-gnu/libc/* /usr/local/aarch64-linux-gnu-7.5.0-linaro/sysroot && \
    cp -r /tmp/usr/* /usr/local/aarch64-linux-gnu-7.5.0-linaro/sysroot/usr/ && \
    rm -rf SDK_usr_tg5040_a133p.tgz /tmp/usr

ENV PATH="/usr/local/aarch64-linux-gnu-7.5.0-linaro/bin:${PATH}"
ENV SYSROOT="/usr/local/aarch64-linux-gnu-7.5.0-linaro/sysroot"
ENV CC="/usr/local/aarch64-linux-gnu-7.5.0-linaro/bin/aarch64-linux-gnu-gcc --sysroot=${SYSROOT} -I${SYSROOT}/usr/include"

COPY lib/* ${SYSROOT}/lib

# Download and build SDL2
COPY downloads/SDL2-2.26.1.GE8300.tgz .
#RUN wget https://github.com/trimui/toolchain_sdk_smartpro/releases/download/20231018/SDL2-2.26.1.GE8300.tgz && \
RUN tar -xzf SDL2-2.26.1.GE8300.tgz -C /tmp && \
    cd /tmp/SDL2-2.26.1 && \
    ./configure --host=aarch64-linux-gnu \
                --prefix=/usr \
                --disable-video-wayland \
                --disable-pulseaudio \
                --with-sysroot=${SYSROOT} && \
    make && \
    make install && \
    rm -rf /tmp/SDL2-2.26.1 SDL2-2.26.1.GE8300.tgz

# Set PKG_CONFIG_PATH to include SDL2 directories
ENV PKG_CONFIG_PATH="/usr/aarch64-linux-gnu/lib/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig:${SYSROOT}/usr/lib/pkgconfig"

# Set environment variables for cross-compilation
ENV CC="aarch64-linux-gnu-gcc --sysroot=${SYSROOT}"
ENV CXX="aarch64-linux-gnu-g++ --sysroot=${SYSROOT}"
ENV LD="aarch64-linux-gnu-ld --sysroot=${SYSROOT}"
ENV AR="aarch64-linux-gnu-ar"
ENV AS="aarch64-linux-gnu-as"
ENV RANLIB="aarch64-linux-gnu-ranlib"
ENV STRIP="aarch64-linux-gnu-strip"
ENV GOOS="linux"
ENV GOARCH="arm64"
ENV CGO_ENABLED="1"
ENV CGO_LDFLAGS="-L${SYSROOT}/usr/lib  -L/usr/lib/aarch64-linux-gnu -lSDL2_image -lSDL2_ttf -lSDL2 -ldl -lpthread -lm"
ENV CGO_CFLAGS="-I${SYSROOT}/usr/include -I/usr/aarch64-linux-gnu/include -I/usr/aarch64-linux-gnu/include/SDL2 -I/usr/include/SDL2 -I/usr/include -D_REENTRANT"
ENV CXXFLAGS="-I${SYSROOT}/usr/include -I/usr/aarch64-linux-gnu/include -I/usr/aarch64-linux-gnu/include/SDL2 -I/usr/include/SDL2 -I/usr/include -D_REENTRANT"
ENV CFLAGS="-I${SYSROOT}/usr/include -I/usr/aarch64-linux-gnu/include -I/usr/aarch64-linux-gnu/include/SDL2 -I/usr/include/SDL2 -I/usr/include -D_REENTRANT"

ENTRYPOINT ["/bin/bash"]
