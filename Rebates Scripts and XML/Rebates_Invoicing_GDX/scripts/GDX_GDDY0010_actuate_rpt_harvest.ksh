#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script        : GDX_GDDY0010_actuate_rpt_harvest.ksh   
# Title         : Process entries in Harvest Queue table.
#
# Description   : This script will call Java process to copy the report data 
#                 built in the Actuate into the appropriate tables. This
#                 script can process Discount, GPO, and XMD contracts.
#         The parameter passed into the script will determine
#                 which type of model is to be processed.
#
# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 13-08-12   Z133389     ITPR003455 - ACE 2012 - Rebates Phase 1
						 Removed Model type Regardless of model. 						      
# 03-10-06   is00084     Initial Creation
# 
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
 #       export ALTER_EMAIL_ADDRESS="nandini.namburi@caremark.com"
        export ALTER_EMAIL_ADDRESS=""
        LOG_FILE_SIZE_MAX=5000000
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        LOG_FILE_SIZE_MAX=5000000
    fi
else
    # Running in Development region
    # export ALTER_EMAIL_ADDRESS="nandini.namburi@caremark.com"
    export ALTER_EMAIL_ADDRESS="Krishnaswamy.Rameshkumar@caremark.com"
    LOG_FILE_SIZE_MAX=100
fi


RETCODE=0
SCHEDULE="GDDY0010"
JOB=""

FILE_BASE="GDX_"$SCHEDULE"_actuate_rpt_harvest"
SCRIPTNAME=$FILE_BASE".ksh"

# LOG FILES
LOG_FILE_ARCH=$FILE_BASE".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_ARCH

#-------------------------------------------------------------------------#
# Starting the script to Harvest the Actuate Temp Tables
#-------------------------------------------------------------------------#
print `date`                                                                   >> $LOG_FILE
print "Starting the script to Harvest the Actuate Temp Tables."                >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
 
#
#-------------------------------------------------------------------------#
# Call the Java Harvest Process
#-------------------------------------------------------------------------#

if [[ $RETCODE = 0 ]]; then
   JAVACMD=$JAVA_HOME/bin/java
   print "----------------------------------------------------------------"    >>$LOG_FILE
   print "$($JAVACMD -version 2>&1)"                                           >>$LOG_FILE
   print "----------------------------------------------------------------"    >>$LOG_FILE
      
   print "$JAVACMD" "-Dlog4j.configuration=harvest.log4j.properties" "-DlogFile=${LOG_FILE}" "-DREGION=${REGION}" "-DQA_REGION=${QA_REGION}" com.caremark.gdx.harvest.HarvestMain >>$LOG_FILE

   "$JAVACMD" "-Dlog4j.configuration=harvest.log4j.properties" "-DlogFile=${LOG_FILE}" "-DREGION=${REGION}" "-DQA_REGION=${QA_REGION}" com.caremark.gdx.harvest.HarvestMain >> $LOG_FILE
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

# mv -f $JAVA_LOG_FILE $LOG_ARCH_PATH/$JAVA_LOG_FILE_ARCH.`date +"%Y%j%H%M"`

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

