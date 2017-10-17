#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCMN1010_KC_1030J_medicare_Invoice_Creation.ksh   
# Title         : Snapshot refresh.
#
# Description   : 
#                 
#                 
# Maestro Job   : KCMN1010 KC_1030J
#
# Parameters    : N/A - Can be a months_back value to get different 
#                 quarters of data.
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 05-09-2003  K. Gries    Initial Creation.
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
   if [[ $QA_REGION = "true" ]]; then
       export REBATES_DIR=rebates_integration
       export REPORT_DIR=reporting_test/rebates/data
   else
       export REBATES_DIR=rebates_integration
       export REPORT_DIR=reporting_prod/rebates/data
   fi
else   
    export REBATES_DIR=rebates_integration
    export REPORT_DIR=reporting_test/rebates/data
fi

SCHEDULE="KCMN1010"
JOB="KC_1030J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_medicare_Invoice_Creation"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
SQL_FILE=$FILE_BASE".sql"
SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
SQL_MDCR_SPNSR_CNTRL=$FILE_BASE"_PICOS.sql"
MDCR_SPNSR_CNTRL=$FILE_BASE"_PICOS.dat"


rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS
rm -f $INPUT_PATH/$SQL_MDCR_SPNSR_CNTRL
rm -f $OUTPUT_PATH/$MDCR_SPNSR_CNTRL

export DATE_CNTRL_FILE="rbate_KCMN1000_KC_1000J_medicare_date_control_file.dat"

export FTP_NT_IP=AZSHISP00 

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# Values are set at the beginning of the Medicare Invoicing process in
# KCMN1000_KC_1000J.
#
# Read the date control values for use in the claims selection
# SQL.
#-------------------------------------------------------------------------#

export FIRST_READ=1
while read rec_BEG_DATE rec_END_DATE rec_CYCLE_GID ; do
  if [[ $FIRST_READ != 1 ]]; then
    print 'Finishing control file read' >> $OUTPUT_PATH/$LOG_FILE
  else
    export FIRST_READ=0
    print 'read record from control file' >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_BEG_DATE ' $rec_BEG_DATE >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_END_DATE ' $rec_END_DATE >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_CYCLE_GID ' $rec_CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE
    export BEGIN_DATE=$rec_BEG_DATE
    export END_DATE=$rec_END_DATE
    ###########rec_CYCLE_GID=200404
    export CYCLE_GID=$rec_CYCLE_GID
  fi
done < $INPUT_PATH/$DATE_CNTRL_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

print " " >> $OUTPUT_PATH/$LOG_FILE
print "CYCLE_GID parameter being used is: " $CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE
print " " >> $OUTPUT_PATH/$LOG_FILE

cat > $INPUT_PATH/$SQL_MDCR_SPNSR_CNTRL << EOF
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
SPOOL $OUTPUT_PATH/$MDCR_SPNSR_CNTRL
alter session enable parallel dml; 

Select PICO_NO
  from dma_rbate2.v_ncpdp_medicare_detail
 where cycle_gid = $CYCLE_GID
 group by PICO_NO
 order by PICO_NO
;
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_MDCR_SPNSR_CNTRL

RETCODE=$?

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# Values are set at the beginning of the Medicare Invoicing process in
# KCMN1000_KC_1000J.
#
# Read the date control values for use in the claims selection
# SQL.
#-------------------------------------------------------------------------#

print ' '                                                        >> $OUTPUT_PATH/$LOG_FILE
print `date` 'Beginning Medicare Invoice creation ' >> $OUTPUT_PATH/$LOG_FILE

while read rec_PICO_NO ; do
    print `date` 'read record from PICO file' >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_PICO_NO ' $rec_PICO_NO >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# Read the Sequence Number values for use in the File.
#-------------------------------------------------------------------------#

print ' '                                                        >> $OUTPUT_PATH/$LOG_FILE
print `date` 'Getting SAP records'                          >> $OUTPUT_PATH/$LOG_FILE

DAT_FILE=$FILE_BASE"_"$CYCLE_GID"_"$rec_PICO_NO".dat"
rm -f $OUTPUT_PATH/$DAT_FILE

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
    
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE bs=100k &

cat > $INPUT_PATH/$SQL_FILE << EOF
set LINESIZE 401
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
spool $OUTPUT_PATH/$SQL_PIPE_FILE;

SELECT rpad(a.pico,10,' ')
      ,rpad(rtrim(NVL(b.mfg_nam,'Unavailable')),35,' ')
      ,substrb('$CYCLE_GID',5,2)||'/01/'||substrb('$CYCLE_GID',1,4)
      ,to_char(last_day(to_date('$CYCLE_GID','yyyymm')),'MM/DD/YYYY')
      ,case when a.mdcr_ind = 'T' then rpad('Medicare Transitional Assistance',35,' ')
                                  else rpad('Medicare Cash Card',35,' ')
        end
      ,rpad(rtrim(a.ndc_code),11,' ')
      ,rpad(rtrim(a.lbl_name),35,' ')
      ,substrb(to_char(count(a.rx_nbr),'0000000000'),2,10)
      ,to_char(sum(a.unit_qty),'S00000000000V00000')
      ,to_char(sum(a.mdcr_mfr_rspnb_amt),'S00000000000V00')
      ,to_char(sum(a.flat_fee_rbate_amt),'S00000000000V00')
      ,to_char(sum(a.admin_fee_rbate_amt),'S00000000000V00')
  FROM dma_rbate2.h_claim_rbate_medicare a
      ,dma_rbate2.t_rbate_mfg b
  where cycle_gid = $CYCLE_GID
  and excpt_id in (93,94)
  and a.pico = b.pico_no(+)
  and a.pico = $rec_PICO_NO
group by 
       rpad(a.pico,10,' ')
      ,rpad(rtrim(NVL(b.mfg_nam,'Unavailable')),35,' ')
      ,substrb('$CYCLE_GID',5,2)||'/01/'||substrb('$CYCLE_GID',1,4)
      ,to_char(last_day(to_date('$CYCLE_GID','yyyymm')),'MM/DD/YYYY')
      ,case when a.mdcr_ind = 'T' then rpad('Medicare Transitional Assistance',35,' ')
                                  else rpad('Medicare Cash Card',35,' ')
        end
      ,rpad(rtrim(a.ndc_code),11,' ')
      ,rpad(rtrim(a.lbl_name),35,' ')
order by rpad(a.pico,10,' ')
        ,case when a.mdcr_ind = 'T' then rpad('Medicare Transitional Assistance',35,' ')
                                    else rpad('Medicare Cash Card',35,' ')
         end desc
        ,rpad(rtrim(a.ndc_code),11,' ')
;
                    
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

ORA_RETCODE=$?
print `date` 'Completed select of SAP file for ' $CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE

if [[ $ORA_RETCODE = 0 ]]; then
   print `date` 'Completed select of SAP for ' $CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE
   CRYSTAL_DAT_FILE="MDCR_REB_INV_RPT_"$rec_PICO_NO"_"$CYCLE_GID".txt"
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'FTPing ' $OUTPUT_PATH/$DAT_FILE ' to ' $FTP_IP $CRYSTAL_DAT_FILE          >> $OUTPUT_PATH/$LOG_FILE
   print 'cd /'$REBATES_DIR                                                         >> $INPUT_PATH/$FTP_CMDS
   print 'cd '$REPORT_DIR                                                           >> $INPUT_PATH/$FTP_CMDS
   print 'put ' $OUTPUT_PATH/$DAT_FILE $CRYSTAL_DAT_FILE ' (replace'                >> $INPUT_PATH/$FTP_CMDS
   ftp -i  $FTP_NT_IP < $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   FTP_RETCODE=$?
   if [[ $FTP_RETCODE = 0 ]]; then
      print ' ' >> $OUTPUT_PATH/$LOG_FILE
      print `date` 'FTP  of ' $OUTPUT_PATH/$DAT_FILE ' to ' $DAT_FILE ' complete '           >> $OUTPUT_PATH/$LOG_FILE
      RETCODE=$FTP_RETCODE
   else
      RETCODE=$FTP_RETCODE
   fi    
else
   RETCODE=$ORA_RETCODE
fi
 
if [[ $RETCODE != 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Medicare SAP file creation process '       >> $OUTPUT_PATH/$LOG_FILE
   print 'Oracle RETURN CODE is : ' $ORA_RETCODE             >> $OUTPUT_PATH/$LOG_FILE
   print 'FTP RETURN CODE is    : ' $FTP_RETCODE             >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   return
fi

done < $OUTPUT_PATH/$MDCR_SPNSR_CNTRL


#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE       >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
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

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

