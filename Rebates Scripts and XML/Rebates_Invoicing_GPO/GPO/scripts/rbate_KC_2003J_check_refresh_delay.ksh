#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KC_2003J_check_refresh_delay.ksh
#
# Description   : Sends an email out of the RXLives feed is not ready.
#
# Parameters    : None. 
#
# Output        :  
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09/21/2005 Castillo    Initial script.

#uncomment below for debugging
#set -x

. "$(dirname $0)/rebates_env.ksh"


RETCODE=0
SCRIPTNAME=$(basename $0)
FILE_BASE=${SCRIPTNAME%.ksh}
LOG_FILE=$FILE_BASE'.log'
ARCH_LOG_FILE=$FILE_BASE'.log.'$(date +'%Y%j%H%M')
RXLIVES_TRIGGER_FILE=$INPUT_PATH/monthly_rxlives_done.trg
ABS_SCRIPTNAME=$(ksh -c "cd $(dirname $0); pwd")"/$SCRIPTNAME"

if [[ $REGION = 'prod' ]]; then
	if [[ $QA_REGION = 'true' ]]; then
		EMAIL_ADDRESSES='GDXITD@caremark.com'
	else
		EMAIL_ADDRESSES='GDXITD@caremark.com,8884302503@archwireless.net'
	fi
else
		EMAIL_ADDRESSES='bryan.castillo@caremark.com'
fi

rm -f $OUTPUT_PATH/$LOG_FILE
print ' '                             >> $OUTPUT_PATH/$LOG_FILE
print "$(date) Starting $SCRIPTNAME"  >> $OUTPUT_PATH/$LOG_FILE

if [[ ! -f "$RXLIVES_TRIGGER_FILE" ]]; then
	SUBJECT="Error: [$(hostname)] Refresh held up for RXLives feed"
	for ADDRESS in $EMAIL_ADDRESSES; do
		print "Sending mail to [$ADDRESS]" >> $OUTPUT_PATH/$LOG_FILE
		mailx -v -s "$SUBJECT" "$ADDRESS" <<- END_MAIL >> $OUTPUT_PATH/$LOG_FILE
		
			ERROR: Refresh is held up waiting for the RX Lives feed.
			---------------------------------------------------------------
			Script: $ABS_SCRIPTNAME
			Date:   $(date)
			Host:   $(hostname)
			User:   $USER
			Region: $REGION
			QA:     $QA_REGION
			---------------------------------------------------------------
		
			The file [$RXLIVES_TRIGGER_FILE] should have been created.
	
		END_MAIL
		if [[ $? != 0 ]]; then
			print "Mail command failed" >> $OUTPUT_PATH/$LOG_FILE
		fi
	done

	print "$(date) Ending $SCRIPTNAME"    >> $OUTPUT_PATH/$LOG_FILE
	cp $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$ARCH_LOG_FILE
else
	print "Found $RXLIVES_TRIGGER_FILE" >> $OUTPUT_PATH/$LOG_FILE
	ls -l "$RXLIVES_TRIGGER_FILE"       >> $OUTPUT_PATH/$LOG_FILE
	RETCODE=0

	print "$(date) Ending $SCRIPTNAME"    >> $OUTPUT_PATH/$LOG_FILE
	mv $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$ARCH_LOG_FILE
fi

exit $RETCODE

