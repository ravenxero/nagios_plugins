#!/bin/bash
###
#
# Script for checking the consumer sizes on activemq.
# OK = Consumers are correct
# WARN = Not used
# CRIT = Consumers are not correct
#
# Written by Ashley Abbott, modified by David Pickwell
# Copyright:: 2017, The Authors, All Rights Reserved
#
###

# Fail if the number of arguments isn't met
if [ $# -ne 3 ]; then
  printf "You didn't pass enough arguments!\n\nUsage: $0 <hostname or IP> <queue_name> <consumer_count>\n"
  exit 127
fi

#Set variables
JAVA_CMD=`which java`
HOST=$1
QUEUE_NAME=$2
CONSUMER_COUNT=$3
CHECK=`/opt/nagios/custom-plugins/check_jmx -U service:jmx:rmi:///jndi/rmi://$HOST/jmxrmi -O org.apache.activemq:type=Broker,brokerName=localhost,destinationType=Queue,destinationName=$QUEUE_NAME -A ConsumerCount -w 90 -c 100 --username admin --password activemq | awk '{print $6}'`

# Check for JAVA
if [ -z $JAVA_CMD ]
then

  if [ -x $JAVA_HOME/bin/java ]
  then
    JAVA_CMD=$JAVA_HOME/bin/java
  else
    RETVAL=2
    RETSTR="CRITICAL: JAVA not installed"
    echo $RETSTR
    exit $RETVAL
  fi
fi

NODE_CHECK=`netstat -plunt | grep ":61616 " | wc -l`
if [[ NODE_CHECK -eq 0 ]]; then
    RETVAL=0
    RETSTR="OKAY: This is the slave node"
    echo $RETSTR
    exit $RETVAL
fi

# Check if the return of the check contains characters and exit if it does
if [[ $CHECK =~ ^[0-9]+$ ]]; then
    CUR=$CHECK
else
    CHECK=`/opt/nagios/custom-plugins/check_jmx -U service:jmx:rmi:///jndi/rmi://$HOST/jmxrmi -O org.apache.activemq:type=Broker,brokerName=localhost,destinationType=Queue,destinationName=$QUEUE_NAME -A ConsumerCount -w 90 -c 100 --username admin --password activemq`
    RETVAL=2
    RETSTR="CRITICAL: Check contains non-integer characters: $CHECK"
    echo $RETSTR
    exit $RETVAL
fi

ZERO=0

# check if PREV and CUR have values
if [[ $CHECK -ge $CONSUMER_COUNT ]]; then
        RETSTR="OKAY: $QUEUE_NAME queue has $CHECK consumers, which is more than the required $CONSUMER_COUNT consumers."
        RETVAL=0
elif [[ $CHECK -lt $CONSUMER_COUNT ]]; then
        RETSTR="WARN: QUEUE_NAME queue has $CHECK consumers, this should be at least $CONSUMER_COUNT"
        RETVAL=1
elif [[ $CHECK -eq $ZERO ]]; then
        RETSTR="CRITICAL: QUEUE_NAME queue has $CHECK consumers."
        RETVAL=2
else
        RETSTR="Unknown Error with the queue, check the Nagios script $0"
        RETVAL=2
fi

echo $RETSTR
exit $RETVAL
