#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCWK1000_KC_1015J_t_claim_alv_net_rpt.ksh   
# Title         : Pre-gather t_claim_alv net report table.
#
# Description   : This report is the net counts that we expect in SCR from the dwcorp.t_claim_alv table.  
# Maestro Job   : KC_1015J
#
# Parameters    : N/A
#		  
# Input         : This script gets the cycle_gid from the pre-gather report control file 
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-05-2004  N. Tucker   Initial Creation.
# 09-15-05    Castillo   Modifications for Rebates Integration Phase 2
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

# for testing
#. /staging/apps/rebates/prod/scripts/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
	export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
else  
	export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
fi

SCHEDULE="KCWK1000"
JOB="KC_1015J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_t_claim_alv_net_rpt"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
SQL_FILE=$FILE_BASE".sql"
SQL_FILE_DATE_CNTRL=$FILE_BASE"_date_cntrl.sql"
DAT_FILE=$FILE_BASE".dat"
FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
CTRL_FILE="rbate_pre_gather_rpt_control_file_init.dat"
FTP_NT_IP=AZSHISP00

# Use this alias to print out the filename and line number an error occurred on
alias print_err='print "[$SCRIPTNAME:$LINENO]"'

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$FTP_CMDS

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#

print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE
print "Starting " $SCRIPTNAME                                                   >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# read the cntl file and execute sql for each cycle_gid 
#-------------------------------------------------------------------------#
# variable names to set in read command
READ_VARS="
	CYCLE_GID
	CYCLE_START_DATE
	CYCLE_END_DATE
	JUNK
"
while read $READ_VARS; do
	
	print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
	print "Control file record read from " $OUTPUT_PATH/$CTRL_FILE               >> $OUTPUT_PATH/$LOG_FILE
	print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
	print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
	print "Values are:"                                                          >> $OUTPUT_PATH/$LOG_FILE
	print "CYCLE_GID = " $CYCLE_GID                                              >> $OUTPUT_PATH/$LOG_FILE
	print "CYCLE_START_DATE = " $CYCLE_START_DATE                                >> $OUTPUT_PATH/$LOG_FILE
	print "CYCLE_END_DATE = " $CYCLE_END_DATE                                    >> $OUTPUT_PATH/$LOG_FILE
	
	export DAT_FILE=$FILE_BASE'_'$CYCLE_GID'.dat'
	export FILE_OUT=$DAT_FILE
	
	rm -f $INPUT_PATH/$SQL_FILE
	rm -f $OUTPUT_PATH/$DAT_FILE
	
	print "Output file for " $CYCLE_GID " is " $OUTPUT_PATH/$DAT_FILE            >> $OUTPUT_PATH/$LOG_FILE

	cat > $INPUT_PATH/$SQL_FILE <<- EOF
		SET LINESIZE 80
		SET TERMOUT OFF
		SET PAGESIZE 0
		SET NEWPAGE 0
		SET SPACE 0
		SET ECHO OFF
		SET FEEDBACK OFF
		SET HEADING OFF
		SET WRAP OFF
		set verify off
		whenever sqlerror exit 1
		SPOOL $OUTPUT_PATH/$DAT_FILE
		alter session enable parallel dml
		
		SELECT /*+ full(a1) parallel(a1,10) */ 
			a1.feed_id
			,','
			,a2.extnl_src_code   
			,','
			,to_char(a1.batch_date,'Month') 
			,','
			,count(a1.claim_gid)
		FROM DWCORP.t_claim_alv a1, DMA_RBATE2.v_batch@dwcorp_reb a2 
		WHERE
			a1.batch_date BETWEEN to_date('$CYCLE_START_DATE','MMDDYYYY')
				AND to_date('$CYCLE_END_DATE','MMDDYYYY')
			AND a1.batch_gid = a2.batch_gid(+)
			AND a2.extnl_src_code != 'NOREB'
			AND a1.claim_type != 0
		GROUP BY a1.FEED_ID, a2.extnl_src_code, to_char(a1.batch_date,'Month')
		ORDER BY a1.FEED_ID; 
		
		quit; 

	EOF

	$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE            >> $OUTPUT_PATH/$LOG_FILE
	export RETCODE=$?

	print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
	print "SQLPlus complete for " $CYCLE_GID                                     >> $OUTPUT_PATH/$LOG_FILE
	print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
	print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE

	#-------------------------------------------------------------------------#
	# Check for good return from sqlplus.                  
	#-------------------------------------------------------------------------#
	
	if [[ $RETCODE != 0 ]]; then
		print_err "SQLPlus Error ($RETCODE)"                                      >> $OUTPUT_PATH/$LOG_FILE
		print "                                                                 " >> $OUTPUT_PATH/$LOG_FILE
		print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
		print "  Error Executing " $SCRIPT_PATH/$SCRIPTNAME                       >> $OUTPUT_PATH/$LOG_FILE
		print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
		print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
		
		cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
		exit $RETCODE
	fi

	#-------------------------------------------------------------------------#
	# FTP the report to an NT server                  
	#-------------------------------------------------------------------------#

	print 'Creating FTP command for PUT ' $OUTPUT_PATH/$FILE_OUT ' to ' $FTP_NT_IP >> $OUTPUT_PATH/$LOG_FILE
	print 'cd /'$REBATES_DIR                                                     >> $OUTPUT_PATH/$FTP_CMDS
	print 'put ' $OUTPUT_PATH/$FILE_OUT $FILE_OUT ' (replace'                    >> $OUTPUT_PATH/$FTP_CMDS

done < $OUTPUT_PATH/$CTRL_FILE

print 'quit'                                                                    >> $OUTPUT_PATH/$FTP_CMDS
print " "                                                                       >> $OUTPUT_PATH/$LOG_FILE
print "....Executing FTP  ...."                                                 >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
ftp -v -i $FTP_NT_IP < $OUTPUT_PATH/$FTP_CMDS                                   >> $OUTPUT_PATH/$LOG_FILE
RETCODE=$?
print ".... FTP complete   ...."                                                >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE


if [[ $RETCODE != 0 ]]; then
	print_err "SQLPlus Error ($RETCODE)"                                        >> $OUTPUT_PATH/$LOG_FILE
	print "                                                                 "   >> $OUTPUT_PATH/$LOG_FILE
	print "===================== J O B  A B E N D E D ======================"   >> $OUTPUT_PATH/$LOG_FILE
	print "  Error in FTP of " $OUTPUT_PATH/$FTP_CMDS                           >> $OUTPUT_PATH/$LOG_FILE
	print "  Look in " $OUTPUT_PATH/$LOG_FILE                                   >> $OUTPUT_PATH/$LOG_FILE
	print "================================================================="   >> $OUTPUT_PATH/$LOG_FILE
	
	cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
	exit $RETCODE
fi

#-------------------------------------------------------------------------#
# Copy the log file over and end the job                  
#-------------------------------------------------------------------------#

print " "                                                                       >> $OUTPUT_PATH/$LOG_FILE
print "....Completed executing " $SCRIPT_PATH/$SCRIPTNAME " ...."               >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`

exit $RETCODE

