#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_KCDY6000_KC_6000J_medicare_admin_file_load.ksh
# Description  = Create the script to load the t_medicare_admin_fee table
#		    using sqlldr. 
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
# 05/24/04  is31701                 initial script creation
#==============================================================================
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh


#--re-route DEV and QA Error E-mails to nick tucker
if [[ $REGION = "prod" ]];   then 
  if [[ $QA_REGION = "true" ]];   then                                       
    #--Running in the QA region                                               
    export ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'                  
  else                                                                       
    #--Running in Prod region                                                 
    export ALTER_EMAIL_ADDRESS=''                                            
  fi                                                                         
else                                                                         
  #--Running in Development region                                            
  export ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'                    
fi                                                                           


export EXEC_EMAIL=$SCRIPT_PATH"/rbate_email_base.ksh"
export JOB="KC_6000J"
export SCHEDULE="KCDY6000"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_medicare_admin_file_load"
export SCRIPT_NAME=$SCRIPT_PATH"/"$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export LOG_ARCH=$FILE_BASE".log"
export USER_PSWRD=`cat $SCRIPT_PATH/ora_user.fil`
export SQL_LOG=$SCRIPT_PATH"/t_medicare_admin_fee.log"


#--Delete the output log and sql file from previous execution if it exists.
rm -f $OUTPUT_PATH/$LOG_FILE

print " " >> $OUTPUT_PATH/$LOG_FILE
print "TODAYS DATE " `date` >> $OUTPUT_PATH/$LOG_FILE
print "Monthly Load t_medicare_admin_fee table starting" >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE


$ORACLE_HOME/bin/sqlldr $USER_PSWRD $INPUT_PATH/t_medicare_admin_fee.ctl
                    
#-----------------------------------------------------------------------------
#check return code  if valid log completion else email error message
#
#-----------------------------------------------------------------------------

RETCODE=$?


if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed SQLLOADER t_medicare_admin_fee ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'New medicare admin fees loaded ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Schedule/Job : '$SCHEDULE' '$JOB >> $OUTPUT_PATH/$LOG_FILE
   print 'completed successfully ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
else
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'Failure in the medicare admin fees load. ' >> $OUTPUT_PATH/$LOG_FILE
   export RETCODE=$RETCODE
   print 'SQLLOADER - Load of t_medicare_admin_fee failed : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Here is the sqlldr log:'  >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   cat $SQL_LOG  >> $OUTPUT_PATH/$LOG_FILE

   export JOBNAME=$SCHEDULE" / "$JOB
   export SCRIPTNAME=$SCRIPT_NAME
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $LOG_FILE
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" >> $OUTPUT_PATH/$LOG_FILE
   
   . $EXEC_EMAIL
   cp $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
   exit $RC
fi

#-----------------------------------------------------------------------------
# remove trigger file for medicare admin fee table load process
#-----------------------------------------------------------------------------
rm -f $INPUT_PATH/'medicare_admin_fee.trigger'

