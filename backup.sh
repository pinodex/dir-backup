#!/bin/bash
# set -e

CONFIG_FILE=./config.json
DISCORD_CMD=./discord/discord.sh
GDRIVE_CMD="$GOPATH/bin/gdrive"
GDRIVE_CONFIG_DIR="${GDRIVE_CONFIG_DIR:-$HOME/.gdrive}"

if [ ! -f "$CONFIG_FILE" ]
then
  echo "config.json cannot be found."
fi

if [ ! -d "$GDRIVE_CONFIG_DIR" ]
then
  echo "gdrive not configured."
fi

CONFIG=`cat "$CONFIG_FILE"`
DISCORD_WEBHOOK_URL=`jq -r .DISCORD_WEBHOOK_URL <<< "$CONFIG"`
BACKUP_SOURCE_DIRECTORY=`jq -r .BACKUP_SOURCE_DIRECTORY <<< "$CONFIG"`
GOOGLE_DRIVE_TARGET_DIRECTORY_ID=`jq -r .GOOGLE_DRIVE_TARGET_DIRECTORY_ID <<< "$CONFIG"`

send_discord_message () {
  local message=$1

  "$DISCORD_CMD" \
    --webhook-url "$DISCORD_WEBHOOK_URL" \
    --username "Minecraft World Backup Bot" \
    --text "$message"
}

get_target_file () {
  local temp_dir=`dirname $(mktemp -u)`
  local timestamp=`date "+%Y-%m-%d-%H-%M-%S"`

  echo "$temp_dir/backup-$timestamp.tar.gz"
}

create_archive () {
  local source_directory=$1
  local target=$2

  if [ ! -d "$source_directory" ]
  then
    echo "Cannot find directory $source_directory"

    return 1
  fi

  echo "Creating archive of $source_directory ..."

  tar -czf "$target" -C "$source_directory" .

  echo "Archive saved to $target"

  return 0
}

upload_file () {
  local source_file=$1
  local target_directory_id=$2

  "$GDRIVE_CMD" -c "$GDRIVE_CONFIG_DIR" upload \
    -p "$target_directory_id" \
    "$source_file"
}

get_drive_info () {
  "$GDRIVE_CMD" -c "$GDRIVE_CONFIG_DIR" about | tail -n +2
}

LOG_FILE=`mktemp`
BACKUP_FILE=`get_target_file`

{
  create_archive "$BACKUP_SOURCE_DIRECTORY" "$BACKUP_FILE"
  upload_file "$BACKUP_FILE" "$GOOGLE_DRIVE_TARGET_DIRECTORY_ID"

  rm "$BACKUP_FILE"

  echo ""

  get_drive_info
} 2>&1 | tee "$LOG_FILE"

send_discord_message "$(jq -Rs . < "$LOG_FILE" | cut -c 2- | rev | cut -c 2- | rev)"
