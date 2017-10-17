#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_GD_7840J_refresh_discnt_apc_rpt_mstar.ksh
# Title         :
#
# Description   : Copy DISCNT_APC_RPT and MSTAR data to RPS from GDX 
#
# Maestro Job   : RIOR4500 GD_7840J
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
# 06-30-07   qcpi08a     Initial Creation
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

    # Call the GDX APC status update
    . `dirname $0`/Common_GDX_APC_Status_update.ksh 450 ERR >> $LOG_FILE
    
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
JOB="GD_7840J"
FILE_BASE="GDX_"$JOB"_refresh_discnt_apc_rpt_mstar"
SCRIPTNAME=$FILE_BASE".ksh"
#XML_PATH="${GDX_PATH}/xml"

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

# Call the GDX APC status update
. `dirname $0`/Common_GDX_APC_Status_update.ksh 450 STRT                       >> $LOG_FILE

#-------------------------------------------------------------------------#
# Send TDISCNT_APC_RPS and TCUR_INV_PRD data to RPS
#-------------------------------------------------------------------------#

 print "Starting Refresh DISCNT APC RPT at" `date +"%D %r %Z"`                 >> $LOG_FILE
 $SCRIPT_PATH/Common_java_db_interface.ksh GDX_GD_7840J_refresh_discnt_apc_rpt.xml 
 RETCODE=$?
 if [[ $RETCODE != 0 ]]; then
      print "Refresh DISCNT APC RPT Error, return code is : <" $RETCODE ">"    >> $LOG_FILE
      print "Error at " `date +"%D %r %Z"`                                     >> $LOG_FILE
      print ` `                                                                >> $LOG_FILE
      exit_error $RETCODE
 fi
 print "Finishing Refresh DISCNT APC RPT at" `date +"%D %r %Z"`                >> $LOG_FILE
 
#-------------------------------------------------------------------------#
# Send MSTAR data to RPS
#-------------------------------------------------------------------------#

 for MODEL in 'XMD' 'GPO' 'DSC'
 do
    print "Starting MODEL:" $MODEL "at" `date +"%D %r %Z"` >> $LOG_FILE   
    $SCRIPT_PATH/Common_java_db_interface.ksh --model $MODEL GDX_GD_7840J_refresh_mstar.xml
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

# Call the GDX APC status update
. `dirname $0`/Common_GDX_APC_Status_update.ksh 450 END                        >> $LOG_FILE

#-------------------------------------------------------------------------#
# move log file to archive with timestamp
#-------------------------------------------------------------------------#

   mv -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE
