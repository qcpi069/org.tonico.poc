#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCWK1000_KC_1017J_ql_unmatched_billing_entries.ksh
#
# Description   :  
#
# Parameters    : None
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09/21/2005 Castillo    Initial script.

. "$(dirname $0)/rebates_env.ksh"

# This variable should contain all of the hosts to transfer the file to
# Each line in the variable has 2 tokens the remote host and directory.
FTP_CONFG=""

if [[ $REGION = 'prod' ]]; then
	if [[ $QA_REGION = 'false' ]]; then  
		ALTER_EMAIL_ADDRESS=''
		FTP_CONFIG="
			r07prd01	/GDX/$REGION/input
			r07prd02	/actuate7/DSC/gather_rpts
			AZSHISP00	/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
		"
	else
		ALTER_EMAIL_ADDRESS=''
		FTP_CONFIG="
			r07tst07	/GDX/test/input
			r07prd02	/actuate7/DSC/gather_rpts/qa
			AZSHISP00	/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
		"
	fi
else
	FTP_CONFIG="
		r07tst07	/GDX/test/input
		localhost	.
	"
fi

RETCODE=0
SCRIPTNAME=$(basename $0)
FILE_BASE=${SCRIPTNAME%.ksh}
LOG_FILE=$FILE_BASE'.log'
ARCH_LOG_FILE=$FILE_BASE'.log.'$(date +'%Y%j%H%M')
SQL_FILE=$FILE_BASE'.sql'
DAT_FILE=$FILE_BASE".dat"


#----------------------------------
# What to do when exiting the script
#----------------------------------
function exit_script {
	typeset _RETCODE=$1
	typeset _ERRMSG="$2"
	if [[ -z $_RETCODE ]]; then
		_RETCODE=0
	fi
	if [[ $_RETCODE != 0 ]]; then
		print "                                                                 " >> $OUTPUT_PATH/$LOG_FILE
		print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
		if [[ -n "$_ERRMSG" ]]; then
				print "  Error Message: $_ERRMSG"                                 >> $OUTPUT_PATH/$LOG_FILE
		fi
		print "  Error Executing " $SCRIPT_PATH/$SCRIPTNAME                       >> $OUTPUT_PATH/$LOG_FILE
		print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
		print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
		cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
		exit $_RETCODE
	else
		print " "                                                                   >> $OUTPUT_PATH/$LOG_FILE
		print "....Completed executing " $SCRIPT_PATH/$SCRIPTNAME " ...."           >> $OUTPUT_PATH/$LOG_FILE
		print `date`                                                                >> $OUTPUT_PATH/$LOG_FILE
		print "===================================================================" >> $OUTPUT_PATH/$LOG_FILE
		mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
		exit $_RETCODE
	fi
}


#----------------------------------
# Main
#----------------------------------
rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$FILE_BASE.dat.*
rm -f $INPUT_PATH/$SQL_FILE

print ' '                             >> $OUTPUT_PATH/$LOG_FILE
print "$(date) starting $SCRIPTNAME"  >> $OUTPUT_PATH/$LOG_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------
db_user_password=`cat $SCRIPT_PATH/ora_user.fil`


cat > $INPUT_PATH/$SQL_FILE <<- EOF
	set LINESIZE 80
	set TERMOUT OFF
	set PAGESIZE 0
	set NEWPAGE 0
	set SPACE 0
	set ECHO OFF
	set FEEDBACK OFF
	set HEADING OFF
	set WRAP off
	set verify off
	whenever sqlerror exit 1
	SPOOL $OUTPUT_PATH/$DAT_FILE
	alter session enable parallel dml;

	SELECT BILL_DT || ',' || COUNT
	FROM DMA_RBATE2.V_UMTCH_QL_CLAIM@dwcorp_reb;
	
	quit;
EOF

cat $INPUT_PATH/$SQL_FILE >> $OUTPUT_PATH/$LOG_FILE
$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE >> $OUTPUT_PATH/$LOG_FILE
RETCODE=$?
if [[ $RETCODE != 0 ]] ; then
	print 'SQLPlus FAILED - error message is: ' >> $OUTPUT_PATH/$LOG_FILE
	print ' '                                   >> $OUTPUT_PATH/$LOG_FILE
	tail -20 $OUTPUT_PATH/$DAT_FILE             >> $OUTPUT_PATH/$LOG_FILE
	exit_script $RETCODE 'SQLPlus Error'
fi

# FTP the files
# Read non-empty lines from FTP_CONFIG
print "$FTP_CONFIG" | while read FTP_HOST FTP_DIR; do
	if [[ -z $FTP_HOST ]]; then
		continue
	fi
	print "Transfering $OUTPUT_PATH/$DAT_FILE to [$FTP_HOST] [$FTP_DIR]" >> $OUTPUT_PATH/$LOG_FILE
	
	# Build variable containing commands
	FTP_CMDS=$(
		if [[ -n $FTP_DIR ]]; then
			print "cd $FTP_DIR"
		fi
		print "put $OUTPUT_PATH/$DAT_FILE $DAT_FILE"
		print "bye"
	)
	
	# Perform the FTP
	print "Ftp commands:\n$FTP_CMDS\n" >> $OUTPUT_PATH/$LOG_FILE
	FTP_OUTPUT=$(print "$FTP_CMDS" | ftp -vi "$FTP_HOST")
	RETCODE=$?
	
	# Parse the output for 400 & 500 level FTP reply (error) codes
	ERROR_COUNT=$(print "$FTP_OUTPUT" | egrep -v 'bytes (sent|received)' | egrep -c '^\s*[45][0-9][0-9]')
	print "$FTP_OUTPUT" >> $OUTPUT_PATH/$LOG_FILE

	if [[ $RETCODE != 0 ]] ; then
		print 'FTP FAILED' >> $OUTPUT_PATH/$LOG_FILE
		exit_script $RETCODE 'FTP Error'
	fi
	
	if [[ $ERROR_COUNT -gt 0 ]]; then
		RETCODE=$ERROR_COUNT
		print 'FTP FAILED' >> $OUTPUT_PATH/$LOG_FILE
		exit_script $RETCODE 'FTP Error'
	fi
done

exit_script $RETCODE

