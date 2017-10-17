#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDDY0010_report_purge.ksh   
# Title         : This is the main script for the report purge process.
#
#                 
# This script is executed from the following Maestro jobs:
# Maestro Job   : GDDY0010 / GD_0050J
#
# Parameters    : None.
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 or > = fatal error
#
#   Date     Analyst    Project   Description
# ---------  ---------  --------  ----------------------------------------#
# 03/22/07   qcpi13d	6015188   Initial Creation  
# 
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
       export ALTER_EMAIL_ADDRESS="patrick.nutley@caremark.com"
       LOG_FILE_SIZE_MAX=5000000
    else
    # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        LOG_FILE_SIZE_MAX=5000000
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="patrick.nutley@caremark.com"
    LOG_FILE_SIZE_MAX=100
fi


#-------------------------------------------------------------------------#
# Set the Initial Variables.
#-------------------------------------------------------------------------#

SCHEDULE="GDDY0010"
JOB="GD_0050J"
DFLT_FILE_BASE="GDX_"$SCHEDULE"_report_purge"
SCRIPTNAME=$DFLT_FILE_BASE".ksh"

#-------------------------------------------------------------------------#
# First verify the input parameters.
#-------------------------------------------------------------------------#

FILE_BASE="GDX_"$SCHEDULE"_report_purge"
LOG_FILE_ARCH=$FILE_BASE".log" 
LOG_FILE=$LOG_PATH/$LOG_FILE_ARCH
RETCODE=0

#-------------------------------------------------------------------------#
# Call the Java Report Purge Process
#-------------------------------------------------------------------------#

if [[ $RETCODE = 0 ]]; then
   JAVACMD=$JAVA_HOME/bin/java
   print "----------------------------------------------------------------"    >>$LOG_FILE
   print "$($JAVACMD -version 2>&1)"                                           >>$LOG_FILE
   print "----------------------------------------------------------------"    >>$LOG_FILE
      
   print "$JAVACMD" "-Dlog4j.configuration=log4j.properties" "-DlogFile=${LOG_FILE}" "-DREGION=${REGION}" "-DQA_REGION=${QA_REGION}" com.caremark.gdx.reportpurge.ReportPurgeMain >> $LOG_FILE

   "$JAVACMD" "-Dlog4j.configuration=log4j.properties" "-DlogFile=${LOG_FILE}" "-DREGION=${REGION}" "-DQA_REGION=${QA_REGION}" com.caremark.gdx.reportpurge.ReportPurgeMain >> $LOG_FILE
   export RETCODE=$?

   print "RETCODE=$RETCODE "                                                   >> $LOG_FILE

fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
    EMAILPARM4="  "
    EMAILPARM5="  "
    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh
fi

#-----------------------------------------------------------------------------------------#
# Check if the LOG_FILE size is greater than 5MB and move the log file to archive.
#-----------------------------------------------------------------------------------------#

#Get the size of the LOGFILE
if [[ -s $LOG_FILE ]]; then
   FILE_SIZE=$(ls -l "$LOG_FILE" | awk '{ print $5 }')
fi

print " "                                                                      >> $LOG_FILE
print "LOGFILE SIZE  = >$FILE_SIZE<"                                           >> $LOG_FILE
print $FILE_SIZE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

# Removing the $LOGFILE as size is more than 5MB
if [[ $FILE_SIZE -gt $LOG_FILE_SIZE_MAX ]]; then
    mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`
fi   

exit $RETCODE
