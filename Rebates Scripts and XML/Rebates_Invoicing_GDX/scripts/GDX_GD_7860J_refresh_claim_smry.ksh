#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_GD_7860J_refresh_claim_smry.ksh
# Title         :
#
# Description   : send claim summary data to RPS from GDX 
#
# Maestro Job   : RIOR4500 GD_7860J
#
# Parameters    : None
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE,
#                 Data file as
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 07-28-09   qcpi733     Added GDX APC status updates
# 07-02-07   qcpi08a     Initial Creation
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    EMAILPARM4='  '
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

    # Add the GDX APC status update
    . `dirname $0`/Common_GDX_APC_Status_update.ksh 460 ERR >> $LOG_FILE
    
    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE
}

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_GDX_Environment.ksh

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
   fi

# Variables
RETCODE=0
SCHEDULE="RIOR4500"
JOB="GD_7860J"
FILE_BASE="GDX_"$JOB"_refresh_claim_smry"
SCRIPTNAME=$FILE_BASE".ksh"

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log"`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "log files for XML in ${LOG_ARCH_PATH}"
      print "********************************************"
   } > $LOG_FILE

#Call the GDX APC status update
. `dirname $0`/Common_GDX_APC_Status_update.ksh 460 STRT                       >> $LOG_FILE

#-------------------------------------------------------------------------#
# Send claim summary data to RPS
#-------------------------------------------------------------------------#

 for MODEL in 'XMD' 'GPO' 'DSC'
 do
    print "Starting MODEL:" $MODEL "at" `date +"%D %r %Z"`                     >> $LOG_FILE   
    $SCRIPT_PATH/Common_java_db_interface.ksh --model $MODEL GDX_GD_7860J_claim_smry.xml
    RETCODE=$?
    if [[ $RETCODE != 0 ]]; then
      print "Error for MODEL:" $MODEL ", return code is : <" $RETCODE ">"      >> $LOG_FILE
      print "Error at " `date +"%D %r %Z"`                                     >> $LOG_FILE
      print ` `                                                                >> $LOG_FILE
      exit_error $RETCODE
    fi
    print "Finishing MODEL: " $MODEL  "at" `date +"%D %r %Z"`                  >> $LOG_FILE
    sleep 60
 done

 RETCODE=$?

#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
   {
      print "********************************************"
      print "Finishing the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "XML return code is : <" $RETCODE ">"   
   }  >> $LOG_FILE

#Call the GDX APC status update
. `dirname $0`/Common_GDX_APC_Status_update.ksh 460 END                        >> $LOG_FILE 

#-------------------------------------------------------------------------#
# move log file to archive with timestamp
#-------------------------------------------------------------------------#

   mv -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE
