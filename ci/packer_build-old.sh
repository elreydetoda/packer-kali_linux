#!/usr/bin/env bash

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingmodifiedscripthardening
set -${-//[sc]/}eu${DEBUG+xv}o pipefail

choose_packet_options(){
  read -r packet_choice
  eval "${1}=\"${packet_service_array[$packet_choice]}\""
  export $1
}

packet_get_service(){
  packet_service_array=()
  counterz=0
	case $1 in
		facility)
      packet_service_array+=("any - location doesn't matter")
			packet_service_url="projects/${PACKET_PROJECT_UUID}/facilities"
      packet_service_headers="code - location"
			packet_post_jq_pattern='.facilities[] | "\(.code ) - \(.name)"'
			;;

		plan)
			packet_service_url="projects/${PACKET_PROJECT_UUID}/plans"
      packet_service_headers="server types"
      local_facility=$(echo $facility | cut -d ' ' -f 1)
      if [[ ! $local_facility == 'any' ]] ; then
        facility_id=$($curl -X GET "${packet_base_url}/projects/${PACKET_PROJECT_UUID}/facilities" -H "X-Auth-Token: ${PACKET_API_KEY}" | jq -r ".facilities[] | select( .code==\"${local_facility}\") | .id")
        packet_post_jq_pattern=".plans[] | select(.available_in[].href==\"/facilities/${facility_id}\") | .slug"
      else
        packet_post_jq_pattern=".plans[].slug"
      fi
			;;

		os)
			packet_service_url="operating-systems"
      packet_service_headers="operating_system"
			packet_post_jq_pattern=".operating_systems[] | select(.provisionable_on[]==\"${plan}\") | .slug"
			;;

    ips)
      # for some reason this is returning null....
			# packet_service_url="devices/$PACKET_SERVER_ID/ips"
			packet_service_url="devices/$PACKET_SERVER_ID"
      packet_service_headers="IP Address"
			packet_post_jq_pattern='.ip_addresses[0].address'
      ;;
		default)
			echo "Something went terribly wrong...or you added a new parameter."
      echo "If it is the later please search for the packet_get_service function and add necessary variables to access that parameters information."
			exit 1
			;;
	esac
  echo
  echo ${packet_service_headers}
	packet_service_response=$(${curl} -X GET "${packet_base_url}/${packet_service_url}" -H "X-Auth-Token: ${PACKET_API_KEY}" | jq -r "${packet_post_jq_pattern}")
  tmp_ifs=${IFS}
  IFS=$'\n'

  for line in ${packet_service_response} ; do
    
    if [[ $1 == "facility" ]] && [[ $counterz -eq 0 ]] ; then
      printf "%d) %s\n" $counterz "${packet_service_array[${counterz}]}"
      counterz=$(( $counterz + 1 ))
    fi
    
    packet_service_array+=("${line}")
    printf "%d) %s\n" $counterz "${packet_service_array[${counterz}]}"
    counterz=$(( $counterz + 1 ))
  done
  IFS=${tmp_ifs}
}

packet_setup(){

	echo "What is your packet api key?"
	read -r PACKET_API_KEY
	echo "What is your project uuid?"
	read -r PACKET_PROJECT_UUID

  for param in "${packet_parameters[@]}" ; do
    echo
    echo "Please choose from the following choices for: ${param}"
    packet_get_service ${param}
		choose_packet_options ${param}
  done
}

retrieve(){
  if ssh "${2}" -t "[ -f \"${1}\" ]" ; then
    scp "${2}":"${1}" ${ARTIFACTS_DIR}
  else
    # msg="Couldn't find: ${1}"
    # printf '%s\n' "${1}"
    delete_server
    # echo "exiting"
    exit 1
  fi
}

wait_to_finish(){
  minutes_passed=0
  project_folder="${1}"
  ssh_args="${2}"
  status_file="${project_folder}/status.txt"
  # TODO: check if glob works for scp
  logs="${project_folder}/packer.log"
  output_dir="${project_folder}"
  outputs=("red-virtualbox.box")

  too_much_time=120

  if [[ $# -eq 3 ]] ; then
    while [[ ${minutes_passed} -lt ${too_much_time} ]] ; do

      statuz=$(ssh "${ssh_args}" -t cat ${status_file}  )
      statuz=$(echo $statuz | tr -d '\r')


      if [[ "${statuz}" == "building" ]] ; then
        echo "$statuz"
        retrieve "${logs}" "${ssh_args}"
        sleep 5m
        (( minutes_passed += 5 ))
      else
        break
      fi

    done

    if [[ ${minutes_passed} -ge ${too_much_time} ]] ; then
      msg="It took too long...so it failed...specifically: ${minutes_passed}"
      echo "$msg"
      delete_server
      exit 1
    fi

    # getting artifacts
    echo "status was: $statuz"
    if [[ "${statuz}" == 'success' ]] ; then
      msg='Build succeeded!'
      echo "${msg}"
      send_text "${msg}"

      for outputz in "${outputs[@]}" ; do
        current_vagrant_box="${output_dir}/${outputz}"
        # print 'Getting %s' "${current_vagrant_box}"
        retrieve "${current_vagrant_box}"  "${ssh_args}"
      done

      delete_server
      exit 0
    else
      msg='Build failed, getting logs..."'
      echo "${msg}"
      retrieve "${logs}" "${ssh_args}"
      send_text "${msg}"
      delete_server
      exit 1
    fi

  fi

}

run_remote(){
  if [[ -z "${1}" ]] ; then
    echo 'The ip address was not retrieved, please try again and delete the, possibly, old server.'
    delete_server
    exit 1
  fi

  user=root
  project_folder="/opt/packer_kali"
  ssh_args="-oStrictHostKeyChecking=no"

  if [[ $# -eq 1 ]] ; then
  

    rsync -Pav -e "ssh " ~/project/ ${user}@"$1":${project_folder}

    msg='starting build'
    echo "${msg}"
    send_text "${msg}"
    ssh ${user}@${1} -t "CIRCLECI=true bash ${project_folder}/ci/bootstrap.sh"
  else
    ssh ${user}@${1} -t "CIRCLECI=true bash ${project_folder}/build.sh ${2}"
  fi
  # waiting 5 minutes before continuing
  sleep 5m

  # closing function to see the status of the job
  wait_to_finish "${project_folder}" "${user}@${1}" "${@}"
}

check_post(){
  echo
}

delete_server(){
  msg="Deleting server: ${PACKET_SERVER_ID}"
  echo "$msg"
  send_text "$msg"
  $curl -X DELETE \
    "${packet_base_url}/devices/${PACKET_SERVER_ID}" \
    -H 'Content-Type: application/json' \
    -H "X-Auth-Token: ${PACKET_API_KEY}"
}

start_build(){
  # case $2 in
  #   virtualbox)
  #
  #     ;;
  # esac
  run_remote $1 $2
}

function packet_terraform(){
  action="${1}"
  case "${action}" in
    build)
        "${scripts_dir}"/terraform-helper.sh auto-build packet
        remote_packet_ip="$("${scripts_dir}"/terraform-helper.sh output server_ip)"
        current_ip="$("${scripts_dir}"/terraform-helper.sh output current_ip)"
      ;;
    destroy)
      "${scripts_dir}"/terraform-helper.sh auto-destroy packet
      ;;
  esac
}

main(){
  # url for the packet api service
  curl="curl -sSL"
  PERSONAL_NUM="${PERSONAL_NUM:-}"
  scripts_dir="$( cd "$(dirname "scripts")" >/dev/null 2>&1 ; pwd -P )"

  if [[ $CIRCLECI ]] ; then
    # create artifact directory
    ARTIFACTS_DIR='/tmp/artifacts'
    tmp_folder='../'
    project_folder='project'
  else
    tmp_folder='./'
    project_folder='/vagrant'
    ARTIFACTS_DIR='./artifacts'
    packet_setup
  fi
  export ARTIFACTS_DIR PERSONAL_NUM

  mkdir -p ${ARTIFACTS_DIR}


  if [[ $CIRCLECI ]] ; then
    run_remote ${SERVER_IP}
  fi

  # start_build ${SERVER_IP} 'virtualbox'

  echo "Ready for delete"
  delete_server ${PACKET_SERVER_ID}
  
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]] ; then
  main "${@}"
fi
