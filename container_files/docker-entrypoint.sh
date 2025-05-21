#!/bin/ash
# Azahar Multiplayer Dedicated Lobby Startup Script
#
# Server Files: /home/azahar

export LD_LIBRARY_PATH=$HOME/lib:$LD_LIBRARY_PATH

clear

s_command="
$HOME/azahar-room \
--port ${AZAHAR_PORT} \
--room-name \"${AZAHAR_ROOMNAME}\" \
--preferred-app \"${AZAHAR_PREFGAME}\" \
--max_members ${AZAHAR_MAXMEMBERS} \
--ban-list-file \"$AZAHAR_BANLISTFILE\" \
--log-file \"${AZAHAR_LOGFILE}\""
s_password="${AZAHAR_PASSWORD}"

add_optional_arg() {
  while [[ "$#" -gt 0 ]]; do
    s_command="$s_command $1"
    shift
  done
}

if [ ! "x$AZAHAR_ROOMDESC" = "x" ]; then
  add_optional_arg "--room-description" "\"${AZAHAR_ROOMDESC}\""
fi

if [ ! "x$AZAHAR_PREFGAMEID" = "x" ]; then
  add_optional_arg "--preferred-app-id" "\"${AZAHAR_PREFGAMEID}\""
fi

if [ "x$s_password" = "x" ] \
  && [ -f "/run/secrets/azaharroom" ]; then
  s_password=$(cat "/run/secrets/azaharoom")
fi

if [ ! "x$s_password" = "x" ]; then
  add_optional_arg "--password" "\"${s_password}\""
fi

if [ ! "x$AZAHAR_ISPUBLIC" = "x" ] \
  && [ $AZAHAR_ISPUBLIC = 1 ]; then
  if [ ! "x$AZAHAR_TOKEN" = "x" ]; then
    add_optional_arg "--token" "\"${AZAHAR_TOKEN}\""
  fi

  if [ ! "x$AZAHAR_WEBAPIURL" = "x" ]; then
    add_optional_arg "--web-api-url" "\"${AZAHAR_WEBAPIURL}\""
  fi
fi

print_header() {
  local pf="● %-19s %-25s\n"

  [ ! "x$AZAHAR_ROOMDESC" = "x" ] && room_desc="${AZAHAR_ROOMDESC}" || room_desc="(unset)"
  [ ! "x$s_password" = "x" ] && room_pass="Yes" || room_pass="No"
  [ $AZAHAR_ISPUBLIC = 1 ] && room_public="Yes" || room_public="No"
  [ ! "x$AZAHAR_PREFGAMEID" = "x" ] && room_pgid="${AZAHAR_PREFGAMEID}" || room_pgid="(unset)"
  [ ! "x$AZAHAR_WEBAPIURL" = "x" ] && room_api="${AZAHAR_WEBAPIURL}" || room_api="(unset)"

  printf "Azahar Dedicated Server\n"
  printf "$pf" "Port:" "${AZAHAR_PORT}"
  printf "$pf" "Name:" "${AZAHAR_ROOMNAME}"
  printf "$pf" "Description:" "${room_desc}"
  printf "$pf" "Password:" "${room_pass}"
  printf "$pf" "Public:" "${room_public}"
  printf "$pf" "Preferred Game:" "${AZAHAR_PREFGAME}"
  printf "$pf" "Preferred Game ID:" "${room_pgid}"
  printf "$pf" "Maximum Members:" "${AZAHAR_MAXMEMBERS}"
  printf "$pf" "Banlist File:" "${AZAHAR_BANLISTFILE}"
  printf "$pf" "Log File:" "${AZAHAR_LOGFILE}"
  printf "$pf" "Web API URL:" "${room_api}"
  printf "\n"
}

print_header
eval "$s_command"