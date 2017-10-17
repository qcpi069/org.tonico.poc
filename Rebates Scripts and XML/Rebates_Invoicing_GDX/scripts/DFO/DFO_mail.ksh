#!/usr/bin/ksh

if [[ $# != 3 ]] then

   echo "`date +'%b %d, %Y %H:%M:%S'` Error: Inaccurate parameters" \
        "supplied to script 'DFO_mail.ksh'"

   exit 100

fi

MAILTO="$1"
MAIL_SUBJECT="$2"
MAILFILE="$3"

mail -s "$MAIL_SUBJECT" $MAILTO < $MAILFILE

if [[ $? != 0 ]] then

   echo "Mail cound not be sent......."
   exit 100

fi
