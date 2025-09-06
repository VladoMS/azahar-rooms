# =========================
# Builder
# =========================
FROM alpine:3.20 AS builder

WORKDIR /tmp/citra

# Build deps (note: 'ninja' on Alpine). Added: python3, git
RUN apk add --no-cache \
      build-base \
      cmake \
      ninja \
      glslang \
      linux-headers \
      pkgconf \
      zlib-dev \
      openssl-dev \
      ca-certificates \
      wget \
      xz \
      python3 \
      git \
 && update-ca-certificates

# Fetch source (Azahar unified source tarball)
RUN mkdir -p /server /tmp/citra/build \
 && wget -q -O citra-unified.tar.xz \
      "https://github.com/azahar-emu/azahar/releases/download/2123.1/azahar-unified-source-2123.1.tar.xz" \
 && tar --strip-components=1 -xf citra-unified.tar.xz

# Portable build script (POSIX sh; no bashisms)
RUN cat > /tmp/citra/build/build.sh <<'SH' \
 && chmod +x /tmp/citra/build/build.sh \
 && /tmp/citra/build/build.sh
#!/bin/sh
set -eu

SCRIPT_DIR=/tmp/citra/build
mkdir -p "$SCRIPT_DIR"
cd "$SCRIPT_DIR"

CMAKE_FLAGS="
  -GNinja
  -DCMAKE_BUILD_TYPE=Release
  -DENABLE_SDL2=OFF
  -DENABLE_QT=OFF
  -DENABLE_COMPATIBILITY_LIST_DOWNLOAD=OFF
  -DUSE_DISCORD_PRESENCE=OFF
  -DENABLE_FFMPEG_VIDEO_DUMPER=OFF
  -DUSE_SYSTEM_OPENSSL=ON
  -DCITRA_WARNINGS_AS_ERRORS=OFF
  -DENABLE_LTO=ON
"

# Optional arch tuning
arch="$(uname -m)"
if [ "$arch" = "aarch64" ]; then
  export CFLAGS="-O2"
  export CXXFLAGS="$CFLAGS"
elif [ "$arch" = "x86_64" ]; then
  export CFLAGS="-O2 -march=core2 -mtune=intel"
  export CXXFLAGS="$CFLAGS"
fi

cmake .. $CMAKE_FLAGS

# Try common targets; fall back as needed
if ! ninja azahar_room_standalone 2>/dev/null; then
  if ! ninja citra_room_standalone 2>/dev/null; then
    ninja
  fi
fi

# Locate produced room binary robustly
BIN_PATH="$(find "$SCRIPT_DIR" -type f \( -name 'azahar-room' -o -name 'citra-room' \) -perm -111 -print -quit)"
if [ -z "$BIN_PATH" ]; then
  echo "ERROR: Could not find built room binary (azahar-room/citra-room) under $SCRIPT_DIR" >&2
  exit 1
fi

# Normalize name to azahar-room for the final image
install -Dm755 "$BIN_PATH" /server/azahar-room
SH

# Keep only artifacts we need for the runtime stage
RUN install -Dm755 /server/azahar-room /out/azahar-room

# =========================
# Runtime
# =========================
FROM alpine:3.20

# Runtime libs: OpenSSL, libstdc++, libgcc, CA roots
RUN apk add --no-cache \
      ca-certificates \
      openssl \
      libstdc++ \
      libgcc \
 && update-ca-certificates

ENV USERNAME=azahar
ENV USERHOME=/home/$USERNAME

# -------- Default Room Configuration --------
# Required
ENV AZAHAR_PORT=24872
ENV AZAHAR_ROOMNAME="Azahar Room"
ENV AZAHAR_PREFGAME="Any"
ENV AZAHAR_MAXMEMBERS=4
ENV AZAHAR_BANLISTFILE="bannedlist.cbl"
ENV AZAHAR_LOGFILE="azahar-room.log"
# Optional
ENV AZAHAR_ROOMDESC=""
ENV AZAHAR_PREFGAMEID="0"
ENV AZAHAR_PASSWORD=""
ENV AZAHAR_ISPUBLIC=0
ENV AZAHAR_TOKEN=""
ENV AZAHAR_WEBAPIURL=""

# Create unprivileged user
RUN adduser -D "$USERNAME"

WORKDIR $USERHOME

# Copy built binary
COPY --from=builder /out/azahar-room $USERHOME/azahar-room

# Copy container files (entrypoint, etc.)
# Ensure container_files/docker-entrypoint.sh has a proper #!/bin/sh shebang and is executable.
COPY ./container_files/ $USERHOME/

# Ensure files/permissions
RUN chmod +x $USERHOME/azahar-room \
 && chmod +x $USERHOME/docker-entrypoint.sh \
 && touch $USERHOME/$AZAHAR_LOGFILE \
 && [ -f "$USERHOME/$AZAHAR_BANLISTFILE" ] || echo "CitraRoom-BanList-1" > "$USERHOME/$AZAHAR_BANLISTFILE" \
 && chown -R $USERNAME:$USERNAME $USERHOME

USER $USERNAME

ENTRYPOINT ["./docker-entrypoint.sh"]
