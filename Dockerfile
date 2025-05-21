FROM alpine:3.20 AS builder

WORKDIR /tmp/citra

RUN apk update \
    && apk -U add --no-cache \
        build-base \
        binutils-gold \
        ca-certificates \
        cmake \
        glslang \
        libstdc++ \
        linux-headers \
        ninja-build \
        openssl-dev \
        wget \
        xz \
    && export PATH=$PATH:/bin:/usr/local/bin:/usr/bin:/sbin:/usr/lib/ninja-build/bin \
    && mkdir -p /server/lib /tmp/citra/build \
    && wget --show-progress -q -c -O "citra-unified.tar.xz" "https://github.com/azahar-emu/azahar/releases/download/2121.1/azahar-unified-source-2121.1.tar.xz" \
    && tar --strip-components=1 -xf citra-unified.tar.xz \
    && { echo "#!/bin/ash"; \
         echo "SCRIPT_DIR=/tmp/citra/build"; \
         echo "cd \$SCRIPT_DIR"; \
         echo "LDFLAGS=\"-flto -fuse-linker-plugin -fuse-ld=gold\""; \
         echo "CFLAGS=\"-ftree-vectorize -flto\""; \
         echo "if [[ \"$(uname -m)\" == \"aarch64\" ]]; then"; \
         echo "  CFLAGS=\"-O2\""; \
         echo "  LDFLAGS=\"\""; \
         echo "elif [[ \"$(uname -m)\" == \"x86_64\" ]]; then"; \
         echo "  CFLAGS=\"$CFLAGS -march=core2 -mtune=intel\""; \
         echo "fi"; \
         echo "export CFLAGS"; \
         echo "export CXXFLAGS=\"$CFLAGS\""; \
         echo "export LDFLAGS"; \
         echo "cmake .. -GNinja -DCMAKE_BUILD_TYPE=Release \\"; \
         echo " -DENABLE_SDL2=OFF -DENABLE_QT=OFF -DENABLE_COMPATIBILITY_LIST_DOWNLOAD=OFF \\"; \
         echo " -DUSE_DISCORD_PRESENCE=OFF -DENABLE_FFMPEG_VIDEO_DUMPER=OFF -DUSE_SYSTEM_OPENSSL=ON \\"; \
         echo " -DCITRA_WARNINGS_AS_ERRORS=OFF -DENABLE_LTO=ON"; \
         echo "ninja citra_room_standalone "; \
       } >/tmp/citra/build/build.sh \
        && chmod +x /tmp/citra/build/build.sh \
     && /tmp/citra/build/build.sh \
     && cp /tmp/citra/build/bin/Release/azahar-room /server/azahar-room \
     && strip /server/azahar-room \
     && chmod +x /server/azahar-room \
     && cp /usr/lib/libgcc_s.so.1 /server/lib/libgcc_s.so.1 \
     && cp /usr/lib/libstdc++.so.6 /server/lib/libstdc++.so.6 \
     && echo -e "CitraRoom-BanList-1" > /server/bannedlist.cbl \
     && touch /server/azahar-room.log \
     && rm -R /tmp/citra


FROM alpine:3.20

ENV USERNAME=azahar
ENV USERHOME=/home/$USERNAME

# Required
ENV AZAHAR_PORT=24872
ENV AZAHAR_ROOMNAME="Azahar Room"
ENV AZAHAR_PREFGAME="Any"
ENV AZAHAR_MAXMEMBERS=4
ENV AZAHAR_BANLISTFILE="bannedlist.cbl"
ENV AZAHAR_LOGFILE="citra-room.log"
# Optional
ENV AZAHAR_ROOMDESC=""
ENV AZAHAR_PREFGAMEID="0"
ENV AZAHAR_PASSWORD=""
ENV AZAHAR_ISPUBLIC=0
ENV AZAHAR_TOKEN=""
ENV AZAHAR_WEBAPIURL=""

RUN apk update \
    && adduser --disabled-password $USERNAME \
    && rm -rf /tmp/* /var/tmp/*

COPY --from=builder --chown=$USERNAME /server/ $USERHOME/
COPY --chown=$USERNAME ./container_files/ $USERHOME/

USER $USERNAME
WORKDIR $USERHOME

RUN chmod +x docker-entrypoint.sh

ENTRYPOINT ["./docker-entrypoint.sh"]