#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCMN1000_KC_1000J_medicare_date_control_file.ksh   
# Title         : .
#
# Description   : Create the Invoice date control file for the Medicare Invoice  
#                 process.
#                 
#                 
# Maestro Job   : KCMN1000/KC_1000J
#
# Parameters    : If the begin and end dates are not input, we will claculate them 
#                 along with the Medicare cycle_gid.
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 05-10-2004  N.Tucker    Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'
      else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=''
      fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'
fi

RETCODE=0
SCHEDULE="KCMN1000"
JOB="KC_1000J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_medicare_date_control_file"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
SQL_FILE=$FILE_BASE".sql"
DATE_CNTRL_FILE=$FILE_BASE".dat"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $INPUT_PATH/$DATE_CNTRL_FILE
rm -f $INPUT_PATH/$SQL_FILE


#-------------------------------------------------------------------------#
# If CYCLE_GID and MONTH are passed in then they will be used. Otherwise,
# the script will calculate the dates to be used.
#-------------------------------------------------------------------------#

if [ $# -lt 3 ] 
then


#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`


cat > $INPUT_PATH/$SQL_FILE << EOF
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
SPOOL $INPUT_PATH/$DATE_CNTRL_FILE
alter session enable parallel dml; 

SELECT
'27'
,TO_CHAR(ADD_MONTHS(sysdate,-1),'MMYYYY')
,' '
,'26'
,TO_CHAR(sysdate,'MMYYYY') 
,' '
,TO_CHAR(sysdate,'YYYYMM') 
FROM dual;

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

RETCODE=$?


if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed select of medicare date control file ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
else   
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
#
## Do this logic if the parameters are supplied 
#
else
print " " >> $OUTPUT_PATH/$LOG_FILE
    print "DATES ARE SUPPLIED FOR THIS RUN." >> $OUTPUT_PATH/$LOG_FILE
    print " " >> $OUTPUT_PATH/$LOG_FILE
    print "Begin date is: " $1 >> $OUTPUT_PATH/$LOG_FILE
    print "End date is:   " $2 >> $OUTPUT_PATH/$LOG_FILE
    print "cycle_gid is:  " $3 >> $OUTPUT_PATH/$LOG_FILE
    print " " >> $OUTPUT_PATH/$LOG_FILE
    print "creating date control file with these supplied parms " >> $OUTPUT_PATH/$LOG_FILE 
    print $1" "$2" "$3" " >> $INPUT_PATH/$DATE_CNTRL_FILE
fi 


print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`

exit $RETCODE

