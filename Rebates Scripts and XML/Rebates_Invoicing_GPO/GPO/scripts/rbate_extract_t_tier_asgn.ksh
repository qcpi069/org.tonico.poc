#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_extract_t_tier_asgn.ksh   
# Title         : t_tier_asgn extract.
#
# Description   : Extracts t_tier_asgn records for transmit 
#                 to \\mndata02\ms_invoice
# Maestro Job   : RIOR4510 RI_4510J
#
# Parameters    : CYCLE_GID
#
# Output        : Log file as $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 11-26-2002  K. Gries    Initial Creation.
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration
     export MS_INVOICE=ms_invoice
   else  
     export REBATES_DIR=rebates_integration
     export MS_INVOICE=ms_invoice
fi

export FTP_NT_IP=AZSHISP00 

rm -f $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
rm -f $OUTPUT_PATH/rbate_extract_t_tier_asgn.dat

export EDW_USER="/"


#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#

print ' ' >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
print "executing T_TIER_ASGN Extract SQL" >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
print `date` >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# If CYCLE_GID and MONTH are passed in then they will be used. Otherwise,
# the script will calculate the dates to be used.
#
# We use 3 as the default because the file is being run for the previous  
# quarter.
#-------------------------------------------------------------------------#

if [ $# -lt 1 ] 
then
    print " " >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
    print "MONTHS_BACK parameter not supplied. We will use the default of 1." >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
    print " " >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
    print `date` >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
    print " " >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
    let MONTHS_BACK=3
else
    let MONTHS_BACK=$1 
fi

#-------------------------------------------------------------------------#
# Read Oracle to get the cycle_gid and beginning and end dates related
#  to the MONTHS_BACK parameter.                
#                                                                         
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
print "MONTHS_BACK parameter being used is: " $MONTHS_BACK >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
print " " >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log

cat > $SCRIPT_PATH/rbate_extract_t_tier_asgn_datectl.sql << EOF
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
SPOOL $OUTPUT_PATH/rbate_extract_t_tier_asgn_datectl.dat
alter session enable parallel dml; 

Select to_char(add_months(SYSDATE, - $MONTHS_BACK ),'MM')||'/01/'||to_char(add_months(SYSDATE, - $MONTHS_BACK ),'YYYY')
      ,' '
      ,to_char(last_day(add_months(SYSDATE, - $MONTHS_BACK )),'MM/DD/YYYY')
      ,' '
      ,rbate_CYCLE_GID
      ,' '
      ,to_char(last_day(add_months(SYSDATE, - $MONTHS_BACK )),'YYYYMM')
  from dma_rbate2.t_rbate_cycle
 where add_months(SYSDATE, - $MONTHS_BACK ) between CYCLE_START_DATE and CYCLE_END_DATE
   and substrb(rbate_CYCLE_GID,5,1) = '4'
;
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SCRIPT_PATH/rbate_extract_t_tier_asgn_datectl.sql

export RETCODE=$?

#-------------------------------------------------------------------------#
# Read the returned date control values for use in the claims selection
# SQL.
#-------------------------------------------------------------------------#
export FIRST_READ=1
while read rec_BEG_DATE rec_END_DATE rec_CYCLE_GID YRMON; do
  if [[ $FIRST_READ != 1 ]]; then
    print 'Finishing control file read' >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
  else
    export FIRST_READ=0
    print 'read record from control file' >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
    print 'rec_BEG_DATE ' $rec_BEG_DATE >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
    print 'rec_END_DATE ' $rec_END_DATE >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
    print 'rec_CYCLE_GID ' $rec_CYCLE_GID >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
    export BEGIN_DATE=$rec_BEG_DATE
    export END_DATE=$rec_END_DATE
    export CYCLE_GID=$rec_CYCLE_GID
    export YYYYMM=$YRMON
  fi
done < $OUTPUT_PATH/rbate_extract_t_tier_asgn_datectl.dat

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
print "BEGIN_DATE is " $BEGIN_DATE >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
print "END_DATE is " $END_DATE >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
print "CYCLE_GID is " $CYCLE_GID >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
print ' ' >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

rm -f $SCRIPT_PATH/rbate_extract_t_tier_asgn.sql
rm -f $OUTPUT_PATH/rbate_extract_t_tier_asgn_pipe.lst
mkfifo $OUTPUT_PATH/rbate_extract_t_tier_asgn_pipe.lst
dd if=$OUTPUT_PATH/rbate_extract_t_tier_asgn_pipe.lst of=$OUTPUT_PATH/rbate_extract_t_tier_asgn.dat bs=100k &

cat > $SCRIPT_PATH/rbate_extract_t_tier_asgn.sql << EOF
set LINESIZE 100
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
SPOOL $OUTPUT_PATH/rbate_extract_t_tier_asgn_pipe.lst
alter session enable parallel dml; 
SELECT b.bskt_gid
      ,','
      ,a.Bskt_nam
      ,','
      ,b.mrkt_tier_pctg
      ,','
      ,b.tier_id
      ,','
      ,b.rbate_lvl_id
      ,','
      ,a.mrkt_shr_type
  FROM dma_rbate2.h_bskt a
      ,dma_rbate2.h_tier_asgn b
      ,dma_rbate2.t_inv c
 where a.bskt_gid = b.bskt_gid 
   and a.inv_gid = b.inv_gid
   and a.inv_gid = c.inv_gid
   and c.rbate_cycle_gid = $CYCLE_GID
  order by bskt_gid asc
          ,tier_id asc
          ,rbate_lvl_id asc
;
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SCRIPT_PATH/rbate_extract_t_tier_asgn.sql

export RETCODE=$?

if [[ $RETCODE != 0 ]]; then
  print "T_TIER_ASGN Extract SQL Failed - error message is: " >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
  print ' ' >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log 
  tail -20 $SRC_FILE_DIR/rbate_extract_t_tier_asgn.dat >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
else
  print 'cd /'$REBATES_DIR                                  >> $OUTPUT_PATH/rbate_extract_t_tier_asgn_ftpcommands.txt
  print 'cd "'$MS_INVOICE'"'                                >> $OUTPUT_PATH/rbate_extract_t_tier_asgn_ftpcommands.txt
  print 'put ' $OUTPUT_PATH/rbate_extract_t_tier_asgn.dat rbate_extract_t_tier_asgn.dat ' (replace' >> $OUTPUT_PATH/rbate_extract_t_tier_asgn_ftpcommands.txt
  print 'quit'                                              >> $OUTPUT_PATH/rbate_extract_t_tier_asgn_ftpcommands.txt
  ftp -i  $FTP_NT_IP < $OUTPUT_PATH/rbate_extract_t_tier_asgn_ftpcommands.txt >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
fi

export RETCODE=$?

if [[ $RETCODE != 0 ]]; then
  print "Failure in the FTP step" >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
  print ' ' >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log 
else
  mv -f $OUTPUT_PATH/rbate_extract_t_tier_asgn.dat       $LOG_ARCH_PATH/rbate_extract_t_tier_asgn.dat.`date +"%Y%j%H%M"`
  mv -f $OUTPUT_PATH/rbate_extract_t_tier_asgn_ftpcommands.txt $LOG_ARCH_PATH/rbate_extract_t_tier_asgn_ftpcommands.txt.`date +"%Y%j%H%M"`
  rm -f $OUTPUT_PATH/rbate_extract_t_tier_asgn_pipe.lst
fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   print "  Error Executing rbate_extract_t_tier_asgn.ksh          " >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   print "  Look in "$OUTPUT_PATH/rbate_extract_t_tier_asgn.log       >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   print "=================================================================" >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   
# Send the Email notification 
   export JOBNAME="RIOR4510 / RI_4510J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_extract_t_tier_asgn.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_extract_t_tier_asgn.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/rbate_extract_t_tier_asgn.log $LOG_ARCH_PATH/rbate_extract_t_tier_asgn.log.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

print "....Completed executing rbate_extract_t_tier_asgn.ksh ...."   >> $OUTPUT_PATH/rbate_extract_t_tier_asgn.log
mv -f $OUTPUT_PATH/rbate_extract_t_tier_asgn.log $LOG_ARCH_PATH/rbate_extract_t_tier_asgn.log.`date +"%Y%j%H%M"`


exit $RETCODE

