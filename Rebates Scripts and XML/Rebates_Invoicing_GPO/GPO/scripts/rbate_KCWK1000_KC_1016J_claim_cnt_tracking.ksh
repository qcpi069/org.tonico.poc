#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCWK1000_KC_1016J_claim_cnt_tracking.ksh   
#
# Description   : This script updates the edw rxclaim and ruc counts on the
#		   claim_sum_cnt table. These totals are on the 'Quarterly 
#	           Claim Totals' and 'Summary by exception Id' reports.  
#
# Maestro Job   : KC_1016J
#
# Parameters    : N/A
#         
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#                  
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09/15/04  N. Tucker   Initial Creation.
# 08/22/05  N. Tucker	Change select to views for Oracle 10g update
# 09-15-05    Castillo   Modifications for Rebates Integration Phase 2
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
	REBATES_DIR=rebates_integration
	REPORT_DIR=reporting_prod/rebates/data
else 
	REBATES_DIR=rebates_integration
	REPORT_DIR=reporting_test/rebates/data
fi

SCHEDULE="KCWK1000"
JOB="KC_1016J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_claim_cnt_tracking"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
SQL_LOG_FILE=$FILE_BASE".sqllog"
SQL_FILE=$FILE_BASE".sql"
SQL_FILE_CYCLE=$FILE_BASE"_cycle.sql"
CLAIM_SUM_CYCLE_CNTL=$FILE_BASE"_claim_sum_cycle_cntl.dat"

RETCODE=0
RBATE_CYCLE_MONTHLY_TYPE=1
RBATE_CYCLE_QUARTERLY_TYPE=2

# Use this alias to print out the filename and line number an error occurred on
alias print_err='print "[$SCRIPTNAME:$LINENO]"'

#----------------------------------
# What to do when exiting the script
#----------------------------------
function exit_script {
	typeset _RETCODE=$1
	if [[ -z $_RETCODE ]]; then
		_RETCODE=0
	fi
	if [[ $_RETCODE != 0 ]]; then
		print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
		print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
		print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
		print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
		print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
		
		# Send the Email notification 
		export JOBNAME=$SCHEDULE/$JOB
		export LOGFILE=$OUTPUT_PATH/$LOG_FILE
		export EMAILPARM4="  "
		export EMAILPARM5="  "
		
		print "Sending email notification with the following parameters" >> $OUTPUT_PATH/$LOG_FILE
		print "JOBNAME is " $JOB                                         >> $OUTPUT_PATH/$LOG_FILE 
		print "SCRIPTNAME is " $SCRIPTNAME                               >> $OUTPUT_PATH/$LOG_FILE
		print "LOGFILE is " $LOGFILE                                     >> $OUTPUT_PATH/$LOG_FILE
		print "EMAILPARM4 is " $EMAILPARM4                               >> $OUTPUT_PATH/$LOG_FILE
		print "EMAILPARM5 is " $EMAILPARM5                               >> $OUTPUT_PATH/$LOG_FILE
		print "****** end of email parameters ******"                    >> $OUTPUT_PATH/$LOG_FILE

		. $SCRIPT_PATH/rbate_email_base.ksh
		cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
		exit $_RETCODE
	else
		print " "                                 >> $OUTPUT_PATH/$LOG_FILE
		print "Successfully completed job " $JOB  >> $OUTPUT_PATH/$LOG_FILE 
		print "Script " $SCRIPTNAME               >> $OUTPUT_PATH/$LOG_FILE
		print `date`                              >> $OUTPUT_PATH/$LOG_FILE

		mv -f  $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
		exit $_RETCODE
	fi
}


rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$SQL_LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $INPUT_PATH/$SQL_FILE_CYCLE
rm -f $OUTPUT_PATH/$CLAIM_SUM_CYCLE_CNTL

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Write a file out of the cycle_gid we need to process  
# 
#-------------------------------------------------------------------------#

print " "                           >> $OUTPUT_PATH/$LOG_FILE
print `date`                        >> $OUTPUT_PATH/$LOG_FILE
print "Building cycle cntl File "   >> $OUTPUT_PATH/$LOG_FILE
print " "                           >> $OUTPUT_PATH/$LOG_FILE

cat > $INPUT_PATH/$SQL_FILE_CYCLE <<- EOF
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
	SPOOL $OUTPUT_PATH/$CLAIM_SUM_CYCLE_CNTL
	alter session enable parallel dml; 
	
	SELECT 
		rbate_cycle_gid
		,' '
		,to_char(cycle_start_date,'MMDDYYYY')
		,' '
		,to_char(cycle_end_date,'MMDDYYYY')
		,' '
		,alv_refresh_ind
		,' '
		,rxc_refresh_ind
		,' '
		,ruc_refresh_ind
	FROM dma_rbate2.t_rbate_cycle a 
	WHERE
		rbate_cycle_status = upper('A')
		AND rbate_cycle_type_id = $RBATE_CYCLE_MONTHLY_TYPE;
	
	quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE_CYCLE
RETCODE=$?

if [[ $RETCODE = 0  ]]; then
	print " " 							    		           >> $OUTPUT_PATH/$LOG_FILE
	print `date` "Completed getting the cycle_gid and dates. " >> $OUTPUT_PATH/$LOG_FILE
	print " " 							    		           >> $OUTPUT_PATH/$LOG_FILE
else   
	print_err "SQLPlus Error ($RETCODE)"       >> $OUTPUT_PATH/$LOG_FILE
	print " "                                  >> $OUTPUT_PATH/$LOG_FILE
	print "Failure getting the cycle_gid "     >> $OUTPUT_PATH/$LOG_FILE
	print "Oracle RETURN CODE is : " $RETCODE  >> $OUTPUT_PATH/$LOG_FILE
	print " "                                  >> $OUTPUT_PATH/$LOG_FILE
	exit_script $RETCODE
fi

READ_VARS="
	CYCLE_GID
	CYCLE_BEG_DT
	CYCLE_END_DT
	ALV_FLAG
	RXC_FLAG
	RUC_FLAG
	JUNK
"
while read $READ_VARS; do

	# Create a row in DMA_RBATE2.T_CLAIM_SUM_CNT if there isn't one.
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
		alter session enable parallel dml;

		INSERT INTO DMA_RBATE2.T_CLAIM_SUM_CNT (
			SELECT $CYCLE_GID,
				NULL, NULL, NULL, NULL,
				NULL, NULL, NULL, NULL,
				NULL, NULL, NULL, NULL,
				NULL, NULL, NULL, NULL, NULL
			FROM DUAL
			WHERE NOT EXISTS (
				SELECT CYCLE_GID
				FROM DMA_RBATE2.T_CLAIM_SUM_CNT
				WHERE CYCLE_GID = $CYCLE_GID)
		);
		quit
	EOF
	cat < $INPUT_PATH/$SQL_FILE >> $OUTPUT_PATH/$LOG_FILE
	$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE >> $OUTPUT_PATH/$LOG_FILE
	RETCODE=$?
	if [[ $RETCODE != 0 ]]; then
		print_err "SQLPlus Error ($RETCODE)"           >> $OUTPUT_PATH/$LOG_FILE
		print " "                                      >> $OUTPUT_PATH/$LOG_FILE
		print "Failure in update of t_claim_sum_cnt "  >> $OUTPUT_PATH/$LOG_FILE
		print "Oracle RETURN CODE is : " $RETCODE      >> $OUTPUT_PATH/$LOG_FILE
		print " "                                      >> $OUTPUT_PATH/$LOG_FILE
		exit_script $RETCODE
	fi


	# QL is done whenever RUC is
	QLC_FLAG=$RUC_FLAG
	
	#-------------------------------------------------------------------------#
	# Remove the previous SQL, then build and EXEC the new SQL.               
	#                                                                         
	#-------------------------------------------------------------------------#
	rm -f $INPUT_PATH/$SQL_FILE
	
	print "Begin Date is     "$CYCLE_BEG_DT   >> $OUTPUT_PATH/$LOG_FILE
	print "End Date is       "$CYCLE_END_DT   >> $OUTPUT_PATH/$LOG_FILE
	print "ALV flag value is "$ALV_FLAG       >> $OUTPUT_PATH/$LOG_FILE
	print "RXC flag value is "$RXC_FLAG       >> $OUTPUT_PATH/$LOG_FILE
	print "RUC flag value is "$RUC_FLAG       >> $OUTPUT_PATH/$LOG_FILE
	print "QLC flag value is "$QLC_FLAG       >> $OUTPUT_PATH/$LOG_FILE
	
	#### GET THE RXC COUNTS ####
	if [[ $RXC_FLAG = "Y"  ]]; then
		
		print " "                               >> $OUTPUT_PATH/$LOG_FILE
		print "RXC flag is Y; Updating counts " >> $OUTPUT_PATH/$LOG_FILE
		print " "                               >> $OUTPUT_PATH/$LOG_FILE

		cat > $INPUT_PATH/$SQL_FILE <<- EOF
			whenever sqlerror exit 1
			set timing on;
			
			SPOOL $OUTPUT_PATH/$SQL_LOG_FILE
			alter session enable parallel dml;
			
			UPDATE dma_rbate2.t_claim_sum_cnt a 
			SET a.rxc_paid_rvrsd_cnt = (
				SELECT 
					COUNT(A1.claim_gid) claim_cnt
				FROM dma_rbate2.v_claim_sum_cnt_rxc@dwcorp_reb A1
				WHERE A1.batch_date BETWEEN to_date('$CYCLE_BEG_DT','MMDDYYYY')
					AND to_date('$CYCLE_END_DT','MMDDYYYY')
			)
			WHERE a.cycle_gid = $CYCLE_GID;
			
			COMMIT;
			
			quit;
		EOF

		$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE
		RETCODE=$?

		cat $OUTPUT_PATH/$SQL_LOG_FILE >> $OUTPUT_PATH/$LOG_FILE


		if [[ $RETCODE = 0 ]]; then
			print " "                                                               >> $OUTPUT_PATH/$LOG_FILE
			print `date` "Update of rxc T_CLAIM_SUM_CNT successful for " $CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE
		else   
			print_err "SQLPlus Error ($RETCODE)"           >> $OUTPUT_PATH/$LOG_FILE
			print " "                                      >> $OUTPUT_PATH/$LOG_FILE
			print "Failure in update of scr sum counts "   >> $OUTPUT_PATH/$LOG_FILE
			print "Oracle RETURN CODE is : " $RETCODE      >> $OUTPUT_PATH/$LOG_FILE
			print " "                                      >> $OUTPUT_PATH/$LOG_FILE
			exit_script $RETCODE
		fi
	fi

	#### GET THE RUC COUNTS ####
	if [[ $RUC_FLAG = "Y"  ]]; then

		print " "                                >> $OUTPUT_PATH/$LOG_FILE
		print "RUC flag is Y; Updating counts "  >> $OUTPUT_PATH/$LOG_FILE
		print " "                                >> $OUTPUT_PATH/$LOG_FILE
		
		cat > $INPUT_PATH/$SQL_FILE <<- EOF
			
			whenever sqlerror exit 1
			set timing on;
			
			SPOOL $OUTPUT_PATH/$SQL_LOG_FILE
			alter session enable parallel dml;
	
			UPDATE dma_rbate2.t_claim_sum_cnt a 
			SET (a.ruc_paid_rvrsd_cnt, a.ruc_noreb_cnt) = (
				SELECT 
					COUNT(A1.claim_gid) claim_cnt
					,SUM(CASE WHEN A1.extnl_src_code = 'NOREB' THEN 1 ELSE 0 END) count_noreb 
				FROM dma_rbate2.v_claim_sum_cnt_ruc@dwcorp_reb A1
				WHERE
					A1.batch_date BETWEEN to_date('$CYCLE_BEG_DT','MMDDYYYY')
						AND to_date('$CYCLE_END_DT','MMDDYYYY')
			)
			WHERE a.cycle_gid = $CYCLE_GID;
			
			COMMIT;
			
			quit;
		EOF

		$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE
		RETCODE=$?

		cat $OUTPUT_PATH/$SQL_LOG_FILE  >> $OUTPUT_PATH/$LOG_FILE

		if [[ $RETCODE = 0  ]]; then
			print " "                                                               >> $OUTPUT_PATH/$LOG_FILE
		   print `date` "Update of ruc T_CLAIM_SUM_CNT successful for " $CYCLE_GID  >> $OUTPUT_PATH/$LOG_FILE
		else   
			print_err "SQLPlus Error ($RETCODE)"           >> $OUTPUT_PATH/$LOG_FILE
			print " "                                      >> $OUTPUT_PATH/$LOG_FILE
			print "Failure in update of scr sum counts "   >> $OUTPUT_PATH/$LOG_FILE
			print "Oracle RETURN CODE is : " $RETCODE      >> $OUTPUT_PATH/$LOG_FILE
			print " "                                      >> $OUTPUT_PATH/$LOG_FILE
			exit_script $RETCODE
		fi
	fi


	#### GET THE QLC COUNTS ####
	if [[ $QLC_FLAG = "Y"  ]]; then

		print " "                                >> $OUTPUT_PATH/$LOG_FILE
		print "QLC flag is Y; Updating counts "  >> $OUTPUT_PATH/$LOG_FILE
		print " "                                >> $OUTPUT_PATH/$LOG_FILE
		
		cat > $INPUT_PATH/$SQL_FILE <<- EOF
			
			whenever sqlerror exit 1
			set timing on;
			
			SPOOL $OUTPUT_PATH/$SQL_LOG_FILE
			alter session enable parallel dml;

			UPDATE dma_rbate2.t_claim_sum_cnt a 
			SET (a.qlc_paid_rvrsd_cnt) = (
				SELECT COUNT(A1.claim_gid) claim_cnt
				FROM dma_rbate2.v_claim_sum_cnt_ql@dwcorp_reb A1
				WHERE
					(A1.batch_date BETWEEN ADD_MONTHS(TO_DATE('$CYCLE_BEG_DT','MMDDYYYY'), -1)
						AND ADD_MONTHS(TO_DATE('$CYCLE_END_DT','MMDDYYYY'), 1))
					AND (A1.inv_elig_dt BETWEEN TO_DATE('$CYCLE_BEG_DT','MMDDYYYY')
						AND TO_DATE('$CYCLE_END_DT','MMDDYYYY'))
			)
			WHERE a.cycle_gid = $CYCLE_GID;
			
			COMMIT;
			
			quit;
		EOF

		$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE
		RETCODE=$?

		cat $OUTPUT_PATH/$SQL_LOG_FILE  >> $OUTPUT_PATH/$LOG_FILE

		if [[ $RETCODE = 0  ]]; then
			print " "                                                               >> $OUTPUT_PATH/$LOG_FILE
		   print `date` "Update of qlc T_CLAIM_SUM_CNT successful for " $CYCLE_GID  >> $OUTPUT_PATH/$LOG_FILE
		else   
			print_err "SQLPlus Error ($RETCODE)"           >> $OUTPUT_PATH/$LOG_FILE
			print " "                                      >> $OUTPUT_PATH/$LOG_FILE
			print "Failure in update of scr sum counts "   >> $OUTPUT_PATH/$LOG_FILE
			print "Oracle RETURN CODE is : " $RETCODE      >> $OUTPUT_PATH/$LOG_FILE
			print " "                                      >> $OUTPUT_PATH/$LOG_FILE
			exit_script $RETCODE
		fi
	fi
	

	#### GET THE RECAP COUNTS ####
	if [[ $ALV_FLAG = "Y"  ]]; then
		print " "                                >> $OUTPUT_PATH/$LOG_FILE
		print "ALV flag is Y; Updating counts "  >> $OUTPUT_PATH/$LOG_FILE
		print " "                                >> $OUTPUT_PATH/$LOG_FILE
	
		cat > $INPUT_PATH/$SQL_FILE <<- EOF
			whenever sqlerror exit 1
			set timing on;
			
			SPOOL $OUTPUT_PATH/$SQL_LOG_FILE
			alter session enable parallel dml;
			
			UPDATE dma_rbate2.t_claim_sum_cnt a 
			SET (a.alv_paid_rvrsd_cnt, a.alv_noreb_cnt) = (
				SELECT 
					count(A1.claim_gid) claim_cnt
					,sum(CASE WHEN A1.extnl_src_code = 'NOREB' THEN 1 ELSE 0 END) count_noreb 
				FROM dma_rbate2.v_claim_sum_cnt_alv@dwcorp_reb A1         
				WHERE A1.batch_date BETWEEN to_date('$CYCLE_BEG_DT','MMDDYYYY')
										 AND to_date('$CYCLE_END_DT','MMDDYYYY')
			)
			WHERE a.cycle_gid = $CYCLE_GID;
			
			COMMIT;
			
			quit;
		EOF

		$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE
		RETCODE=$?

		cat $OUTPUT_PATH/$SQL_LOG_FILE  >> $OUTPUT_PATH/$LOG_FILE

		if [[ $RETCODE = 0  ]]; then
			print " "                                                                >> $OUTPUT_PATH/$LOG_FILE
			print `date` "Update of alv T_CLAIM_SUM_CNT successful for " $CYCLE_GID  >> $OUTPUT_PATH/$LOG_FILE
		else   
			print_err "SQLPlus Error ($RETCODE)"           >> $OUTPUT_PATH/$LOG_FILE
			print " "                                      >> $OUTPUT_PATH/$LOG_FILE
			print "Failure in update of scr sum counts "   >> $OUTPUT_PATH/$LOG_FILE
			print "Oracle RETURN CODE is : " $RETCODE      >> $OUTPUT_PATH/$LOG_FILE
			print " "                                      >> $OUTPUT_PATH/$LOG_FILE
			exit_script $RETCODE
		fi
	fi


done < $OUTPUT_PATH/$CLAIM_SUM_CYCLE_CNTL

exit_script $RETCODE


