#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_KCWK1023_KC_1023J_force_gather.ksh
# Description  = Execute the pk_load_force_gather_driver PL/SQL package
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
#  10/23/03  is31701                 initial script creation
#==============================================================================
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh


#--re-route DEV and QA Error E-mails to nick tucker
if [[ $REGION = "prod" ]];   then                                            
  if [[ $QA_REGION = "true" ]];   then                                       
    #--Running in the QA region                                               
    export ALTER_EMAIL_ADDRESS='nick.tucker@advancepcs.com'                  
  else                                                                       
    #--Running in Prod region                                                 
    export ALTER_EMAIL_ADDRESS=''                                            
  fi                                                                         
else                                                                         
  #--Running in Development region                                            
  export ALTER_EMAIL_ADDRESS='nick.tucker@advancepcs.com'                    
fi                                                                           


export EXEC_EMAIL=$SCRIPT_PATH"/rbate_email_base.ksh"
export JOB="KC_1023J"
export PKG_NAME=dma_rbate2.PK_FORCE_GATHER_DRIVER.PRC_FORCE_GATHER_DRIVER
export SCHEDULE="KCWK1023"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_force_gather"
export SCRIPT_NAME=$SCRIPT_PATH"/"$FILE_BASE".ksh"
export LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
export LOG_ARCH=$FILE_BASE".log"
export SQL_FILE=$FILE_BASE".sql"
export LOG_SQL_FILE=$OUTPUT_PATH/$FILE_BASE".sqllog"
export USER_PSWRD=`cat $SCRIPT_PATH/ora_user.fil`

#--Delete the output log and sql file from previous execution if it exists.
rm -f $LOG_FILE
rm -f $SCRIPT_PATH/$SQL_FILE
rm -f $LOG_SQL_FILE


#--build and log the execute statement for SQLPLUS
PKG_EXEC=$PKG_NAME

print ' ' >> $LOG_FILE
print 'Exec stmt is: '$PKG_EXEC >> $LOG_FILE
print ' ' >> $LOG_FILE


#--build the sql file for SQLPLUS

cat > $SCRIPT_PATH/$SQL_FILE << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL $LOG_SQL_FILE
SET TIMING ON
exec $PKG_EXEC; 
quit;
EOF

print ' ' >> $LOG_FILE
print "executing SQL" >> $LOG_FILE
print `date` >> $LOG_FILE
print ' ' >> $LOG_FILE

#--execute sql file in SQLPLUS
$ORACLE_HOME/bin/sqlplus -s $USER_PSWRD @$SCRIPT_PATH/$SQL_FILE

RC=$?

cat $LOG_SQL_FILE >> $LOG_FILE

#--Process the Return Code

if [[ $RC != 0 ]]; then
#----if non-zero, error occured.  e-mail error and copy log to archive directory
   export JOBNAME=$SCHEDULE" / "$JOB
   export SCRIPTNAME=$SCRIPT_NAME
   export LOGFILE=$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $LOG_FILE
   print "JOBNAME is " $JOBNAME >> $LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $LOG_FILE
   print "LOGFILE is " $LOGFILE >> $LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $LOG_FILE
   print "****** end of email parameters ******" >> $LOG_FILE
   
   . $EXEC_EMAIL
   cp $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
   exit $RC
else
#----if zero, successful.  Move log to archive directory
print ' ' >> $LOG_FILE
print 'Schedule/Job : '$SCHEDULE' '$JOB >> $LOG_FILE
print 'completed successfully ' >> $LOG_FILE
print ' ' >> $LOG_FILE
   mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
fi



