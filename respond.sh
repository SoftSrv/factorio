#!/bin/bash
if [ -z "$response_type" ]; then
  response_type="in_channel"
fi

response_payload="{\"response_type\": \"$response_type\", \"text\": \"$1\"}"

curl -XPOST $response_url -H content-type:'application/json' -d "$response_payload"
