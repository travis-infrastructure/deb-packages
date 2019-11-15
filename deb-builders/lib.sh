#!/usr/bin/env bash
set -o errexit

prepare_deb_file(){
  local source_file=$1
  local destination_dir=$2
  mkdir -p $destination_dir
  echo "Moving ${source_file} to ${destination_dir}"
  mv ${source_file} ${destination_dir}/
}
