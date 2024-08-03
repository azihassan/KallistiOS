FROM alpine:3.20
RUN apk --update add build-base patch bash texinfo gmp-dev libjpeg-turbo-dev libpng-dev elfutils-dev curl wget python3 git ruby-rake cmake sdl12-compat-dev sdl12-compat

RUN echo Creating a space for your toolchain installation...
RUN mkdir -p /opt/toolchains/dc
RUN chmod -R 755 /opt/toolchains/dc
RUN chown -R $(id -u):$(id -g) /opt/toolchains/dc

RUN echo Cloning the KOS git repository...
RUN git clone https://github.com/KallistiOS/KallistiOS /opt/toolchains/dc/kos

RUN echo Configuring the dc-chain script...
WORKDIR /opt/toolchains/dc/kos/utils/dc-chain

RUN echo "Downloading and compiling the toolchain..."
RUN make build-sh4
RUN make clean

RUN echo "Setting up the environment settings and building KOS..."
WORKDIR /opt/toolchains/dc/kos
RUN cp doc/environ.sh.sample environ.sh 
RUN source /opt/toolchains/dc/kos/environ.sh && make

RUN echo "Compiling kos-ports..."
WORKDIR /opt/toolchains/dc/
RUN git clone https://github.com/KallistiOS/kos-ports
# libjmctl fails to build
RUN source /opt/toolchains/dc/kos/environ.sh && /opt/toolchains/dc/kos-ports/utils/build-all.sh || echo 'Something failed in kos-ports, skipping'

RUN echo "Compiling mkdcdisc to generate .cdi files..."
RUN git clone https://gitlab.com/simulant/mkdcdisc.git
RUN apk add ninja-build meson libisofs-dev
RUN cd mkdcdisc && \
    meson setup builddir && \
    meson compile -C builddir && \
    echo 'export PATH="${PATH}:/opt/toolchains/dc/mkdcdisc/builddir"' >> /opt/toolchains/dc/kos/environ.sh && \
    source /opt/toolchains/dc/kos/environ.sh && \
    mkdcdisc -h || true

RUN echo "Removing lua C++ support to prevent missing LuaEvent error"
COPY lua.patch /opt/toolchains/dc/kos-ports
RUN patch kos-ports/lua/Makefile -l -p0 < kos-ports/lua.patch
RUN source /opt/toolchains/dc/kos/environ.sh && cd /opt/toolchains/dc/kos-ports/lua && make uninstall install clean

ENTRYPOINT ["sh", "-c", "source /opt/toolchains/dc/kos/environ.sh && \"$@\"", "-s"]
#ENTRYPOINT ["bash"]
