#!/usr/bin/env bash

set -euo pipefail

curl="curl -sSL"

create_server(){
	# checking to see if arguments got passed
	if [[ $# -eq 0 ]] ; then
		### circle ci variables
		## packet
		# facility: the place where the server will be created
		chosen_facility='any'
		# plan: which server type do you want?
		chosen_plan='baremetal_1'
		# operating system
		chosen_os='ubuntu_16_04'
	else
    chosen_facility="$(echo ${facility} | cut -d ' ' -f 1)"
		chosen_plan="${plan}"
		chosen_os="${os}"
	fi
	# Creating machine to build kali image in packet's vps
	echo "Creating new server for a packer host."
  packet_service_url="projects/${PACKET_PROJECT_UUID}/devices"
  export PACKET_SERVER_ID=$($curl -X POST \
  "${packet_base_url}/${packet_service_url}" \
  -H 'Content-Type: application/json' \
  -H "X-Auth-Token: ${PACKET_API_KEY}" \
  -H 'cache-control: no-cache' \
  -d "{
    \"facility\": \"${chosen_facility}\",
    \"plan\": \"${chosen_plan}\",
    \"operating_system\": \"${chosen_os}\"
  }" | jq -r '.id')
  
}

choose_packet_options(){
  read packet_choice
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
	read PACKET_API_KEY
	echo "What is your project uuid?"
	read PACKET_PROJECT_UUID

  for param in "${packet_parameters[@]}" ; do
    echo
    echo "Please choose from the following choices for: ${param}"
    packet_get_service ${param}
		choose_packet_options ${param}
  done
}

retrieve(){
  if ssh "${2}" -t "[ -f "${1}" ]" ; then
    scp "${2}":"${1}" ${ARTIFACTS_DIR}
  else
    printf "Couldn't find: %s\n" "${1}"
    delete_server
    exit 1
  fi
}

send_text(){
  if [[ -z "${PERSONAL_NUM}" ]] ; then
    echo "Number wasn't set, so no text for you..."
  else
    curl -X POST https://textbelt.com/text \
      --data-urlencode phone="${PERSONAL_NUM}" \
      --data-urlencode message="${1}" \
      -d key="${TEXTBELT_KEY}"
  fi
}

wait_to_finish(){
  minutes_passed=0
  project_folder="${1}"
  ssh_args="${2}"
  status_file="${project_folder}/status.txt"
  # TODO: check if glob works for scp
  logs="${project_folder}/packer.log"
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
      send_text "${msg}"
      delete_server
      exit 1
    fi

    # getting artifacts
    echo "status was: $statuz"
    if [[ "${statuz}" == 'success' ]] ; then
      msg='Build succeeded!'
      echo "${msg}"
      send_text "${msg}"
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

add_ecdsa(){
  echo "adding ecdsa key for host: ${1}"
  ssh-keyscan $1 | tee -a ~/.ssh/known_hosts
}

run_remote(){
  if [[ -z $1 ]] ; then
    echo 'The ip address was not retrieved, please try again and delete the, possibly, old server.'
    delete_server
    exit 1
  fi

  user=root
  project_folder="/opt/packer_kali"
  ssh_args="-oStrictHostKeyChecking=no"

  add_ecdsa $1

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
  wait_to_finish "${project_folder}" "${user}@${1}" ${@}
}

check_post(){
  echo
}

delete_server(){
  echo "Deleting server: ${PACKET_SERVER_ID}"
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

main(){
  # url for the packet api service
  packet_base_url='https://api.packet.net'
  packet_parameters=( "facility" "plan" "os" )
  set +u
  if [[ -z $PERSONAL_NUM ]] ; then
    PERSONAL_NUM=''
  fi
  set -u

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

  create_server

  mkdir -p ${ARTIFACTS_DIR}


  if [ "$(echo -n $PACKET_SERVER_ID | wc -c)" -ne 36 ]; then
    echo "Server may have failed provisionining. Device ID is set to: $PACKET_SERVER_ID"
    exit 1
  fi

  echo "Your packer build box has successfully provisioned with ID: $PACKET_SERVER_ID"


  echo "Sleeping 10 minutes to wait for Packet servers to finish provisiong"
  sleep 10m
  # # sleep 300
  # # echo "Sleeping 5 more minutes (CircleCI Keepalive)"
  # # sleep 300

  packet_get_service ips
  SERVER_IP=${packet_service_array[0]}
  echo ${SERVER_IP}
  if [[ $CIRCLECI ]] ; then
    run_remote ${SERVER_IP}
  fi

  # start_build ${SERVER_IP} 'virtualbox'

  echo "Ready for delete"
  # delete_server ${PACKET_SERVER_ID}
  
}

main
