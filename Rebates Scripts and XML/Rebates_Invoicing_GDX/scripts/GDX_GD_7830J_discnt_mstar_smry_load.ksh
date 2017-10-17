#!/bin/ksh
#set -x 
#-------------------------------------------------------------------------#
#
# Script        : GDX_GD_7830J_discnt_mstar_smry_load.ksh   
# Title         : 
#
# Description   : Create the MSTAR Summary data  
#
# Maestro Job   : RIOR4500 GD_7830J
#
# Parameters    : None
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE, 
#                
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09-24-09   qcpi733     Added $SCRIPT_PATH variable to call of APC Status
# 07-28-09   qcpi733     Added GDX APC status update
# 07-10-07   qcpi08a     Initial Creation
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_GDX_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
    RETCODE=$1
    EMAILPARM4='MAILPAGER'
    EMAILPARM5='  '

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

    # Call the GDX APC status update
    . $SCRIPT_PATH/Common_GDX_APC_Status_update.ksh 440 ERR >> $LOG_FILE
    
    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH
    exit $RETCODE
}
#-------------------------------------------------------------------------#

# Region specific variables
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        export ALTER_EMAIL_ADDRESS=""
    LOG_FILE_SIZE_MAX=5000000
        SYSTEM="QA"
    else
        export ALTER_EMAIL_ADDRESS=""
    LOG_FILE_SIZE_MAX=5000000
        SYSTEM="PRODUCTION"
    fi
else
    export ALTER_EMAIL_ADDRESS="yanping.zhao@caremark.com"
    LOG_FILE_SIZE_MAX=100
        SYSTEM="DEVELOPMENT"
        #FTP_DIR="/DBprog"
        FTP_DIR="assign2"
fi

# Variables
RETCODE=0
SCHEDULE="RIOR4500"
JOB="GD_7830J"
FILE_BASE="GDX_"$JOB"_discnt_mstar_smry_load"
SCRIPTNAME=$FILE_BASE".ksh"

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log"`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"

# Cleanup from previous run
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time. 
#-------------------------------------------------------------------------#
   {
      print "Starting the script $SCRIPTNAME ......"                              
      print `date +"%D %r %Z"`
      print "********************************************"      
   }  >> $LOG_FILE

# Call the GDX APC status update
. $SCRIPT_PATH/Common_GDX_APC_Status_update.ksh 440 STRT >> $LOG_FILE

#-------------------------------------------------------------------------#
# Call the Java Mstar Process
#-------------------------------------------------------------------------#

   echo $CLASSPATH

   JAVACMD=$JAVA_HOME/bin/java
   print "----------------------------------------------------------------"    >>$LOG_FILE
   print "$($JAVACMD -version 2>&1)"                                           >>$LOG_FILE
   print "----------------------------------------------------------------"    >>$LOG_FILE

   print "$JAVACMD" "-Dlog4j.configuration=log4j.properties" "-DlogFile=${LOG_FILE}" "-DREGION=${REGION}" "-DQA_REGION=${QA_REGION}" com.caremark.gdx.mstar.MstarMain >> $LOG_FILE

   "$JAVACMD" "-Dlog4j.configuration=log4j.properties" "-DlogFile=${LOG_FILE}" "-DREGION=${REGION}" "-DQA_REGION=${QA_REGION}" com.caremark.gdx.mstar.MstarMain >> $LOG_FILE
   RETCODE=$?

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: Java code fail ...          "            >> $LOG_FILE
      print "JAVA return code is : <" $RETCODE ">"           >> $LOG_FILE
      exit_error $RETCODE
   else
      print "...... Ending JAVA ......"                      >> $LOG_FILE
   fi

#-----------------------------------------------------------------------------------------#
# Check if the LOG_FILE size is greater than 5MB and move the log file to archive.
#-----------------------------------------------------------------------------------------#

   if [[ -s $LOG_FILE ]]; then
      FILE_SIZE=$(ls -l "$LOG_FILE" | awk '{ print $5 }')
   fi
   {
      print " "                                                                  
      print "LOGFILE SIZE  = >$FILE_SIZE<"                                     
      print " "                                                           
      print " "                                                         
      print "....Completed executing " $SCRIPTNAME " ...."          
      print " "                                              
      print " Complete Time is :"`date +"%D %r %Z"`
   }  >> $LOG_FILE

# Call the GDX APC status update
. $SCRIPT_PATH/Common_GDX_APC_Status_update.ksh 440 END

   if [[ $FILE_SIZE -gt $LOG_FILE_SIZE_MAX ]]; then
      mv -f $LOG_FILE $LOG_FILE_ARCH
   fi

exit $RETCODE

