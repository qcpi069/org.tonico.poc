#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_KSMN7600_KS_7600J_work_rxlives.ksh
# Description    Execute the 
#                 rbate_reg.pk_get_work_rxlives_driver.prc_get_work_rxlives_driver
#                 PL/SQL package
# Parameters     Valid input parameters are ALV, RXC or RUC   
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
#  03/19/03  is31701                 initial script creation
#==============================================================================
#----------------------------------
# Caremark Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh


#--re-route DEV and QA Error E-mails
if [[ $REGION = "prod" ]];   then                                            
  if [[ $QA_REGION = "true" ]];   then                                       
    #--Running in the QA region                                               
    export ALTER_EMAIL_ADDRESS='Scott.Hull@caremark.com'                  
  else                                                                       
    #--Running in Prod region                                                 
    export ALTER_EMAIL_ADDRESS=''                                            
  fi                                                                         
else                                                                         
  #--Running in Development region                                            
  export ALTER_EMAIL_ADDRESS='Scott.Hull@caremark.com'                    
fi                                                                           


export EXEC_EMAIL=$SCRIPT_PATH"/rbate_email_base.ksh"
export JOB="KS_7600J"
export PKG_NAME=rbate_reg.pk_get_work_rxlives_driver.prc_get_work_rxlives_driver
export SCHEDULE="KSMN7600"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_work_rxlives"
export SCRIPT_NAME=$SCRIPT_PATH"/"$FILE_BASE".ksh"
export USER_PSWRD=`cat $SCRIPT_PATH/ora_user.fil`


#--Verify parameter 1 sent to script
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

#--Verify parameter 2 (optional) sent to script
#----if no parameter found, still call script.  If 2nd paramter is invalid e-mail and exit
NOALVLIVES=$2
#print $PARM1 '  *****   '   $NOALVLIVES
if [[ $NOALVLIVES = "noalvlives" || $NOALVLIVES = "alvlives"  ]]; then
# valid parameter: 
   print "valid parameter passed in for noalvlives " >> $LOG_FILE
elif [[ $NOALVLIVES != "" ]]
  then
# invalid parameter e-mail error and exit
   print "invalid parameter passed in for noalvlives " >> $LOG_FILE  
   export JOBNAME=$SCHEDULE" / "$JOB": INVALID PARAMETER='"$NOALVLIVES"'"
   export SCRIPTNAME=$SCRIPT_NAME
   export LOGFILE=''
   export EMAILPARM4=''
   . $EXEC_EMAIL
   exit 1
else 
   print "No parameter passed in for noalvlives"  $NOALVLIVES >> $LOG_FILE
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
#PKG_EXEC=$PKG_NAME\(\'$SOURCE\'\);
PKG_EXEC=$PKG_NAME\(\'$SOURCE\',\'$NOALVLIVES\'\);

print ' ' >> $LOG_FILE
print 'Exec stmt is: '$PKG_EXEC >> $LOG_FILE
print ' ' >> $LOG_FILE


#--build the sql file for SQLPLUS
cd $INPUT_PATH
cat > $SQL_FILE << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL $LOG_FILE
SET TIMING ON
set serveroutput on
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



