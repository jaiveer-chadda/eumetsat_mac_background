#!/usr/bin/env zsh


eumetsat_bg::init() {

  # ————— Return Codes ——————

  export EB_RET_CODE_TOO_EARLY=2
  export EB_RET_CODE_DOWNLOAD_FAILED=3
  export EB_RET_CODE_NO_NEW_IMG=4

  # ————— Filepaths ——————

  export EB_PROJECT_ROOT="${CS}/x_Automation/Mac Background/EUMETSAT"

  export EB_ENVIRONMENT_DIR="${EB_PROJECT_ROOT}/environment"
  export EB_IMAGES_DIR="${EB_PROJECT_ROOT}/images"

  export EB_ACTIVE_IMG_UPDATED_FP="${EB_ENVIRONMENT_DIR}/active_img_updated"

  export EB_ACTIVE_IMG_FP="${EB_IMAGES_DIR}/active_img.png"
  export EB_TEMP_IMG_FP="${EB_IMAGES_DIR}/_temp_img.png"

  # ————— Time ——————

  export EB_10_MINS_IN_SECS=$(( 10 * 60 ))

  export EB_CURRENT_TIME="$( date '+%s' )"
  export EB_ACTIVE_IMG_UPDATED="$( cat "${EB_ACTIVE_IMG_UPDATED_FP}" )"
  export EB_TIME_SINCE_LAST_UPDATE=$(( EB_CURRENT_TIME - EB_ACTIVE_IMG_UPDATED ))

  export EB_ACTIVE_IMG_BIRTH="$( stat -f %B "${EB_ACTIVE_IMG_FP}" )"
  # export EB_TEMP_IMG_BIRTH="$( stat -f %B "${EB_TEMP_IMG_FP}" )"

}

eumetsat_bg::deinit() {
  unset \
    EB_RET_CODE_TOO_EARLY   EB_RET_CODE_DOWNLOAD_FAILED                     \
    EB_RET_CODE_NO_NEW_IMG  EB_PROJECT_ROOT             EB_ENVIRONMENT_DIR  \
    EB_IMAGES_DIR           EB_ACTIVE_IMG_UPDATED_FP    EB_ACTIVE_IMG_FP    \
    EB_TEMP_IMG_FP          EB_10_MINS_IN_SECS          EB_CURRENT_TIME     \
    EB_ACTIVE_IMG_UPDATED   EB_TIME_SINCE_LAST_UPDATE   EB_ACTIVE_IMG_BIRTH \
    EB_TEMP_IMG_BIRTH
}


# ——————————————————————————————————————————————————————————————————————————— #

eumetsat_bg() {
  eumetsat_bg::init
  eumetsat_bg::main "${@}"
  local -i ret_code="${?}"
  eumetsat_bg::deinit
  return $ret_code
}

# ——————————————————————————————————————————————————————————————————————————— #

# will run every ~10 mins, since a new photo is uploaded every ~10 mins
eumetsat_bg::main() {

  local -i   do_force=0
  local -i do_verbose=0
  [[ $1 =~  '^-f$|^--force$'   ]] && {               do_force=1; shift; }
  [[ $1 =~  '^-v$|^--verbose$' ]] && { do_verbose=1;             shift; }
  [[ $1 =~ '^-vf$|^-fv$'       ]] && { do_verbose=1; do_force=1; shift; }

  (( do_verbose )) && {
    (( do_force )) \
      && echo 'do_force   : true' \
      || echo 'do_force   : false'
    echo "do_verbose : true\n"
    echo "current time           : ${EB_CURRENT_TIME}"
    echo "active img update time : ${EB_ACTIVE_IMG_UPDATED}"
    echo "secs since last update : ${EB_TIME_SINCE_LAST_UPDATE}\n"
  }

  # if it's been < 10 mins since the last time the bg was updated, don't run
  #  except if --force has been passed
  (( EB_TIME_SINCE_LAST_UPDATE < EB_10_MINS_IN_SECS && ! do_force )) && {
    (( do_verbose )) && 
      echo "\e[31mNot enough time since last update\e[0m; exiting"
    return $EB_RET_CODE_TOO_EARLY
  }

  (( do_verbose )) && \
    echo "\e[34m>= 10 mins since updated (or --force is set)\e[0m; continuing\n"

  # ———————————————————————————————————————————————— #

  # download the image and save it to ./images/active_img.png
  eumetsat_bg::download_image $do_verbose || {
    (( do_verbose )) && echo "\e[31mDownload Failed\e[0m; exiting"
    # if it fails to download, return != 0
    return $EB_RET_CODE_DOWNLOAD_FAILED
  }
  
  export EB_TEMP_IMG_BIRTH="$( stat -f %B "${EB_TEMP_IMG_FP}" )"

  (( do_verbose )) && {
    echo "\e[34mDownload Succeeded\e[0m; continuing\n"
    echo "active img birth time  : ${EB_CURRENT_TIME}"
    echo "downloaded img birth   : ${EB_ACTIVE_IMG_UPDATED}"
  }

  # if the img we just dloded has the same creation time as the one we alr have
  #  then delete the temp img, and return != 0
  (( EB_ACTIVE_IMG_BIRTH == EB_TEMP_IMG_BIRTH )) && {
    (( do_verbose )) && 
      echo "\e[31mImages have same birth time\e[0m; deleting temp img & exiting"
    command rm "${EB_TEMP_IMG_FP}"
    return $EB_RET_CODE_NO_NEW_IMG
  }

  (( do_verbose )) && {
    echo "\e[34mImages do not have same birth time\e[0m; continuing\n"
    echo 'Moving _temp_img.png -> active_img.png\n'
  }

  mv "${EB_TEMP_IMG_FP}" "${EB_ACTIVE_IMG_FP}"

  (( do_verbose )) && {
    echo "Setting active image birth time to ${EB_TEMP_IMG_BIRTH}"
    echo "Setting active img updated time to ${EB_CURRENT_TIME}"
  }

  # if everything succeeds, record current time in environment file
  echo "${EB_CURRENT_TIME}" > "${EB_ACTIVE_IMG_UPDATED_FP}"
}


# ——————————————————————————————————————————————————————————————————————————— #


eumetsat_bg::download_image() {

  local -i do_verbose="$1"

  (( do_verbose )) && echo 'Beginning download process'

  # ———————————————————————————————————————————————— #
  
  local _project_root="${CS}/x_Automation/Mac Background/EUMETSAT"
  local _images_dir="${_project_root}/images"
  local _temp_img_file="${_images_dir}/_temp_img.png"

  # ———————————————————————————————————————————————— #

  local domain='https://view.eumetsat.int/geoserver/ows'
  
  local service='WMS'
  local request='GetMap'
  local version='1.3.0'
  
  local -a layers=( 'mtg_fd:rgb_geocolour' )
  
  local format='image/png'
  local crs='EPSG:4326'
  
  local -a bounding_box=( -82 -82 82 82 )
  local -A dimensions=( [width]=800 [height]=800 )

  # ———————————————————————————————————————————————— #

  local -a arguments=( 
    "service=${service}"
    "request=${request}"
    "version=${version}"
    "layers=${(j:,:)layers}"
    "format=${format}"
    "crs=${crs}"
    "bbox=${(j:,:)bounding_box}"
    "width=${dimensions[width]}"
    "height=${dimensions[height]}"
  )

  local download_link="${domain}?${(j:&:)arguments}"

  (( do_verbose )) && echo "Download link : ${download_link}"

  curl -s "${download_link}" > "${_temp_img_file}" && return 0 || return 1

}

# ——————————————————————————————————————————————————————————————————————————— #

