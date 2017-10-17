#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCWK1000_KC_1018J_mvs_hierarchy_trigger.ksh
#
# Description   : Creates a trigger file which is ftp'd to MVS.
#                 The KSZ7006J job pulls Rebate ID/Hierarchy/LCM data from
#                 the MVS Cross Reference system for RUC and RXC (and now QL).
#                 
# Maestro Job   : KCWK1000/KC_1018J 
#
# Parameters    : None 
#
# Output        : Creates a trigger file which is ftp'd to MVS 
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09-19-05   B. Castillo Initial Creation.
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. "$(dirname $0)/rebates_env.ksh"

RETCODE=0
SCRIPTNAME=$(basename $0)
FILE_BASE="${SCRIPTNAME%.ksh}"
LOG_FILE=$FILE_BASE".log"

FTP_FILE_BASE="KSZ7006J.TRIGGER"
FTP_HOST=
FTP_FILE=

function exit_script {
	typeset _RETCODE=$1
	typeset _ERRMSG="$2"
	if [[ -z $_RETCODE ]]; then
		_RETCODE=0
	fi
	if [[ $_RETCODE != 0 ]]; then
		print ""                                                                  >> $OUTPUT_PATH/$LOG_FILE
		print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
		if [[ -n "$_ERRMSG" ]]; then
				print "  Error Message: $_ERRMSG"                                 >> $OUTPUT_PATH/$LOG_FILE
		fi
		print "  Error Executing " $SCRIPT_PATH/$SCRIPTNAME                       >> $OUTPUT_PATH/$LOG_FILE
		print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
		print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
		cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.$(date +"%Y%j%H%M")
		exit $_RETCODE
	else
		print ""                                                                    >> $OUTPUT_PATH/$LOG_FILE
		print "....Completed executing " $SCRIPT_PATH/$SCRIPTNAME " ...."           >> $OUTPUT_PATH/$LOG_FILE
		print $(date)                                                               >> $OUTPUT_PATH/$LOG_FILE
		print "===================================================================" >> $OUTPUT_PATH/$LOG_FILE
		mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.$(date +"%Y%j%H%M")
		exit $_RETCODE
	fi
}

function run_ftp {
	typeset _FTP_HOST="$1"
	typeset _FTP_COMMANDS=$(cat) # pulls stdin into a variable
	typeset _FTP_OUTPUT=
	typeset _ERROR_COUNT=
	
	print "Transferring to $_FTP_HOST using commands:" >> $OUTPUT_PATH/$LOG_FILE
	print "$_FTP_COMMANDS"                             >> $OUTPUT_PATH/$LOG_FILE
	print ""                                           >> $OUTPUT_PATH/$LOG_FILE
	_FTP_OUTPUT=$(print "$_FTP_COMMANDS" | ftp -i -v $_FTP_HOST)
	RETCODE=$?	
	print "$_FTP_OUTPUT" >> $OUTPUT_PATH/$LOG_FILE
	if [[ $RETCODE != 0 ]]; then
		print "Errors occurred during ftp." >> $OUTPUT_PATH/$LOG_FILE
		exit_script $RETCODE
	fi
	
	# Parse the ftp output for errors
	# 400 and 500 level replies are errors
	# You have to vilter out the bytes sent message
	# it may say something 404 bytes sent and you don't
	# want to mistake this for an error message. 
	_ERROR_COUNT=$(echo "$_FTP_OUTPUT" | egrep -v 'bytes (sent|received)' | egrep -c '^\s*[45][0-9][0-9]')
	if [[ $_ERROR_COUNT -gt 0 ]]; then
		print "Errors occurred during ftp." >> $OUTPUT_PATH/$LOG_FILE
		RETCODE=1
		exit_script $RETCODE
	fi
}

function check_ftp {
	typeset _FTP_COMMANDS=$(cat) # pulls stdin into a variable
	typeset _FTP_OUTPUT=
	typeset _ERROR_COUNT=

	_FTP_OUTPUT=$(print "$_FTP_COMMANDS" | ftp )
	typeset _RETCODE=$?	
	if [[ $_RETCODE != 0 ]]; then
		return $_RETCODE
	fi
	
	# Parse the ftp output for errors
	# 400 and 500 level replies are errors
	# You have to vilter out the bytes sent message
	# it may say something 404 bytes sent and you don't
	# want to mistake this for an error message. 
	_ERROR_COUNT=$(echo "$_FTP_OUTPUT" | egrep -v 'bytes (sent|received)' | egrep -c '^\s*[45][0-9][0-9]')
	if [[ $_ERROR_COUNT -gt 0 ]]; then
		return $_ERROR_COUNT
	fi

	return 0
}


if [[ "$REGION" = "prod" ]]; then
	if [[ "$QA_REGION" = "true" ]]; then
		FTP_HOST=
		FTP_FILE="TEST.X.${FTP_FILE_BASE}"
	else
		FTP_HOST=phxn3
		FTP_FILE="PCS.P.${FTP_FILE_BASE}"
	fi
else
	FTP_HOST=phxn2
	FTP_FILE="TEST.D.${FTP_FILE_BASE}"
fi


rm -f $OUTPUT_PATH/$LOG_FILE
print "\n$(date) Starting $SCRIPTNAME\n\n" >> $OUTPUT_PATH/$LOG_FILE

# Create the trigger file
cat > $OUTPUT_PATH/$FTP_FILE <<-END_TXT
	--------------------------------------------
	File Name: $FTP_FILE
	Script:    $SCRIPTNAME
	Created:   $(date)
	Host:      $(hostname)		
	--------------------------------------------

	This trigger file is meant to trigger the MVS KSZ7006J job.
	The KSZ7006J job pulls Rebate ID/Hierarchy/LCM data from
	the MVS Cross Reference system for RUC and RXC (and now QL).

END_TXT


if [[ -z "$FTP_HOST" ]]; then
	print "Warning: no FTP_HOST was defined." >> $OUTPUT_PATH/$LOG_FILE
else
	run_ftp "$FTP_HOST" <<-END_FTP
		put $OUTPUT_PATH/$FTP_FILE '$FTP_FILE'
		dir '$FTP_FILE'
		bye
	END_FTP
fi

exit_script $RETCODE

