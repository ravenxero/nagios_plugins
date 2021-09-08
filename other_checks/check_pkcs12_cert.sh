#!/bin/bash
#
# Check pkcs12 certs for expiration
#
# Usage: check_pkcs12_cert.sh <cert_file> <password> <crit_days> <warn_days>
#
# (c) 2021, David Pickwell
# https://github.com/ravenxero/nagios_plugins
#

if [ $# -ne 4 ]; then
  printf "You didn't pass enough arguments!\n\nUsage: $0 <cert_file> <password> <crit_days> <warn_days> \n"
  exit 127
fi

# Set some variables
CERT_FILE=$1
PASSWORD=$2
let SECS_CRIT=$3*86400
let SECS_WARN=$4*86400

# Get the TimeDate for the expiration of the Certificate
CERT_DATETIME=`openssl pkcs12 -in ${CERT_FILE} -nokeys -passin pass:${PASSWORD} | openssl x509 -noout -enddate | awk -F '=' '{print $2}'`

# Calculate the time (in secs) until the expiration, cos it's easier in unix time.
let DIFF_SECS=`date --date="${CERT_DATETIME}" --utc +"%s"`-`date --utc +"%s"`

# Calculate the time (in days) until the expiration, cos people can't read unix time.
let TIME_LEFT=${DIFF_SECS}/86400

# Do some logical calculations.
if [[ ${DIFF_SECS} -le ${SECS_CRIT} ]]
then
  RETVAL=2
  RETSTR="CRIT: Certificate ${CERT_FILE} will expire in ${TIME_LEFT} day(s)"
elif [[ ${DIFF_SECS} -le ${SECS_WARN} ]]
then
  RETVAL=1
  RETSTR="WARN: Certificate ${CERT_FILE} will expire in ${TIME_LEFT} day(s)"
elif [[ ${DIFF_SECS} -gt ${SECS_WARN} ]]
then
  RETVAL=0
  RETSTR="OKAY: Certificate ${CERT_FILE} is not close to expiration."
else
  RETVAL=3
  RETSTR="UNKNOWN: Whoops, something bad has happened!"
fi

# Return some stuff to Nagios
echo $RETSTR
exit $RETVAL
