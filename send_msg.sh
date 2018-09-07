#!/bin/bash
# $1 is the message to send

send_msg() {
    echo "{\"text\":\"$1\"}" > /tmp/payload.json
    shipctl notify factorio-slack --payload=/tmp/payload.json
}