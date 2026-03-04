#!/usr/bin/env zsh

# ——————————————————————————————————————————————————————————————————————————— #

# will run every ~10 mins, since a new photo is uploaded every ~10 mins
eumetsat_bg::main() {

  local -i _ret_code_too_early=2
  local -i _ret_code_download_failed=3
  local -i _ret_code_no_new_img=4

  # ———————————————————————————————————————————————— #

  local _project_root="${CS}/x_Automation/Mac Background/EUMETSAT"
  
  local _environ_dir="${_project_root}/environment"
  local _images_dir="${_project_root}/images"

  local _active_img_updated_fp="${_environ_dir}/active_img_updated"

  local _active_img_fp="${_images_dir}/active_img.png"
  local _temp_img_fp="${_images_dir}/_temp_img.png"

  local -i _secs_in_10_mins=$(( 10 * 60 ))

  # ———————————————————————————————————————————————— #

  local -i   do_force=0
  local -i do_verbose=0
  [[ $1 =~ '-f|--force'   ]] && {               do_force=1; shift; }
  [[ $1 =~ '-v|--verbose' ]] && { do_verbose=1;             shift; }
  [[ $1 =~ '-vf|-fv'      ]] && { do_verbose=1; do_force=1; shift; }

  (( do_verbose )) && {
    (( do_force )) \
      && echo 'do_force   : true' \
      || echo 'do_force   : false'
    echo "do_verbose : true\n"
  }

  local -i current_time="$( date '+%s' )"
  local -i active_img_updated="$( cat "${_active_img_updated_fp}" )"
  local -i time_since_last_update=$(( current_time - active_img_updated ))

  (( do_verbose )) && {
    echo "current time           : ${current_time}"
    echo "active img update time : ${active_img_updated}"
    echo "secs since last update : ${time_since_last_update}\n"
  }

  # if it's been < 10 mins since the last time the bg was updated, don't run
  #  except if --force has been passed
  (( time_since_last_update < _secs_in_10_mins && ! do_force )) && {
    (( do_verbose )) && 
      echo "\e[31mNot enough time since last update\e[0m; exiting"
    return $_ret_code_too_early
  }

  (( do_verbose )) && \
    echo "\e[34m>= 10 mins since last update (or --force set)\e[0m; continuing\n"

  # ———————————————————————————————————————————————— #

  # download the image and save it to ./images/active_img.png
  eumetsat_bg::download_image $do_verbose || {
    (( do_verbose )) && echo "\e[31mDownload Failed\e[0m; exiting"
    # if it fails to download, return != 0
    return $_ret_code_download_failed
  }

  (( do_verbose )) && echo "\e[34mDownload Succeeded\e[0m; continuing\n"

  local -i active_img_birth="$( stat -f %B "${_active_img_fp}" )"
  local -i temp_img_birth="$( stat -f %B "${_temp_img_fp}" )"

  (( do_verbose )) && {
    echo "active img birth time  : ${current_time}"
    echo "downloaded img birth   : ${active_img_updated}"
  }

  # if the img we just dloded has the same creation time as the one we alr have
  #  then delete the temp img, and return != 0
  (( active_img_birth == temp_img_birth )) && {
    (( do_verbose )) && 
      echo "\e[31mImages have same birth time\e[0m; deleting temp img & exiting"
    command rm "${_temp_img_fp}"
    return $_ret_code_no_new_img
  }

  (( do_verbose )) && {
    echo "\e[34mImages do not have same birth time\e[0m; continuing\n"
    echo 'Moving _temp_img.png -> active_img.png'
  }

  mv "${_temp_img_fp}" "${_active_img_fp}"

  (( do_verbose )) && {
    echo "Setting active image birth time to ${temp_img_birth}"
    echo "Setting active img updated time to ${current_time}"
  }

  echo "${temp_img_birth}" > "${_active_img_birth_fp}"

  # if everything succeeds, record current time in environment file
  echo "${current_time}" > "${_active_img_updated_fp}"
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

