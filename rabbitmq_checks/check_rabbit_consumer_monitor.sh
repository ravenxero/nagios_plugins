#!/bin/bash
###
#
# Script for checking the consumer sizes on RabbitMQ.
#
# Written by David Pickwell
# Copyright:: 2019, The Authors, All Rights Reserved
#
###

function show_help {
  printf "    --set\t\tSet the consumers to the current count\n"
  printf "    --help\t\tShow the help page\n"
}

function set_files {

  RAW_DATA=`/sbin/rabbitmqctl list_queues --local name consumers | grep -v -i dead | egrep -v 'Listing|Timeout'`
  mapfile -t ARRAY < <(echo "$RAW_DATA")

  for I in "${ARRAY[@]}"
  do
    IFS=$'\t'
    read  -r NAME CONSUMER_COUNT <<< "$I"

    if [[ ! $CONSUMER_COUNT =~ ^[0-9]+$ ]]; then
      echo "Check contains non-integer characters"
      exit 2
    fi

    printf "${CONSUMER_COUNT}\t| ${NAME}\n"
  done

  while true; do
    read -p "Do you want to update the check to the above consumer count (YES/NO)? " yn
    case $yn in
      YES ) break;;
      NO ) echo "Cancelling update, no changes have been made..."; exit;;
      * ) echo "Please answer [YES|NO]:";;
    esac
  done

  for I in "${ARRAY[@]}"

  do
    IFS=$'\t'
    read  -r NAME CONSUMER_COUNT <<< "$I"

    # We need to strip spaces from the name
    FILE_NAME=`echo $NAME | sed 's/ //g'`
    FILE="/tmp/${FILE_NAME}_consumers.nagios"

    printf "Queue:\t\"${NAME}\"\n"
    printf "File:\t${FILE}\n"
    printf "Consumer:\t${CONSUMER_COUNT}\n"

    echo $CONSUMER_COUNT > ${FILE}

  done


}

function run_check {

  RETVAL=0
  RAW_DATA=`/sbin/rabbitmqctl list_queues --local name consumers | grep -v -i dead | egrep -v 'Listing|Timeout'`
  mapfile -t ARRAY < <(echo "$RAW_DATA")

  unset RETSTR

  for I in "${ARRAY[@]}"
  do

    IFS=$'\t'
    read  -r NAME CONSUMER_COUNT <<< "$I"

    if [[ ! $CONSUMER_COUNT =~ ^[0-9]+$ ]]; then
      echo "CRIT:Check contains non-integer characters"
      exit 2
    fi

    FILE_NAME=`echo $NAME | sed 's/ //g'`
    FILE="/tmp/${FILE_NAME}_consumers.nagios"

    if [[ -e "${FILE}" ]]; then
      SET_CONSUMER_COUNT=`cat ${FILE}`
    else
      printf "CRIT:Queue file \"${FILE}\" has not been created\nRun $0 --set to initiate the check\n"
      exit 2
    fi

    if [[ $CONSUMER_COUNT -ne $SET_CONSUMER_COUNT ]]; then
      RETSTR=$"${RETSTR}CRIT:Consumer Count for \"${NAME}\" is not as expected. Should be ${SET_CONSUMER_COUNT}, is actually ${CONSUMER_COUNT} | "
      RETVAL=2
    fi

  done

  if [[ $RETVAL -eq 0 ]]; then
    RETSTR="OKAY:All Consumers are the correct count."
  fi

  echo $RETSTR
  exit $RETVAL

}

if [[ -z $1 ]]; then
  run_check
elif [[ $1 == "--set" ]]; then
  set_files
elif [[ $1 == "--help" ]]; then
  show_help
else
  printf "You didn't pass the correct arguments!\n\nUsage: $0 [--set|--help]\n\n"
  show_help
fi
