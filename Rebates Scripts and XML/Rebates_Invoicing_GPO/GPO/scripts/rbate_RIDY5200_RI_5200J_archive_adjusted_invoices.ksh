#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIDY5200_RI_5200J_archive_adjusted_invoices.ksh   
# Title         : APC file processing.
#
# Description   : Calls the Oracle Stored package that Archives any 
#               :   invoices in 'AJ' or 'NJ' adjusted status.
# Maestro Job   : RIDY5200 RI_5200J, runs daily
#
# Parameters    : None
#
# Output        : Log file as $OUTPUT_PATH/rbate_RIDY5200_RI_5200J_archive_adjusted_invoices.ksh
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 06-22-04   is45401     Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
  if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
    ALTER_EMAIL_ADDRESS='randy.redus@caremark.com'
    SCHEMA_OWNER="dma_rbate2"
  else
    # Running in Prod region
    ALTER_EMAIL_ADDRESS=''
    SCHEMA_OWNER="dma_rbate2"
  fi
else
  # Running in Development region
  ALTER_EMAIL_ADDRESS='randy.redus@caremark.com'
  SCHEMA_OWNER="dma_rbate2"
fi

SCHEDULE="RIDY5200"
JOB="RI_5200J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_archive_adjusted_invoices"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
LOG_ARCH=$FILE_BASE".log"
ORA_PACKAGE_NME=$SCHEMA_OWNER".pk_archive_adjstd_invoice.prc_archive_adjstd_inv_driver"
ORACLE_PKG_RETCODE=$OUTPUT_PATH/$FILE_BASE"_oracle_return_code.log"
SQL_FILE=$OUTPUT_PATH/$FILE_BASE".sql"

rm -f $LOG_FILE
rm -f $ORACLE_PKG_RETCODE
rm -f $SQL_FILE

print "Starting "$SCRIPTNAME                                                   >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#----------------------------------
# Create the Package to be executed
#----------------------------------

PKGEXEC=$ORA_PACKAGE_NME

print " "                                                                      >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE
print "Beginning Package call of " $PKGEXEC                                    >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Execute the SQL run the Package to manipulate the IPDR file
#-------------------------------------------------------------------------#

# CANNOT INDENT THIS!!  IT WONT FIND THE EOF!
cat > $SQL_FILE << EOF
set linesize 5200
set flush off
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP on
set verify off
whenever sqlerror exit 1
SPOOL $ORACLE_PKG_RETCODE

EXEC $PKGEXEC

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

RETCODE=$?

print " "                                                                      >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE
print "Package call Return Code is :" $RETCODE                                 >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
    
if [[ $RETCODE = 0 ]]; then
    print "Successfully completed Package call of " $PKGEXEC                   >> $LOG_FILE
else
    print "Failure in Package call of " $PKGEXEC                               >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    #ORACLE_PKG_RETCODE file will be empty if package was successful, will hold ORA errors if unsuccessful
    cat $ORACLE_PKG_RETCODE                                                    >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE 
    print "===================== J O B  A B E N D E D ======================"  >> $LOG_FILE
    print "  Error Executing "$SCRIPTNAME"          "                          >> $LOG_FILE
    print "  Look in "$LOG_FILE                                                >> $LOG_FILE
    print "================================================================="  >> $LOG_FILE

    # Send the Email notification 
    export JOBNAME=$SCHEDULE" / "$JOB
    export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
    export LOGFILE=$LOG_FILE
    export EMAILPARM4="  "
    export EMAILPARM5="  "

    print "Sending email notification with the following parameters"           >> $LOG_FILE
    print "JOBNAME is " $JOBNAME                                               >> $LOG_FILE 
    print "SCRIPTNAME is " $SCRIPTNAME                                         >> $LOG_FILE
    print "LOGFILE is " $LOGFILE                                               >> $LOG_FILE
    print "EMAILPARM4 is " $EMAILPARM4                                         >> $LOG_FILE
    print "EMAILPARM5 is " $EMAILPARM5                                         >> $LOG_FILE
    print "****** end of email parameters ******"                              >> $LOG_FILE

    . $SCRIPT_PATH/rbate_email_base.ksh
    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
    exit $RETCODE
fi

print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`

rm -f $LOG_FILE
rm -f $ORACLE_PKG_RETCODE
rm -f $SQL_FILE

exit $RETCODE

