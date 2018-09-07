#!/bin/bash

resource=$1
target=$2
message=$3
echo "{\"text\":\"$3\",\"channel\":\"$2\"}" > /tmp/payload.json

shipctl notify $1 --payload /tmp/payload.json