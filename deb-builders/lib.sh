#!/usr/bin/env bash
set -o errexit

prepare_deb_file(){
  local source_file=$1
  local destination_dir=$2
  mkdir -p "$destination_dir"
  echo "Moving ${source_file} to ${destination_dir}"
  mv "${source_file}" "${destination_dir}/"
}


# Call function
# @param func_name=[FUNCTION_NAME]
#
# call order:
# func_name_[dist]_[arch]
# func_name_[dist]
# func_name_[arch]
# func_name
call_build_function(){
  local func_name dist_codename "${@}"
  local func_arch_name func_dist_codename func_dist_arch_name
  ARCH=$(uname -m)
  if [ "$ARCH" == "x86_64" ];then ARCH=amd64; fi
  if [ "$ARCH" == "aarch64" ];then ARCH=arm64; fi

  if [ -z "$dist_codename" ]
  then
    dist_codename="$(source /etc/os-release;echo "$VERSION_CODENAME")"
  fi

  func_arch_name="${func_name}_${ARCH}"
  func_dist_codename="${func_name}_${dist_codename}"
  func_dist_arch_name="${func_name}_${dist_codename}_${ARCH}"

  if declare -F $func_dist_arch_name &> /dev/null; then
    $func_dist_arch_name
  elif declare -F $func_dist_codename &> /dev/null; then
    #echo "Calling build function: ${func_dist_codename}"
    $func_dist_codename
  elif declare -F $func_arch_name &> /dev/null; then
    #echo "Calling build function: ${func_arch_name}"
    $func_arch_name
  else
    #echo "Calling build function: ${func_name}"
    $func_name
  fi
}
