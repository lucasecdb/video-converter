#!/bin/bash

set -e

export OPTIMIZE="-Os"
export PREFIX="/src/build"
export CFLAGS="${OPTIMIZE} -I${PREFIX}/include"
export CPPFLAGS="${OPTIMIZE} -I${PREFIX}/include"
export LDFLAGS="${OPTIMIZE} -L${PREFIX}/lib"

test -n "$SKIP_BUILD" || (
  apt-get update
  apt-get install -qqy pkg-config
)

PROGRAM_NAME=convert

FILTERS=anull,aresample,crop,null,overlay,rotate,scale,transpose,vflip
DEMUXERS=avi,concat,flv,gif,image2,matroska,mov,mp3,mpegps,ogg
MUXERS=avi,gif,matroska,mov,mp4,mp3,ogg,wav,webm
ENCODERS=aac,ac3,gif,libx264,libmp3lame,mpeg4,vorbis
DECODERS="aac,\
ac3,\
ass,\
gif,\
h264,\
hevc,\
mjpeg,\
mp3,\
mpeg2video,\
mpeg4,\
opus,\
png,\
srt,\
ssa,\
theora,\
vorbis,\
vp8,\
vp9,\
webvtt"

FFMPEG_LIBS="libavformat.a,\
libavcodec.a,\
libavfilter.a,\
libswscale.a,\
libswresample.a,\
libavutil.a"

test -n "$SKIP_BUILD" || test -n "$SKIP_X264" || (
  echo "=========================="
  echo "Compiling libx264"
  echo "=========================="

  cd node_modules/libx264
  if ! patch -R -s -f -p1 --dry-run < ../../x264-configure.patch; then
    patch -p1 < ../../x264-configure.patch
  fi
  emconfigure ./configure \
    --prefix=${PREFIX} \
    --extra-cflags="-Wno-unknown-warning-option" \
    --host=x86-none-linux \
    --disable-cli \
    --enable-shared \
    --disable-opencl \
    --disable-thread \
    --disable-asm \
    --disable-avs \
    --disable-swscale \
    --disable-lavf \
    --disable-ffms \
    --disable-gpac \
    --disable-lsmash
  emmake make -j8
  emmake make install

  echo "=========================="
  echo "Compiling libx264 done"
  echo "=========================="
)

test -n "$SKIP_BUILD" || test -n "$SKIP_LAME" || (
  echo "=========================="
  echo "Compiling lame"
  echo "=========================="

  cd node_modules/libmp3lame
  emconfigure ./configure \
    --prefix=${PREFIX} \
    --host=x86-none-linux \
    --disable-static \
    \
    --disable-gtktest \
    --disable-analyzer-hooks \
    --disable-decoder \
    --disable-frontend
  emmake make -j8
  emmake make install

  echo "=========================="
  echo "Compiling lame done"
  echo "=========================="
)

test -n "$SKIP_BUILD" || test -n "$SKIP_ZLIB" || (
  echo "=========================="
  echo "Compiling zlib"
  echo "=========================="

  cd node_modules/zlib
  emconfigure ./configure --prefix=${PREFIX}
  emmake make -j8
  emmake make install

  echo "=========================="
  echo "Compiling zlib done"
  echo "=========================="
)

test -n "$SKIP_BUILD" || (
  echo "=========================="
  echo "Compiling ffmpeg"
  echo "=========================="

  cd node_modules/ffmpeg
  EM_PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig emconfigure ./configure \
    --prefix=${PREFIX} \
    --cc=emcc \
    --enable-cross-compile \
    --target-os=none \
    --arch=x86 \
    --disable-runtime-cpudetect \
    --disable-asm \
    --disable-fast-unaligned \
    --disable-pthreads \
    --disable-w32threads \
    --disable-os2threads \
    --disable-debug \
    --disable-all \
    --disable-manpages \
    --disable-stripping \
    --enable-ffmpeg \
    --enable-avcodec \
    --enable-avformat \
    --enable-avutil \
    --enable-swresample \
    --enable-swscale \
    --enable-avfilter \
    --disable-network \
    --disable-d3d11va \
    --disable-dxva2 \
    --disable-vaapi \
    --disable-vdpau \
    $(eval echo --enable-decoder={$DECODERS}) \
    $(eval echo --enable-encoder={$ENCODERS}) \
    $(eval echo --enable-demuxer={$DEMUXERS}) \
    $(eval echo --enable-muxer={$MUXERS}) \
    --enable-protocol=file \
    $(eval echo --enable-filter={$FILTERS}) \
    --disable-bzlib \
    --disable-iconv \
    --disable-libxcb \
    --disable-lzma \
    --disable-securetransport \
    --disable-xlib \
    --enable-libmp3lame \
    --enable-gpl \
    --enable-libx264 \
    --enable-zlib \
    --extra-cflags="-I ${PREFIX}/include" \
    --extra-ldflags="-L ${PREFIX}/lib"
  emmake make -j8
  emmake make install
  cp ffmpeg ffmpeg.bc

  echo "=========================="
  echo "Compiling ffmpeg done"
  echo "=========================="
)

EMSCRIPTEN_COMMON_ARGS="--bind \
  ${OPTIMIZE} \
  --closure 1 \
  -s MODULARIZE=1 \
  -s INVOKE_RUN=0 \
  -s EXPORT_NAME=\"ffmpeg\" \
  -s ENVIRONMENT='web,worker' \
  --std=c++17 \
  -x c++ \
  -I ${PREFIX}/include \
  --pre-js preamble.js \
  node_modules/ffmpeg/ffmpeg.bc \
  convert.cpp \
  ${PREFIX}/lib/libmp3lame.so \
  ${PREFIX}/lib/libx264.so"

KB=1024
MB=$((KB * 1024))
GB=$((MB * 1024))

echo "=========================="
echo "Generating bidings"
echo "=========================="
(
  if [[ $ASM_ONLY || $ASM ]]; then
    echo "******************************************"
    echo "Generating asm.js bindings"
    echo "******************************************"
    mkdir -p asm
    emcc \
      $EMSCRIPTEN_COMMON_ARGS \
      -s WASM=0 \
      -s TOTAL_MEMORY=$GB \
      -s USE_CLOSURE_COMPILER=1 \
      -o asm/$PROGRAM_NAME.js
  fi

  if [[ ! $ASM_ONLY ]]; then
    echo "******************************************"
    echo "Generating wasm bindings"
    echo "******************************************"
    emcc \
      $EMSCRIPTEN_COMMON_ARGS \
      -s ALLOW_MEMORY_GROWTH=1 \
      -o $PROGRAM_NAME.js
  fi
)
echo "=========================="
echo "Generating bidings done"
echo "=========================="
