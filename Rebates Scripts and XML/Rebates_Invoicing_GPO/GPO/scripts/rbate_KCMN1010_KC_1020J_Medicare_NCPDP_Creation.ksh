#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCMN1010_KC_1020J_Medicare_NCPDP_Creation.ksh   
# Title         : Medicare NCPDP extract.
#
# Description   : Extract NCPDP files for Medicare Rebates by calling an
#                 an ASYNCHRONOUS module for each Pico involved in the 
#                 cycle period. The currect ASYNCHRONOUS module can be
#                 run in a prallel of 4 processes.
#
#                 ASYNCH module name is 
#     rbate_KCMN1010_KC_1020J_Medicare_NCPDP_Creation_asynchronus_module.ksh
#                 
#                 
# Maestro Job   : KCMN1010 KC_1020J
#
# Parameters    : N/A
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
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

export SCHEDULE="KCMN1010"
export JOB="KC_1020J"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_Medicare_NCPDP_Creation"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export SQL_FILE=$FILE_BASE".sql"
export SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
export FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
export SQL_MDCR_SPNSR_CNTRL=$FILE_BASE"_Medicare_Sponsors.sql"
export MDCR_SPNSR_CNTRL=$FILE_BASE"_Medicare_Sponsors.txt"

export SLEEP_SECS=30


#-------------------------------------------------------------------------#
# The date control file is set in KCMN100 KC_100J and is located in 
# the input path directory 
#-------------------------------------------------------------------------#

export DATE_CNTRL_FILE="rbate_KCMN1000_KC_1000J_medicare_date_control_file.dat"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS
rm -f $INPUT_PATH/$SQL_MDCR_SPNSR_CNTRL
rm -f $OUTPUT_PATH/$MDCR_SPNSR_CNTRL

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
    export CYCLE_GID=$rec_CYCLE_GID
  fi
done < $INPUT_PATH/$DATE_CNTRL_FILE


#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`


#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/$LOG_FILE
print "BEGIN_DATE is " $BEGIN_DATE >> $OUTPUT_PATH/$LOG_FILE
print "END_DATE is " $END_DATE >> $OUTPUT_PATH/$LOG_FILE
print "CYCLE_GID is " $CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE


#-------------------------------------------------------------------------#
# Read Oracle to get the cycle_gid and beginning and end dates related
#  to the MONTHS_BACK parameter.                
#                                                                         
#-------------------------------------------------------------------------#

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

rm -f $OUTPUT_PATH/$FILE_BASE"_ASYCH*.TRG"

#####-------------------------------------------------------------------------#
##### Make asynchronus calls for parallel processing based upon MAX_ASYNCH value.               
##### MAX_ASYNCH value is contained in data file
##### rbate_KCMN1010_KC_1020J_Medicare_NCPDP_Creation_ASYNCH_CTRL.dat
##### in the Input Path directory.
#####-------------------------------------------------------------------------#

print ' '                                                        >> $OUTPUT_PATH/$LOG_FILE
print `date` 'Beginning Medicare NCPDP asynchronus loop control' >> $OUTPUT_PATH/$LOG_FILE

let MAX_ASYNCH=`cat $INPUT_PATH/rbate_KCMN1010_KC_1020J_Medicare_NCPDP_Creation_ASYNCH_CTRL.dat`
   
print ' '                                                        >> $OUTPUT_PATH/$LOG_FILE
print `date` 'MAX_ASYNCH value is ' $MAX_ASYNCH                  >> $OUTPUT_PATH/$LOG_FILE

let I=1
while [[ $I -le $MAX_ASYNCH ]] ; do

    print "Creating start up Trigger file " $OUTPUT_PATH/$FILE_BASE"_ASYCH"$I".TRG" >> $OUTPUT_PATH/$LOG_FILE
    print "TRG start up for " $OUTPUT_PATH/$FILE_BASE"_ASYCH"$I".TRG" >> $OUTPUT_PATH/$FILE_BASE"_ASYCH"$I".TRG"
    let I=$I+1

done

while read rec_PICO_NO ; do
    print `date` 'read record from PICO file' >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_PICO_NO ' $rec_PICO_NO >> $OUTPUT_PATH/$LOG_FILE
    let LOOPCTR=1
    let ENDLOOP=0
    
    print 'LOOPCTR    = ' $LOOPCTR >> $OUTPUT_PATH/$LOG_FILE
    print 'ENDLOOP    = ' $ENDLOOP >> $OUTPUT_PATH/$LOG_FILE
    print 'MAX_ASYNCH = ' $MAX_ASYNCH >> $OUTPUT_PATH/$LOG_FILE
  
    while [[ $ENDLOOP = 0 ]] ; do
    
       print 'TRG file name is ' $OUTPUT_PATH/$FILE_BASE"_ASYCH"$LOOPCTR".TRG" >> $OUTPUT_PATH/$LOG_FILE

       if [[ -a $OUTPUT_PATH/$FILE_BASE"_ASYCH"$LOOPCTR".TRG" ]]; then

          print "removing Trigger file " $OUTPUT_PATH/$FILE_BASE"_ASYCH"$LOOPCTR".TRG" >> $OUTPUT_PATH/$LOG_FILE
          rm -f $OUTPUT_PATH/$FILE_BASE"_ASYCH"$LOOPCTR".TRG" 
          print 'starting Asynch process for PICO_NO ' $rec_PICO_NO >> $OUTPUT_PATH/$LOG_FILE
          print '    as job number ' $LOOPCTR                       >> $OUTPUT_PATH/$LOG_FILE
          . $SCRIPT_PATH/rbate_KCMN1010_KC_1020J_Medicare_NCPDP_Creation_asynchronus_module.ksh $LOOPCTR $rec_PICO_NO $CYCLE_GID $BEGIN_DATE $END_DATE &
                    
          let LOOPCTR=$MAX_ASYNCH+1
          let ENDLOOP=1

       else

          print 'File does not exist for ' $LOOPCTR ' - INCREMENTING!!!!' >> $OUTPUT_PATH/$LOG_FILE
          let LOOPCTR=$LOOPCTR+1
          if [[ $LOOPCTR > $MAX_ASYNCH ]] ; then
             
             print 'LOOPCTR ('$LOOPCTR') greater than MAX_ASYNCH (' $MAX_ASYNCH '), so we are sleeping for ' $SLEEP_SECS ' seconds' >> $OUTPUT_PATH/$LOG_FILE
             let ENDLOOP=0
             let LOOPCTR=1
             sleep $SLEEP_SECS

          fi   

       fi
    
    done    
    
done < $OUTPUT_PATH/$MDCR_SPNSR_CNTRL

if [[ $FIRST_READ != 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Medicare NCPDP creation process ' >> $OUTPUT_PATH/$LOG_FILE
   print 'No PICOs were processed.'                    >> $OUTPUT_PATH/$LOG_FILE
   print ' '                                           >> $OUTPUT_PATH/$LOG_FILE
   PICO_CNT=`wc -l $OUTPUT_PATH/$MDCR_SPNSR_CNTRL`
   export EMAIL_TEXT=$FILE_BASE"_email_text.dat"
   cat > $OUTPUT_PATH/$EMAIL_TEXT << 99999


The Medicare NCPDP process did not create any NCPDP files for $CYCLE_GID.

The number of PICOs to be processed is the following count from the following file name:

$PICO_CNT.


Rebates ON-Call : Please verify that this is correct

99999

   chmod 777 $OUTPUT_PATH/$EMAIL_TEXT

   export EMAIL_SUBJECT="Medicare_NCPDPs_were_not_generated"
   
   mailx -s $EMAIL_SUBJECT MMRebInvoiceITD@caremark.com < $OUTPUT_PATH/$EMAIL_TEXT
   ##mailx -s $EMAIL_SUBJECT kurt.gries@caremark.com < $OUTPUT_PATH/$EMAIL_TEXT

fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0  ]]; then
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

