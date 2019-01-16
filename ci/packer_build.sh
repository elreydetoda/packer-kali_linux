#!/usr/bin/env bash

set -e



create_server(){
	# checking to see if arguments got passed
	if [[ $# -eq 0 ]] ; then
		### circle ci variables
		## packet
		# facility: the place where the server will be created
		facility='any'
		# plan: which server type do you want?
		plan='baremetal_1'
		# operating system
		os='ubuntu_16_04'
	else
		facility="$1"
		plan="$2"
		os="$3"
	fi
	# Creating machine to build kali image in packet's vps
	echo "Creating "
}

packet_get_service(){
	case $1 in
		facility)
			packet_service_url="projects/${PACKET_PROJECT_UUID}/facilities"
      packet_service_headers="code - name"
			packet_post_jq_pattern='.facilities[] | "\(.code ) - \(.name)"'
			;;
		plan)
			packet_service_url="/projects/${PACKET_PROJECT_UUID}/plans"
      packet_service_headers="code - name"
			packet_post_jq_pattern=''
			;;
		os)
			packet_service_url="/operating-systems"
			packet_post_jq_pattern=''
			;;
		default)
			echo "Something went terribly wrong...or you added a new parameter."
      echo "If it is the later please search for the packet_get_service function and add necessary variables to access that parameters information."
			exit 1
			;;
	esac
	curl -X GET "${packet_base_url}/${packet_service_url}" \
		-H "X-Auth-Token: ${PACKET_API_KEY}"
}

packet_setup(){
	# url for the packet api service
	packet_base_url='https://api.packet.net'
  packet_parameters=( "facility" "plan" "os" )

	echo "What is your packet api key?"
	read PACKET_API_KEY
	echo "What is your project uuid?"
	read PACKET_PROJECT_UUID

  for param in "${packet_parameters[@]}" ; do
    echo "Please choose from the following choices for: ${param}"
  done

}

main(){
	if [[ $CIRCLECI ]] ; then
		# create artifact directory
		artifacts_dir='/tmp/artifacts'
		create_server
	else
		artifacts_dir='./artifacts'
		packet_setup
		choose_packet_options
		create_server $
	fi

	if [ ! -d "${artifacts_dir}" ]; then
		mkdir ${artifacts_dir}
	fi 
}

main
