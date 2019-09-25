#!/bin/bash
###
#
# Script for checking the queue sizes on activemq.
# OK = Queues are at 0
# WARN = Queues are changing size
# CRIT = Queues are >0 and not changing
#
# Written by Ashley Abbott, modified by David Pickwell
# Copyright:: 2017, The Authors, All Rights Reserved
#
###

# Fail if the number of arguments isn't met
if [ $# -ne 2 ]; then
  printf "You didn't pass enough arguments!\n\nUsage: $0 <hostname or IP> <queue_name> \n"
  exit 127
fi

#Set variables
JAVA_CMD=`which java`
HOST=$1
QUEUE_NAME=$2
TMP_FILE_NAME=`echo -n $QUEUE_NAME$HOST | md5sum | awk '{print $1}'`
CHECK=`/opt/nagios/custom-plugins/check_jmx -U service:jmx:rmi:///jndi/rmi://$HOST/jmxrmi -O org.apache.activemq:type=Broker,brokerName=localhost,destinationType=Queue,destinationName=$QUEUE_NAME -A QueueSize -w 90 -c 100 --username admin --password activemq | awk '{print $6}'`


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

# only if the file exists will PREV be set
if [[ -e "/tmp/$TMP_FILE_NAME.nagios" ]]; then
  PREV=`cat /tmp/$TMP_FILE_NAME.nagios`
else
  PREV=0
fi

# Check if the return of the check contains characters and exit if it does
if [[ $CHECK =~ ^[0-9]+$ ]]; then
    CUR=$CHECK
else
    RETVAL=2
    RETSTR="Check contains non-integer characters"
    echo $RETSTR
    exit $RETVAL
fi

# check if PREV and CUR have values
if [[ $CUR -lt 5 ]]; then
  RETSTR="OKAY: JMX Queue Size is $CUR | Queue_Size=$CUR"
	RETVAL=0
elif [[ $CUR -eq 0 && $PREV -eq 0 ]]; then
	RETSTR="OKAY: JMX Queue Size is 0 | Queue_Size=$CUR"
	RETVAL=0
elif [[ $CUR -ne $PREV ]]; then
  	RETSTR="WARN: JMX Queue Size is changing and is currently $CUR, a push must be going out | Queue_Size=$CUR"
  	RETVAL=1
elif [[ $CUR -eq $PREV ]]; then
  	RETSTR="CRIT: JMX Queue Size Hasn't Changed for a While, and is currently $CUR , Login to $HOST | Queue_Size=$CUR"
  	RETVAL=2
else
	RETSTR="Unknown Error with the queue, check the Nagios script $0"
	RETVAL=2
fi

echo $RETSTR
# write out CUR to TEMP
echo $CUR > /tmp/$TMP_FILE_NAME.nagios

exit $RETVAL
