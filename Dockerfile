# Copyright (C) 2018  Christian Berger
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

FROM chrberger/javascript-libcluon-builder:latest
MAINTAINER Christian Berger "christian.berger@gu.se"

# Set the env variable DEBIAN_FRONTEND to noninteractive
ENV DEBIAN_FRONTEND noninteractive

# Install necessary tools.
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
    npm \
    wget \
    unzip \
    zip

RUN cd /opt && git clone --recurse-submodules https://github.com/Cyberselves/mini-decoder.js && mv mini-decoder.js sources && cd sources/codecs && \
	rm -r libvpx && git clone https://github.com/webmproject/libvpx/ && cd libvpx && git checkout v1.4.0 && rm -r /opt/sources/ts

ADD ts /opt/sources/ts

WORKDIR /opt/sources 

# Use Bash by default from now.
SHELL ["/bin/bash", "-c"]

RUN npm i -g google-closure-compiler@v20180716 typescript@3.0

RUN cd ts && \
    echo "Retrieving es6-promise.d.ts v4.2.4 from https://github.com/stefanpenner/es6-promise." && \
    wget https://raw.githubusercontent.com/stefanpenner/es6-promise/314e4831d5a0a85edcb084444ce089c16afdcbe2/es6-promise.d.ts && \
    echo "Retrieving emscripten.d.ts v1.3.0 from https://github.com/DefinitelyTyped/DefinitelyTyped." && \
    wget https://raw.githubusercontent.com/DefinitelyTyped/DefinitelyTyped/0ab77b678f0ca0ec18776fe5842f0526982e1fe3/types/emscripten/index.d.ts && \
    mv index.d.ts emscripten.d.ts

# Build openh264_decoder.js.
RUN source /opt/emsdk/emsdk_env.sh && \
    cd /opt/sources && \
    cd codecs/openh264 && \
    patch -p1 < ../../patches/openh264-v1.8.0.patch && \
    emmake make -j24 libopenh264.a && \
    cd /opt/sources && \
    mkdir -p build && cd build && \
    tsc --out .openh264_decoder.js ../ts/openh264_decoder.ts && \
    emcc -o /tmp/openh264_decoder.js \
    -O1 --llvm-lto 1 --memory-init-file 0 \
    -s BUILD_AS_WORKER=1 -s TOTAL_MEMORY=67108864 \
    -s NO_FILESYSTEM=1 \
    -s EXPORTED_FUNCTIONS="['_malloc']" \
    -s EXPORTED_RUNTIME_METHODS="['setValue', 'getValue']" \
    -I /opt/sources/codecs/openh264/codec/api/svc \
    -s EXPORTED_FUNCTIONS="['_WelsCreateDecoder','_WelsInitializeDecoder','_WelsDecoderDecodeFrame','_SizeOfSBufferInfo']" \
    --post-js .openh264_decoder.js \
    /opt/sources/codecs/openh264/libopenh264.a ../bindings/openh264.c && \
    google-closure-compiler --js /tmp/openh264_decoder.js --js_output_file /tmp/openh264_decoder.js.2 && \
    mv /tmp/openh264_decoder.js.2 /tmp/openh264_decoder.js

# Build vpx_decoder.js.
RUN source /opt/emsdk/emsdk_env.sh && \
    cd /opt/sources && \
    cd codecs/libvpx && \
    patch -p1 < ../../patches/libvpx-992d9a0.patch && \
    emconfigure ./configure \
    --disable-multithread \
    --target=generic-gnu \
    --disable-docs \
    --disable-examples \
    --enable-realtime-only \
    --enable-vp8 --enable-vp9 \
    --enable-vp9-postproc --enable-vp9-highbitdepth \
    --disable-webm-io && \
    emmake make -j24 libvpx_g.a && \
    cd /opt/sources && \
    mkdir -p build && cd build && \
    tsc ../ts/libvpx_decoder.ts --target esnext --outfile .libvpx_decoder.js && \
    emcc -o /tmp/libvpx_decoder.js \
    -O1 --llvm-lto 1 --memory-init-file 0 \
    -s BUILD_AS_WORKER=1 -s TOTAL_MEMORY=67108864 \
    -s NO_FILESYSTEM=1 \
    -s EXPORTED_FUNCTIONS="['_malloc']" \
    -s EXPORTED_RUNTIME_METHODS="['setValue', 'getValue']" \
    -I /opt/sources/codecs/libvpx/vpx \
    -s EXPORTED_FUNCTIONS="['_vpx_codec_vp8_dx','_vpx_codec_vp9_dx','_vpx_codec_dec_init2','_allocate_vpx_codec_ctx','_vpx_codec_dec_init_ver','_vpx_codec_decode','_vpx_codec_get_frame']" \
    --post-js .libvpx_decoder.js \
    /opt/sources/codecs/libvpx/libvpx_g.a ../bindings/libvpx.c && \
    google-closure-compiler --js /tmp/libvpx_decoder.js --js_output_file /tmp/libvpx_decoder.js.2 && \
    mv /tmp/libvpx_decoder.js.2 /tmp/libvpx_decoder.js

# When running a Docker container based on this image, simply copy the results to /opt/output.
CMD cp /tmp/openh264_decoder.js /tmp/libvpx_decoder.js /opt/output/

