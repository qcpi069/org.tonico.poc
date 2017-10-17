#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIBW3400_RI_3400J_Missing_Document_Numbers_extrcts.ksh   
# Title         : .
#
# Description   : Identify Missing Document Numbers on the EDW 
#                 
#                 
#                 
# Maestro Job   : RIBW3400 RI_3400J
#
# Parameters    : N/A - 

#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date      Programmer    Description
# ----------  ------------  ---------------------------------------------#
# 10-10-2003  R. Hutchison  Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration
     export MVS_ENV="PCS.P."
   else  
     export REBATES_DIR=rebates_integration
     export MVS_ENV="PCS.D."
fi

export SCHEDULE="RIBW3400"
export JOB="RI_3400J"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_Missing_Document_Numbers_extrct"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export SQL_FILE=$FILE_BASE".sql"
export SQL_FILE_DATE_CNTRL=$FILE_BASE"_date_cntrl.sql"
export SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
export DAT_FILE=$FILE_BASE".dat"
export DAT_FILE_CNT=$FILE_BASE"_cnt.dat"
export DATE_CNTRL_FILE=$FILE_BASE"_date_control_file.dat"
export MR_MAILMAN_FILE=$FILE_BASE"_mr_mailman.dat"
export FTP_CMDS=$FILE_BASE"_ftpcommands.txt"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$DAT_FILE
rm -f $OUTPUT_PATH/$DATE_CNTRL_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $INPUT_PATH/$SQL_FILE_DATE_CNTRL
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS
rm -f $OUTPUT_PATH/$DAT_FILE_CNT
rm -f $OUTPUT_PATH/$MR_MAILMAN_FILE

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# If MONTHS_BACK are passed in then they will be used. Otherwise,
# the script will calculate the dates to be used.
#-------------------------------------------------------------------------#

if [ $# -lt 1 ] 
then
    print " " >> $OUTPUT_PATH/$LOG_FILE
    print "MONTHS_BACK parameter not supplied. We will use the default of 2 to get prior quarter." >> $OUTPUT_PATH/$LOG_FILE
    print " " >> $OUTPUT_PATH/$LOG_FILE
    print `date` >> $OUTPUT_PATH/$LOG_FILE
    print " " >> $OUTPUT_PATH/$LOG_FILE
    let MONTHS_BACK=2
else
    let MONTHS_BACK=$1 
fi

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Read Oracle to get two dates:
# v_first_day_prev_month - the first day of the previous month
# v_last_day_curr_month  - the last day of the current month
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/$LOG_FILE
print "MONTHS_BACK parameter being used is: " $MONTHS_BACK >> $OUTPUT_PATH/$LOG_FILE
print " " >> $OUTPUT_PATH/$LOG_FILE

cat > $INPUT_PATH/$SQL_FILE_DATE_CNTRL << EOF
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
SPOOL $OUTPUT_PATH/$DATE_CNTRL_FILE

Select to_char((last_day(add_months(SYSDATE, - ($MONTHS_BACK))) + 1), 'MM-DD-YYYY')
      ,' '
      ,to_char(last_day(SYSDATE), 'MM-DD-YYYY')  
  from dual
;
quit;

EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE_DATE_CNTRL

export RETCODE=$?

#-------------------------------------------------------------------------#
# Read the returned date control values for use in the claims selection
# SQL.
#-------------------------------------------------------------------------#

export FIRST_READ=1
while read rec_FIRST_DAY_PREV_MONTH rec_LAST_DAY_CURR_MONTH; do
  if [[ $FIRST_READ != 1 ]]; then
    print 'Finishing control file read' >> $OUTPUT_PATH/$LOG_FILE
  else
    export FIRST_READ=0
    print 'read record from control file' >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_FIRST_DAY_PREV_MONTH ' $rec_FIRST_DAY_PREV_MONTH >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_LAST_DAY_CURR_MONTH ' $rec_LAST_DAY_CURR_MONTH >> $OUTPUT_PATH/$LOG_FILE
    export FIRST_DAY_PREV_MONTH=$rec_FIRST_DAY_PREV_MONTH
    export LAST_DAY_CURR_MONTH=$rec_LAST_DAY_CURR_MONTH

  fi
done < $OUTPUT_PATH/$DATE_CNTRL_FILE

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
# Display special env vars used for this script
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/$LOG_FILE
print "FIRST_DAY_PREV_MONTH is " $FIRST_DAY_PREV_MONTH >> $OUTPUT_PATH/$LOG_FILE
print "LAST_DAY_CURR_MONTH is " $LAST_DAY_CURR_MONTH >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE
print `date` ' SQL Loader started' >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# Use SQL loader to load all of the document numbers from MVS into the
# missing_allv_docnums table.
#-------------------------------------------------------------------------#

$ORACLE_HOME/bin/sqlldr $db_user_password $INPUT_PATH/missing_allv_docnums.ctl

export RETCODE=$?

if [[ $RETCODE != 0 ]]; then
#-------------------------------------------------------------------------#
# This IF relates to the Return code check for the sqlldr step.
# Search for SQLLDR_IF_FI to find the location of the related FI in this code.
#-------------------------------------------------------------------------#
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in SQL Loader Process' >> $OUTPUT_PATH/$LOG_FILE
   export RETCODE=$RETCODE
   print 'Missing Document Number Extract RETURN CODE is : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
else
   print `date` ' Completed SQL Loader to load all document numbers from MVS' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# 
# Set up the Pipe file, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#
print `date` 'Beginning select of Missing document numbers Extract ' >> $OUTPUT_PATH/$LOG_FILE

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE bs=100k &

cat > $INPUT_PATH/$SQL_FILE << EOF
set LINESIZE 800
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP off
set verify off
set trimspool on
alter session enable parallel dml;

spool $OUTPUT_PATH/$DAT_FILE_CNT;

--------------------------------------------------------------------------#
-- Delete all of the rows in the missing_allv_docnums table.
-- Join the allv_docnums table with the t_claim_alv table and the 
-- s_claim_alv table.  Write all document numbers to the missing_allv_docnums
-- table if they do not exist on the other 2 tables. 
--------------------------------------------------------------------------#

alter session enable parallel dml;
delete from dma_rbate2.missing_allv_docnums;
commit;

insert into dma_rbate2.missing_allv_docnums (
   select /*+ full(a) parallel(a,12) */ doc_num
     from dma_rbate2.allv_docnums a
    where doc_num not in(
    	       select * from (
    			SELECT /*+ full(a) parallel(a,12) */ extnl_claim_id
    			     from dwcorp.t_claim_alv a
    			     WHERE batch_date BETWEEN TO_DATE('$FIRST_DAY_PREV_MONTH','MM-DD-YYYY') 
                                                  AND TO_DATE('$LAST_DAY_CURR_MONTH','MM-DD-YYYY')
    			       AND extnl_claim_id IS NOT NULL
    			union all
    			SELECT /*+ full(tca) parallel(tca,12)  */
  			     extnl_claim_id
   			     FROM dma.s_claim_alv@iron tca
   			     WHERE batch_date BETWEEN TO_DATE('$FIRST_DAY_PREV_MONTH','MM-DD-YYYY') 
                                                  AND TO_DATE('$LAST_DAY_CURR_MONTH','MM-DD-YYYY')
   			     and extnl_claim_id IS NOT NULL))
                         and doc_num is not null);

commit;

select count(*) 
  from dma_rbate2.allv_docnums a;

select count(*) 
  from dma_rbate2.missing_allv_docnums a;

--------------------------------------------------------------------------#
-- Write all of the missing document numbers to a file
--------------------------------------------------------------------------#
spool $OUTPUT_PATH/$SQL_PIPE_FILE;

SELECT doc_num
FROM dma_rbate2.missing_allv_docnums a
order by doc_num;

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

export RETCODE=$?

#-------------------------------------------------------------------------#
# Read the total number of records on the allv_docnums table and the 
# total number of records on the missing_allv_docnums table.  Then 
# display them in the Mr Mailman file below.
#-------------------------------------------------------------------------#

export FIRST_READ=1
while read rec_COUNTER; do
  if [[ $FIRST_READ = 1 ]]; then
    let rec_TOTAL_DOC_NUMBERS=$rec_COUNTER
    print 'Document numbers read from tables' >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_TOTAL_DOC_NUMBERS ============ ' $rec_TOTAL_DOC_NUMBERS >> $OUTPUT_PATH/$LOG_FILE
    export FIRST_READ=0
  else
    let rec_TOTAL_DOC_NUMBERS_NOT_FOUND=$rec_COUNTER
    print 'rec_TOTAL_DOC_NUMBERS_NOT_FOUND == ' $rec_TOTAL_DOC_NUMBERS_NOT_FOUND >> $OUTPUT_PATH/$LOG_FILE
  fi

done < $OUTPUT_PATH/$DAT_FILE_CNT

let rec_TOTAL_DOC_NUMBERS_FOUND=$rec_TOTAL_DOC_NUMBERS-$rec_TOTAL_DOC_NUMBERS_NOT_FOUND
print 'rec_TOTAL_DOC_NUMBERS_FOUND ====== ' $rec_TOTAL_DOC_NUMBERS_FOUND >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# 
# Create Mr Mailman file that will be sent to MVS.
# This file will contain counts for the number of document numbers read from
# MVS, number of document reads found on EDW, and the number of records
# not found on EDW. This file will be FTPed to MVS and concatenated with
# the Mr Mailman message created in job ED50J400.             
#                                                                         
#-------------------------------------------------------------------------#

cat > $OUTPUT_PATH/$MR_MAILMAN_FILE << ZZZZZ

****************************************************************
*                    TOTALS FOR UNIX SCRIPT 
*  $SCRIPTNAME 
****************************************************************
  
TOTAL ALLVOUCHER DOCUMENT NUMBERS READ FROM MVS     $rec_TOTAL_DOC_NUMBERS
TOTAL ALLVOUCHER DOCUMENT NUMBERS FOUND ON EDW      $rec_TOTAL_DOC_NUMBERS_FOUND
TOTAL ALLVOUCHER DOCUMENT NUMBERS NOT FOUND ON EDW  $rec_TOTAL_DOC_NUMBERS_NOT_FOUND
  
ZZZZZ

if (($rec_TOTAL_DOC_NUMBERS_NOT_FOUND > 0)); then
  cat >> $OUTPUT_PATH/$MR_MAILMAN_FILE << 99999


****************************************************************
*         Missing document numbers are being researched
****************************************************************

99999
else
  cat >> $OUTPUT_PATH/$MR_MAILMAN_FILE << 99999


****************************************************************
*     There are no missing document numbers for this cycle
****************************************************************

99999
fi

if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed select of Missing Document Numbers Extract ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTPing files ' >> $OUTPUT_PATH/$LOG_FILE
   export FTP_NT_IP=PHXN3
   export TARGET_FILE="'"$MVS_ENV"ED50J410.MISS.DOCNUMS'"
   export TARGET_MAILMAN_FILE="'"$MVS_ENV"ED50J410.MAILMAN'"
   print 'put ' $OUTPUT_PATH/$DAT_FILE $TARGET_FILE ' (replace'                 >> $INPUT_PATH/$FTP_CMDS
   print 'put ' $OUTPUT_PATH/$MR_MAILMAN_FILE $TARGET_MAILMAN_FILE ' (replace'  >> $INPUT_PATH/$FTP_CMDS
   print 'quit'                                                                 >> $INPUT_PATH/$FTP_CMDS
   ftp -i  $FTP_NT_IP < $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTP complete ' >> $OUTPUT_PATH/$LOG_FILE
fi

if [[ $RETCODE != 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Extract ' >> $OUTPUT_PATH/$LOG_FILE
   export RETCODE=$RETCODE
   print 'Missing Document Number Extract RETURN CODE is : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
fi

#-------------------------------------------------------------------------#
# The following FI relates to the Return code check for the SQLLDR step.
# Search for SDQLLDR_IF_FI to find the location of the code.               
#-------------------------------------------------------------------------#

fi


#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE       >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
#-------------------------------------------------------------------------#
# Send the Email notification                  
#-------------------------------------------------------------------------#
   export JOBNAME=$SCHEDULE " / " $JOB
   export SCRIPTNAME=$OUTPUT_PATH"/"$SCRIPTNAME
   export LOGFILE=$OUTPUT_PATH"/"$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/allv_docnums.dat

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

