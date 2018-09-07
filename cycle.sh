#!/bin/bash 
set -e
#DO_TOKEN should be pre-defined
source send_msg.sh
write_msg() {
  echo "---> $@"
}
exec_doctl() {
  eval "doctl $@ -t $DO_TOKEN"
}

validate_prereqs() {
  if [ -z "$dropletId" ] && [ -z "$snapshotId" ]; then
    echo "need a dropletId or a snapshotId to proceed"
    exit 99
  elif [ -z "$DO_TOKEN" ]; then
    echo "missing DO token. cannot use API."
    exit 99
  fi
  write_msg "all args present"
}
get_droplet() {
  up_id=$(exec_doctl compute droplet list --format ID --no-header --tag-name factorio)
  if [ "$up_id" != "$dropletId" ]; then
    echo "running droplet .${up_id}. does not match requested ID .${dropletId}."
    exit 99
  fi
  write_msg "got droplet with id $dropletId"
}
power_down() {
  send_msg "Shutting down droplet $dropletId"
  write_msg "shutting down $dropletId"
  exec_doctl compute droplet-action power-off $dropletId --wait --no-header --format Status,CompletedAt
  write_msg "done"
}
power_up() {
  write_msg "powering up $dropletId"
  exec_doctl compute droplet-action power-on $dropletId --wait --no-header --format Status,CompletedAt
  write_msg "done"
}
take_snapshot() {
  send_msg "Taking snapshot. This might take a minute."
  write_msg "taking snapshot of droplet $dropletId"
  exec_doctl compute droplet-action snapshot $dropletId --no-header --format ID --snapshot-name $snapshotName --wait
  write_msg "done"
  write_msg "getting snapshot id"
  snapshotId=$(doctl compute image list --no-header --format ID,Name -t $DO_TOKEN | grep $snapshotName | awk '{print $1}')
  write_msg "done"
  write_msg "snapshot ID is: $snapshotId"
}
destroy_snapshot() {
  write_msg "removing snapshot"
  exec_doctl compute snapshot delete $snapshotId -f --no-header 
  write_msg "done"
  snapshotId=""
}
destroy_droplet() {
  send_msg "Destroying droplet $dropletId"
  write_msg "destroying droplet $dropletId"
  exec_doctl compute droplet delete $dropletId -f
  write_msg "done"
  dropletId=""
  send_msg "Droplet has been destroyed."
}
restore_snapshot() {
  write_msg "restoring droplet from snapshot $snapshotId"
  exec_doctl compute droplet create factorio --image $snapshotId --tag-name factorio --region $region --size $size --wait
  write_msg "done"
  write_msg "finding new dropletId and publicIP"
  result=$(doctl compute droplet list --no-header --format ID,PublicIPv4 --tag-name factorio -t $DO_TOKEN)
  dropletId=$(awk '{print $1}' <<< result)
  publicIP=$(awk '{print $2}' <<< result)
  write_msg "found new droplet id: $dropletId"
  write_msg "publicIP is $publicIP"
  shipctl put_resource_state $JOB_NAME versionName $publicIP
  send_msg "New droplet started with IP: $publicIP"
  write_msg "done"
}
write_state() {
  write_msg "writing new values to state:"
  write_msg "dropletId: $dropletId"
  write_msg "snapshotId: $snapshotId"
  echo "export snapshotId=\"$snapshotId\"" > state.env
  echo "export dropletId=\"$dropletId\"" >> state.env
  shipctl copy_file_to_state state.env
  write_msg "done"
}


validate_prereqs
if [ -n $dropletId ] && [ -z $snapshotId ]; then
  get_droplet
  power_down
  sleep 2
  take_snapshot
  sleep 2
  destroy_droplet
  sleep 2
  write_state
elif [ -n $snapshotId ] && [ -z $dropletId ]; then 
  send_msg "Restoring droplet from snapshot $snapshotId"
  restore_snapshot
  sleep 2
  destroy_snapshot
  sleep 2
  write_state
else
  write_msg "bad state"
  write_msg "dropletId: $dropletId"
  write_msg "snapshotId: $snapshotId"
fi

write_msg "script complete"