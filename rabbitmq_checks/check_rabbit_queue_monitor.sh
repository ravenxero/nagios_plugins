#!/bin/bash
###
#
# Script for checking the queue and consumer sizes on RabbitMQ.
# OK = Queues are at 0
# WARN = Queues are changing size
# CRIT = Queues are >0 and not changing
#
# Written by David Pickwell
# Copyright:: 2019, The Authors, All Rights Reserved
#
###

if [ $# -ne 3 ]
then
  printf "You didn't pass the correct arguments!\n\nUsage: $0 <min_threshold> <warn_threshold> <crit_threshold>\n"
  exit 127
fi

OKAY=$1
WARN=$2
CRIT=$3

unset $RETVAL
unset $WARN_STR
unset $CRIT_STR
unset $OKAY_STR
OKAY_VAL=0
WARN_VAL=0
CRIT_VAL=0

CMD=`/bin/which rabbitmqctl`
RAW_DATA=`/sbin/rabbitmqctl list_queues --local name messages | grep -v -i dead | egrep -v 'Listing|Timeout'`

mapfile -t ARRAY < <(echo "$RAW_DATA")

for I in "${ARRAY[@]}"
do

  unset RETVAL
  unset RETSTR#!/bin/bash

  IFS=$'\t'
  read  -r NAME COUNT <<< "$I"

  # We need to strip spaces from the name
  FILE_NAME=`echo $NAME | sed 's/ //g'`
  FILE="/tmp/${FILE_NAME}_messages.nagios"

  # Check if the return of the check contains characters and exit if it does
  if [[ $COUNT =~ ^[0-9]+$ ]]; then
    CUR=$COUNT
  else
    RETVAL=2
    RETSTR="Check contains non-integer characters"
    exit $RETVAL
  fi

  if [[ -e "${FILE}" ]]; then
    PREV=`cat ${FILE}`
  else
    PREV=0
  fi

  # Greater then CRIT
  if [ ${CUR} -gt ${CRIT} ]; then
    CRIT_STR=$"${CRIT_STR}CRIT: RabbitMQ Queue \"${NAME}\" is greater than ${CRIT}, at ${CUR} | "
    CRIT_VAL=1
  # If the queue is empty
  elif [ ${CUR} -eq 0 ]; then
    OKAY_STR=$"${OKAY_STR}OKAY: RabbitMQ Queue \"${NAME}\" is empty | "
    OKAY_VAL=1
  # Greater than MIN and NOT processing
  elif [ $CUR -gt $OKAY -a $CUR -eq $PREV ]; then
    CRIT_STR=$"${CRIT_STR}CRIT: RabbitMQ Queue \"${NAME}\" is greater than ${OKAY}, at ${CUR}, and stationary | "
    CRIT_VAL=1
  # Less than MIN and NOT processing
  elif [ ${CUR} -le ${OKAY} -a ${CUR} -eq ${PREV} ]; then
    WARN_STR=$"${WARN_STR}WARN: RabbitMQ Queue \"${NAME}\" is less than ${OKAY}, at ${CUR}, but stationary | "
    WARN_VAL=1
  # Between WARN and CRIT and IS processing
  elif [ ${CUR} -gt ${WARN} -a ${CUR} -ne ${PREV} ]; then
    WARN_STR=$"${WARN_STR}WARN: RabbitMQ Queue \"${NAME}\" is processing, at ${CUR} | "
    WARN_VAL=1
  else
    OKAY_STR=$"${OKAY_STR}OKAY: RabbitMQ Queue \"${NAME}\" is processing, at ${CUR} | "
    OKAY_VAL=1
  fi

  # Lets reset the file with the new count
  echo $COUNT > ${FILE}

done

if [ ${CRIT_VAL} -eq 1 ]; then
  echo ${CRIT_STR}
  exit 2
elif [ ${WARN_VAL} -eq 1 ]; then
  echo ${WARN_STR}
  exit 1
elif [ ${OKAY_VAL} -eq 1 ]; then
  echo "OKAY: All queues are currently okay"
  exit 0
else
  echo "Something is fundamentally wrong here, please check the script ${0}"
  exit 3
fi
