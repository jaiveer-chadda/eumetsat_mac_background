#!/usr/bin/env zsh


eumetsat_bg::download_image() {

  local _project_dir="${CS}/x_Automation/Mac Background/EUMETSAT"
  local _resources_dir="${_project_dir}/resources"
  local _target_file="${_resources_dir}/most_recent_img.png"

  local domain='https://view.eumetsat.int/geoserver/ows'
  
  local service='WMS'
  local request='GetMap'
  local version='1.3.0'
  
  local -a layers_arr=( 'mtg_fd:rgb_geocolour' )
  
  local format='image/png'
  local crs='EPSG:4326'
  
  local -a bounding_box=( -82 -82 82 82 )
  
  local -A _dims=( [width]=800 [height]=800 )
  local dimensions="width=${_dims[width]}&height=${_dims[height]}"

  local -a arguments=( 
    "service=${service}"
    "request=${request}"
    "version=${version}"
    "layers=${(j:,:)layers_arr}"
    "format=${format}"
    "crs=${crs}"
    "bbox=${(j:,:)bounding_box}"
    "${dimensions}"
  )


  curl "${domain}?${(j:&:)arguments}" > "${_target_file}"

}

