#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCQT6100_KC_6130J_create_claim_sum_rpt.ksh   
#
# Description   : This script creates the file used by Crystal Reports to 
#                 produce the 'Monthly Claim Totals' report.  
#
# Maestro Job   : KC_6130J
#
# Parameters    : N/A
#         
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#                  
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#
#   Date                   Description
# ---------  ------------  -------------------------------------------------#
# 09/16/04    N. Tucker    Initial Creation.
# 06-24-2005  is23301      Oracle 10G change to spool to .lst files.
# 09/06/2005  B. Castillo  Added QLC_OLD_DSPND_DT_CNT & QLC_PAID_RVRSD_CNT

#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
	export REBATES_DIR=rebates_integration
	export REPORT_DIR=reporting_prod/rebates/data
else  
	export REBATES_DIR=rebates_integration
	export REPORT_DIR=reporting_test/rebates/data
fi

export SCHEDULE="KCQT6100"
export JOB="KC_6130J"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_create_claim_sum_rpt"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export SQL_LOG_FILE=$FILE_BASE".sqllog"
export SQL_FILE=$FILE_BASE".sql"
export SQL_FILE_CYCLE=$FILE_BASE"_cycle.sql"
export SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
export FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
export CLAIM_SUM_CYCLE_CNTL="rbate_KCQT6100_KC_6100J_claim_sum_cycle_cntl.dat"
export FTP_NT_IP=AZSHISP00

# Use this alias to print out the filename and line number an error occurred on
alias print_err='print "[$SCRIPTNAME:$LINENO]"'

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$SQL_LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $INPUT_PATH/$SQL_FILE_CYCLE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Perfrom a read loop of the cycle control file 
#-------------------------------------------------------------------------#

print " "                         >> $OUTPUT_PATH/$LOG_FILE
print `date`                      >> $OUTPUT_PATH/$LOG_FILE
print "Reading cycle cntl File "  >> $OUTPUT_PATH/$LOG_FILE
print " "                         >> $OUTPUT_PATH/$LOG_FILE

READ_VARS="
	CYCLE_GID
	CYCLE_BEG_DT
	CYCLE_END_DATE
	JUNK
"
while read $READ_VARS; do
	
	#-------------------------------------------------------------------------#
	# Remove the previous SQL, then build and EXEC the new SQL.               
	#                                                                         
	#-------------------------------------------------------------------------#
	rm -f $INPUT_PATH/$SQL_FILE
	rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
	mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE

	DAT_FILE=$FILE_BASE"_"$CYCLE_GID".dat"
	rm -f $OUTPUT_PATH/$DAT_FILE
	dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE bs=100k &

	cat > $INPUT_PATH/$SQL_FILE <<- EOF
		set LINESIZE 200
		set trimspool on
		set TERMOUT OFF
		set PAGESIZE 0
		set NEWPAGE 0
		set SPACE 0
		set ECHO OFF
		set FEEDBACK OFF
		set HEADING OFF 
		set WRAP off
		set serveroutput off
		set verify off
		whenever sqlerror exit 1
		set timing off;
		
		alter session enable parallel dml;
		
		spool $OUTPUT_PATH/$SQL_PIPE_FILE;
		
		SELECT 
			SUBSTR(TO_CHAR(q.cycle_gid,'000000'),2,6)
			,TO_CHAR(m.rxc_paid_rvrsd_cnt + m.ruc_paid_rvrsd_cnt + m.alv_paid_rvrsd_cnt + m.qlc_paid_rvrsd_cnt, '000000000S')
			,TO_CHAR(m.ruc_noreb_cnt + m.alv_noreb_cnt, '000000000S')
			,TO_CHAR(m.rxc_old_dspnd_dt_cnt + m.ruc_old_dspnd_dt_cnt + m.alv_old_dspnd_dt_cnt + m.qlc_old_dspnd_dt_cnt, '000000000S')
			,NVL(TO_CHAR(q.force_gather_cnt,'000000000S'),'000000000+')
			,NVL(TO_CHAR(q.scr_cnt,'000000000S'),'000000000+')
			,NVL(TO_CHAR(q.scr_excpt_cnt,'00000000S'),'00000000+')
			,NVL(TO_CHAR(q.scrc_cnt,'000000000S'),'000000000+')
			,NVL(TO_CHAR(q.scrc_excpt_cnt,'00000000S'),'00000000+')
			,NVL(TO_CHAR(q.rbated_cnt,'000000000S'),'000000000+')
			,NVL(TO_CHAR(q.submitted_cnt,'000000000S'),'000000000+')
		FROM (
				SELECT *
				FROM DMA_RBATE2.T_CLAIM_SUM_CNT
				WHERE CYCLE_GID = $CYCLE_GID
			) q,
			(	
				SELECT
					NVL(SUM(RXC_PAID_RVRSD_CNT),0) AS RXC_PAID_RVRSD_CNT,
					NVL(SUM(RXC_OLD_DSPND_DT_CNT),0) AS RXC_OLD_DSPND_DT_CNT,
					NVL(SUM(RUC_PAID_RVRSD_CNT),0) AS RUC_PAID_RVRSD_CNT,
					NVL(SUM(RUC_NOREB_CNT),0) AS RUC_NOREB_CNT,
					NVL(SUM(RUC_OLD_DSPND_DT_CNT),0) AS RUC_OLD_DSPND_DT_CNT,
					NVL(SUM(ALV_PAID_RVRSD_CNT),0) AS ALV_PAID_RVRSD_CNT,
					NVL(SUM(ALV_NOREB_CNT),0) AS ALV_NOREB_CNT,
					NVL(SUM(ALV_OLD_DSPND_DT_CNT),0) AS ALV_OLD_DSPND_DT_CNT,
					NVL(SUM(FORCE_GATHER_CNT),0) AS FORCE_GATHER_CNT,
					NVL(SUM(SCR_CNT),0) AS SCR_CNT,
					NVL(SUM(SCR_EXCPT_CNT),0) AS SCR_EXCPT_CNT,
					NVL(SUM(SCRC_CNT),0) AS SCRC_CNT,
					NVL(SUM(SCRC_EXCPT_CNT),0) AS SCRC_EXCPT_CNT,
					NVL(SUM(RBATED_CNT),0) AS RBATED_CNT,
					NVL(SUM(SUBMITTED_CNT),0) AS SUBMITTED_CNT,
					NVL(SUM(QLC_OLD_DSPND_DT_CNT),0) AS QLC_OLD_DSPND_DT_CNT,
					NVL(SUM(QLC_PAID_RVRSD_CNT),0) AS QLC_PAID_RVRSD_CNT
				FROM DMA_RBATE2.T_CLAIM_SUM_CNT
				WHERE CYCLE_GID IN (
					SELECT trc_m.RBATE_CYCLE_GID
					FROM
						DMA_RBATE2.T_RBATE_CYCLE trc_m,
						DMA_RBATE2.T_RBATE_CYCLE trc_q
					WHERE 
						trc_q.RBATE_CYCLE_GID = $CYCLE_GID
						AND trc_m.CYCLE_START_DATE BETWEEN trc_q.CYCLE_START_DATE AND trc_q.CYCLE_END_DATE
						AND trc_m.RBATE_CYCLE_TYPE_ID = 1
				)
			) m
		;
		
				
		quit;
	EOF

	$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE
	ORA_RETCODE=$?

	print `date` "Completed select of claim count summary report for " $CYCLE_GID  >> $OUTPUT_PATH/$LOG_FILE
	#-------------------------------------------------------------------------#
	# If everything is fine FTP the file to the DATA directory on Crystal Server.                  
	#-------------------------------------------------------------------------#

	if [[ $ORA_RETCODE = 0 ]]; then

		FTP_FILE="rbate_"$JOB"_"$SCHEDULE"_create_claim_sum_rpt"$CYCLE_GID".txt"   
		rm -f $INPUT_PATH/$FTP_CMDS

		print " "                                        >> $OUTPUT_PATH/$LOG_FILE
		print `date` "FTPing files for cycle "$CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE

		print 'cd /'$REBATES_DIR                                   >> $INPUT_PATH/$FTP_CMDS
		print 'cd '$REPORT_DIR                                     >> $INPUT_PATH/$FTP_CMDS
		print 'put ' $OUTPUT_PATH/$DAT_FILE $FTP_FILE ' (replace'  >> $INPUT_PATH/$FTP_CMDS  
		print 'quit'                                               >> $INPUT_PATH/$FTP_CMDS

		ftp -v -i $FTP_NT_IP < $INPUT_PATH/$FTP_CMDS  >> $OUTPUT_PATH/$LOG_FILE
		FTP_RETCODE=$?
		print `date` 'FTP complete '                  >> $OUTPUT_PATH/$LOG_FILE

		if [[ $FTP_RETCODE = 0 ]]; then
			print " " 							>> $OUTPUT_PATH/$LOG_FILE
			print `date` "FTP of "$OUTPUT_PATH/$DAT_FILE" to "$FTP_FILE" complete" >> $OUTPUT_PATH/$LOG_FILE
			RETCODE=$FTP_RETCODE
		else
			RETCODE=$FTP_RETCODE
			print_err "FTP Error ($RETCODE)" >> $OUTPUT_PATH/$LOG_FILE
		fi    
	else
		RETCODE=$ORA_RETCODE
		print_err "SQLPlus Error ($RETCODE)" >> $OUTPUT_PATH/$LOG_FILE
	fi   
	
	if [[ $RETCODE != 0 ]]; then
		print " " >> $OUTPUT_PATH/$LOG_FILE
		print "Failure in select for summary report for cycle " $CYCLE_GID  >> $OUTPUT_PATH/$LOG_FILE
		print "Oracle RETURN CODE is : " $ORA_RETCODE                       >> $OUTPUT_PATH/$LOG_FILE
		print "FTP RETURN CODE is    : " $FTP_RETCODE                       >> $OUTPUT_PATH/$LOG_FILE
		print " "                                                           >> $OUTPUT_PATH/$LOG_FILE
	fi

done < $OUTPUT_PATH/$CLAIM_SUM_CYCLE_CNTL


#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
	print " " >> $OUTPUT_PATH/$LOG_FILE
	print "===================== J O B  A B E N D E D ======================" 	>> $OUTPUT_PATH/$LOG_FILE
	print "  Error Executing " $SCRIPTNAME                                    	>> $OUTPUT_PATH/$LOG_FILE
	print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  	>> $OUTPUT_PATH/$LOG_FILE
	print "=================================================================" 	>> $OUTPUT_PATH/$LOG_FILE
	
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
	exit $RETCODE
fi

print " "                                 >> $OUTPUT_PATH/$LOG_FILE
print "Successfully completed job " $JOB  >> $OUTPUT_PATH/$LOG_FILE 
print "Script " $SCRIPTNAME               >> $OUTPUT_PATH/$LOG_FILE
print `date`                              >> $OUTPUT_PATH/$LOG_FILE
mv -f  $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`

exit $RETCODE

