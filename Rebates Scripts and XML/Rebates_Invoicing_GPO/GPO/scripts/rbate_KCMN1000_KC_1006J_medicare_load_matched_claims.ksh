#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_KCMN1000_KC_1006J_medicare_load_matched_claims.ksh
# Description  = Execute the pk_gather_medicare_claims.prc_load_matched_medicare_scr
#		   PL/SQL procedure
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
# 05/19/04  is31701                 initial script creation
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
export JOB="KC_1006J"
export PKG_NAME=dma_rbate2.PK_GATHER_MEDICARE_CLAIMS.prc_load_matched_medicare_scr
export SCHEDULE="KCMN1000"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_medicare_load_matched_claims"
export SCRIPT_NAME=$SCRIPT_PATH"/"$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export LOG_ARCH=$FILE_BASE".log"
export SQL_FILE=$FILE_BASE".sql"
export LOG_SQL_FILE=$OUTPUT_PATH/$FILE_BASE".sqllog"
export USER_PSWRD=`cat $SCRIPT_PATH/ora_user.fil`

export DATE_CNTRL_FILE="rbate_KCMN1000_KC_1000J_medicare_date_control_file.dat"

#--Delete the output log and sql file from previous execution if it exists.
rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $SCRIPT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$LOG_SQL_FILE

#--build and log the execute statement for SQLPLUS
PKG_EXEC=$PKG_NAME;

print ' ' >> $OUTPUT_PATH/$LOG_FILE
print 'Exec stmt is: '$PKG_EXEC >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE


#--build the sql file for SQLPLUS

cat > $SCRIPT_PATH/$SQL_FILE << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL $LOG_SQL_FILE
SET TIMING ON
exec $PKG_EXEC; 
quit;
EOF

print ' ' >> $OUTPUT_PATH/$LOG_FILE
print "executing SQL" >> $OUTPUT_PATH/$LOG_FILE
print `date` >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE

#--execute sql file in SQLPLUS
$ORACLE_HOME/bin/sqlplus -s $USER_PSWRD @$SCRIPT_PATH/$SQL_FILE

RC=$?

cat $LOG_SQL_FILE >> $OUTPUT_PATH/$LOG_FILE

#--Process the Return Code

if [[ $RC != 0 ]]; then
#----if non-zero, error occured.  e-mail error and copy log to archive directory
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
else
#----if zero, successful.  Move log to archive directory
print ' ' >> $OUTPUT_PATH/$LOG_FILE
print 'Schedule/Job : '$SCHEDULE' '$JOB >> $OUTPUT_PATH/$LOG_FILE
print 'completed successfully ' >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE
   mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
fi



