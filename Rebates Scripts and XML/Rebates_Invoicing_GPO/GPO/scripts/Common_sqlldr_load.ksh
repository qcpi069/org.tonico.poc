#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_sqlldr_load.ksh   
# Title         : .
#
# Description   : Load a data file to Oracle using SQLLDR.
#                 
#                 
# Maestro Job   : varies
#
# Parameters    : fully qualified data file name 
#                
# Input         : varies
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 06-12-07   is45401     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh


if [[ $REGION = "prod" ]];   then
     export ALTER_EMAIL_ADDRESS=""
     export DATABASE="SILVER"
   if [[$QA_REGION = "true"]]; then
     export ALTER_EMAIL_ADDRESS="" 
     export 
   fi
else
     export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"  
fi

FILE_BASE="Common_sqlldr_load"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
ARCH_LOG_FILE=$OUTPUT_PATH/archive/$FILE_BASE".log."$(date +'%Y%j%H%M')
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    export JOBNAME
    export SCRIPTNAME
    export LOG_FILE
    export LOGFILE=$LOG_FILE
    export EMAILPARM4='  '
    export EMAILPARM5='  '

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    {
        print 'Sending email notification with the following parameters'

        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"

        print '****** end of email parameters ******'
    } >> $LOG_FILE

   . $SCRIPT_PATH/rbate_email_base.ksh
   
    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $ARCH_LOG_FILE
    exit $RETCODE
}
#-------------------------------------------------------------------------#

if [[ $# -lt 1 ]]; then
    print " "                                                                  >> $LOG_FILE
    print "Insufficient arguments passed to script."                           >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    exit_error 1
else
    #fully qualified DAT_FILE
    DAT_FILE_IN=$1
    #strip directory and extension
    DAT_FILE_BASE=`basename $1 .dat`
fi

RETCODE=0

SCHEDULE=""
JOB=""
FILE_BASE="Common_sqlldr_load"
SCRIPTNAME=$(basename $0)
LOG_FILE=$OUTPUT_PATH/$FILE_BASE"_$DAT_FILE_BASE.log"
ARCH_LOG_FILE=$OUTPUT_PATH/archive/$FILE_BASE"_$DAT_FILE_BASE.log."$(date +'%Y%j%H%M')
SQLLDR_CONTROL=$INPUT_PATH/$DAT_FILE_BASE".ctl"
SQLLDR_LOG=$SCRIPT_PATH/$DAT_FILE_BASE".log"
SQLLDR_BAD=$INPUT_PATH/$DAT_FILE_BASE".bad"
#in case trigger file was sent, remove it now.
MAESTRO_TRIGGER_NAME=$DAT_FILE_IN.trg

rm -f $LOG_FILE
rm -f $MAESTRO_TRIGGER_NAME
rm -f $SQLLDR_LOG
rm -f $SQLLDR_BAD

#----------------------------------
# Oracle userid/password
# specific for dma_rbate2 database
# ora.user used for rbate invoicing
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

print " "                                                                      >> $LOG_FILE
print "TODAYS DATE " `date`                                                    >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "Input Parameter = "$1                                                   >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "Load Oracle table using SQLLDR using file $DAT_FILE_IN"                 >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-----------------------------------------------------------------------------
#Execute SQLLDR and check return code  if valid log completion else email error message
#
#-----------------------------------------------------------------------------

$ORACLE_HOME/bin/sqlldr $db_user_password CONTROL=$SQLLDR_CONTROL              >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE = 0 ]]; then
    print `date` "Completed SQLLOADER using $SQLLDR_CONTROL "                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print `date` "New records successfully loaded from data file. "            >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
else
    print " "                                                                  >> $LOG_FILE
    print "Error when loading data using $SQLLDR_CONTROL"                      >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Here is the .bad file info - "                                      >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    cat $SQLLDR_BAD                                                            >> $LOG_FILE    
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Here is the SQLLDR .log file info - "                               >> $LOG_FILE
    cat $SQLLDR_LOG                                                            >> $LOG_FILE    
    print " "                                                                  >> $LOG_FILE
    exit_error 1
fi    

print " "                                                                      >> $LOG_FILE
print "Here is the SQLLDR .log file info - "                                   >> $LOG_FILE
cat $SQLLDR_LOG                                                                >> $LOG_FILE    
print " "                                                                      >> $LOG_FILE
#--------------------------------------------------------------
# Successful run, move/copy data file and rename extension to .old
#--------------------------------------------------------------

mv -f $DAT_FILE_IN $INPUT_PATH/$DAT_FILE_BASE".dat.old"

rm -f $SQLLDR_LOG
rm -f $SQLLDR_BAD

print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE

mv -f $LOG_FILE $ARCH_LOG_FILE

exit $RETCODE

