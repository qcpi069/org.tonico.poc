#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_KCWK1024_KC_102XJ_dup_scr_clms_removal.ksh
# Description  = Execute the pk_dup_scr_driver.prc_dup_scr_process PL/SQL package
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
#  07/01/03  is52701                 initial script creation
#==============================================================================
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh


#--re-route DEV and QA Error E-mails to Peter Merk
if [[ $REGION = "prod" ]];   then                                            
  if [[ $QA_REGION = "true" ]];   then                                       
    #--Running in the QA region                                               
    export ALTER_EMAIL_ADDRESS='peter.merk@advancepcs.com'                  
  else                                                                       
    #--Running in Prod region                                                 
    export ALTER_EMAIL_ADDRESS=''                                            
  fi                                                                         
else                                                                         
  #--Running in Development region                                            
  export ALTER_EMAIL_ADDRESS='peter.merk@advancepcs.com'                    
fi                                                                           


export EXEC_EMAIL=$SCRIPT_PATH"/rbate_email_base.ksh"
export JOB="KC_102XJ"
export PKG_NAME=dma_rbate2.PK_DUP_SCR_CLMS_DRIVER.PRC_DUP_SCR_CLMS_DRIVER
export SCHEDULE="KCWK1024"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_dup_src_clms_removal"
export SCRIPT_NAME=$SCRIPT_PATH"/"$FILE_BASE".ksh"
export USER_PSWRD=`cat $SCRIPT_PATH/ora_user.fil`


#--Verify parameter sent to script
#----if no parameter found, [no logging] e-mail and exit
if [ $# -lt 1 ]; then
   export JOBNAME=$SCHEDULE" / "$JOB": NO PARAMETER"
   export SCRIPTNAME=$SCRIPT_NAME
   export LOGFILE=''
   export EMAILPARM4=''
   export EMAILPARM5=''
   . $EXEC_EMAIL
   exit 1
fi


#--Verify valid parameter sent to script
SOURCE=$1
if [[ $SOURCE = "ALV" ]] || [[ $SOURCE = "RUC" ]] || [[ $SOURCE = "RXC" ]]; then
#----valid parameter: Build Base Filename, Log and SQL Filenames
   LOG_FILE=$OUTPUT_PATH/$FILE_BASE"_"$SOURCE".log"
   LOG_ARCH=$LOG_ARCH_PATH/$FILE_BASE"_"$SOURCE".log"
   SQL_FILE=$INPUT_PATH/$FILE_BASE"_"$SOURCE".sql"
else
#----invalid parameter, [no logging] e-mail error and exit
   export JOBNAME=$SCHEDULE" / "$JOB": INVALID PARAMETER='"$SOURCE"'"
   export SCRIPTNAME=$SCRIPT_NAME
   export LOGFILE=''
   export EMAILPARM4=''
   export EMAILPARM5=''
   . $EXEC_EMAIL
   exit 1
fi


#--Delete the output log and sql file from previous execution.
rm -f $LOG_FILE
rm -f $SQL_FILE


#--build and log the execute statement for SQLPLUS
PKG_EXEC=$PKG_NAME\(\'$SOURCE\'\);

print ' ' >> $LOG_FILE
print 'Exec stmt is: '$PKG_EXEC >> $LOG_FILE
print ' ' >> $LOG_FILE


#--build the sql file for SQLPLUS
cd $INPUT_PATH
cat > $SQL_FILE << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL $LOG_FILE
SET TIMING ON
exec $PKG_EXEC; 
EXIT
EOF


#--execute sql file in SQLPLUS
$ORACLE_HOME/bin/sqlplus -s $USER_PSWRD @$SQL_FILE


#--Process the Return Code
RC=$?
if [[ $RC != 0 ]] then
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
   cp $LOG_FILE $LOG_ARCH.`date +"%Y%j%H%M"`
   exit $RC
else
#----if zero, successful.  Move log to archive directory
   mv -f $LOG_FILE $LOG_ARCH.`date +"%Y%j%H%M"`
fi



