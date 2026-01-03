#!/bin/sh

# Usage:  /etc/keepalived/chk_docker_label.sh keepalived.vip=adguard

LABEL="$1"

[ -z "$LABEL" ] && exit 1

/usr/bin/docker ps -q --filter "label=$LABEL" | /bin/grep -q .