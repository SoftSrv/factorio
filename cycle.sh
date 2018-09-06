#!/bin/bash
#DO_TOKEN should be pre-defined

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
  write_msg "destroying droplet $dropletId"
  exec_doctl compute droplet delete $dropletId -f
  write_msg "done"
  dropletId=""
}
restore_snapshot() {
  write_msg "creating new droplet from snapshot $snapshotId"
  exec_doctl compute droplet create factorio --image $snapshotId --tag-name factorio --region $region --size $size --wait
  write_msg "done"
  write_msg "finding new dropletId"
  dropletId=$(exec_doctl compute droplet list --format ID --no-header --tag-name factorio)
  write_msg "done"
  write_msg "found new droplet id: $dropletId"
}
write_state() {
  echo "snapshotId=\"$snapshotId\"" > state.env
  echo "dropletId=\"$dropletId\"" >> state.env
  shipctl copy_file_to_state state.env
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
  restore_snapshot
  sleep 2
  destroy_snapshot
  sleep 2
  write_state
fi

write_msg "script complete"
cat state.env