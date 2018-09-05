#!/bin/bash
#DO_TOKEN should be pre-defined
export dropletId=""#required
export snapshotId=""#computed later
export snapshotName="factorio-ss"

write_msg() {
  echo "---> $@"
}
exec_doctl() {
  eval "doctl $@ -t $DO_TOKEN"
}

validate_prereqs() {
  if [ -z "$dropletId" ]; then
    echo "missing ID. cannot destroy."
    exit 99
  elif [ -z "$DO_TOKEN" ]; then
    echo "missing DO token. cannot destroy."
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
destroy_droplet() {
  write_msg "destroying droplet $dropletId"
  exec_doctl compute droplet delete $dropletId -f
  write_msg "done"
}
restore_snapshot() {
  write_msg "creating new droplet from snapshot $snapshotId"
  exec_doctl compute droplet create factorio --image $snapshotId --tag-name factorio --region sfo2 --size s-1vcpu-3gb --wait
  write_msg "done"
  write_msg "finding new dropletId"
  up_id=$(exec_doctl compute droplet list --format ID --no-header --tag-name factorio)
  write_msg "done"
  write_msg "found new id: $up_id"
}

validate_prereqs
get_droplet
power_down
take_snapshot
destroy_droplet
restore_snapshot
