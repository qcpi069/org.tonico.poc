#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCWK2000_KC_2001J_algn_lvl_lcm_snapshot.ksh   
# Title         : Snapshot refresh.
#
# Description   : Refreshes the dwcorp.t_algn_lvl_lcm snapshot on Silver. 
#                
# Maestro Job   : KC_2001J
#
# Parameters    : None
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 
# 06-24-2005  N. Tucker  Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'
    else
        # Running in Prod region
        ALTER_EMAIL_ADDRESS=''
    fi
else
    # Running in Development region
    ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'
fi

RETCODE=0
SCHEDULE="KCWK2000"
JOB="KC_2001J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_algn_lvl_lcm_snapshot"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
SQL_FILE=$INPUT_PATH/$FILE_BASE".sql"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $SQL_FILE

print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
print " Now starting script " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# Set parameters.
#
# Snapshot_Name is the table to be refreshed
# Refresh_Type is the type of refresh where C=Complete
#
#-------------------------------------------------------------------------#

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

cat > $SQL_FILE << EOF
set serveroutput on size 1000000
whenever sqlerror exit 1
SET TIMING ON
exec DBMS_SNAPSHOT.REFRESH('DWCORP.t_algn_lvl_lcm','C',atomic_refresh=>true);
EXIT
EOF

print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
print " Now executing the DBMS_SNAPSHOT.REFRESH procedure on DWCORP.t_algn_lvl_lcm" >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

RETCODE=$?

print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE

if [[ $RETCODE = 0 ]]; then
    print " Successfully completed snapshot. "           	             >> $OUTPUT_PATH/$LOG_FILE
else
    print " Snapshot abended. "                                              >> $OUTPUT_PATH/$LOG_FILE     
fi

print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   JOBNAME=$SCHEDULE/$JOB
   SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   LOGFILE=$OUTPUT_PATH/$LOG_FILE
   EMAILPARM4="  "
   EMAILPARM5="  "
   
   print "Sending email notification with the following parameters"         >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOBNAME                                             >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME                                       >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE                                             >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4                                       >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5                                       >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******"                            >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

rm -f $SQL_FILE

print "....Completed executing " $SCRIPTNAME "...."                         >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

