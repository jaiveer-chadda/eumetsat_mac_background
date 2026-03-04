#!/usr/bin/env zsh


# will run every ~10 mins, since a new photo is uploaded every ~10 mins
eumetsat_bg::main() {

  local -i do_force=0
  [[ $1 =~ '-f|--force' ]] && { do_force=1; shift; }

  local _project_root="${CS}/x_Automation/Mac Background/EUMETSAT"
  local _environ_dir="${_project_root}/environment"
  local _time_last_run_file="${_environ_dir}/time_last_run.txt"

  local _secs_in_10_mins=$(( 10 * 60 ))

  local current_time="$( date '+%s' )"
  local time_last_run="$( cat "${_time_last_run_file}" )"

  # if it's been < 10 mins since the last run, don't re-run it
  #  except if --force has been passed
  (( current_time - time_last_run < _secs_in_10_mins && ! do_force )) \
    && return 1
  
  # download the image and save it to ./images/most_recent_img.png
  #  if it succeeds, record current time in environment file
  eumetsat_bg::download_image && \
    echo "${current_time}" > "${_time_last_run_file}"
}



eumetsat_bg::download_image() {

  local _project_root="${CS}/x_Automation/Mac Background/EUMETSAT"
  local _images_dir="${_project_root}/images"
  local _recent_img_file="${_images_dir}/most_recent_img.png"

  local domain='https://view.eumetsat.int/geoserver/ows'
  
  local service='WMS'
  local request='GetMap'
  local version='1.3.0'
  
  local -a layers=( 'mtg_fd:rgb_geocolour' )
  
  local format='image/png'
  local crs='EPSG:4326'
  
  local -a bounding_box=( -82 -82 82 82 )
  local -A dimensions=( [width]=800 [height]=800 )

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

  curl -s "${domain}?${(j:&:)arguments}" > "${_recent_img_file}" \
    && return 0 \
    || return 1

}

