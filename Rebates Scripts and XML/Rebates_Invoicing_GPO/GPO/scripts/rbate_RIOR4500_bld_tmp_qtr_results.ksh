#!/bin/ksh
#--------------------------------------------------------------------------#
# Script        : rbate_RIOR4500_bld_tmp_qtr_results.ksh   
# Title         : Refreshes the data in TMP_QTR_RESULTS Oracle table
#
# Description   : Accepts the Quarterly cycle gid in as a parameter 
#               :   (optional), and also the Invoice Version number 
#               :   (optional), then refreshes the TMP_QTR_RESULTS table 
#               :   with the APC file data for that calendar quarter.
#
# Maestro Job   : Normally run during RIOR4500 APC Schedule, but no job
#               :   was created for this script. Typically the
#               :   RI_4500J Rebated claim extract script calls this one.
#
# Parameters    : CYCLE_GID (optional) INV_VER_NB (optional)
#
# Output        : Log file as $OUTPUT_PATH/rbate_RIOR4500_bld_tmp_qtr_results.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date        ID      PARTE #  Description
# ---------  ---------  -------  ------------------------------------------#
# 07-09-04    IS45401   5994785  Initial Creation.
#--------------------------------------------------------------------------#
 
#--------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#--------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
  if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
    export ALTER_EMAIL_ADDRESS='randy.redus@Caremark.com'
    SCHEMA_OWNER="dma_rbate2"
  else
    # Running in Prod region
    export ALTER_EMAIL_ADDRESS=''
    SCHEMA_OWNER="dma_rbate2"
  fi
else
  # Running in Development region
  export ALTER_EMAIL_ADDRESS='randy.redus@Caremark.com'
  SCHEMA_OWNER="dma_rbate2"
fi
 
RETCODE=0
SCHEDULE="RIOR4500"
TQR_FILE_BASE="rbate_"$SCHEDULE"_bld_tmp_qtr_results"
TQR_SCRIPTNAME=$TQR_FILE_BASE".ksh"
APC_OUTPUT_DIR=$OUTPUT_PATH/apc
TQR_LOG_FILE=$OUTPUT_PATH/$TQR_FILE_BASE".log"
TQR_LOG_ARCH=$TQR_FILE_BASE".log"
SQL_FILE=$APC_OUTPUT_DIR/$TQR_FILE_BASE".sql"
ORA_PACKAGE_NME=$SCHEMA_OWNER".pk_bld_tmp_qtr_results_driver.prc_bld_tmp_qtr_results_driver"
ORACLE_PKG_RETCODE=$OUTPUT_PATH/$TQR_FILE_BASE"_oracle_return_code.log"

rm -f $TQR_LOG_FILE
rm -f $SQL_FILE
rm -f $ORACLE_PKG_RETCODE

print $APC_OUTPUT_DIR >> $TQR_LOG_FILE

print "Starting "$TQR_SCRIPTNAME                                               >> $TQR_LOG_FILE
print `date`                                                                   >> $TQR_LOG_FILE

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
# PKGEXEC is the full SQL command to be executed
#-------------------------------------------------------------------------#

print " "                                                                      >> $TQR_LOG_FILE

if [[ $# -lt 1 ]]; then
    print "Cycle gid was not passed in, calling package without input parms."  >> $TQR_LOG_FILE
    ORA_PKG_CYCLE_INPUT=";"
else
    #At least one parameter was passed in, and the first parm should be Cycle_Gid
    CYCLE_GID=$1
    print "Quarterly Cycle GID passed to script is >"$1"<"                     >> $TQR_LOG_FILE
    ORA_PKG_CYCLE_INPUT=\($CYCLE_GID\)";"
    if [[ $# -eq 2 ]]; then 
        INV_VER_NB=$2
        print "Invoice Version passed to script is >"$INV_VER_NB"<"            >> $TQR_LOG_FILE
        ORA_PKG_CYCLE_INPUT=\($CYCLE_GID_INPUT","$INV_VER_NB\)";"
    else
        if [[ $# -gt 2 ]]; then 
            #Error in input parms - more than 2 parameters passed in.
            print "More than two parameters were passed into the script."      >> $TQR_LOG_FILE
            print "Parameter 1 = >"$CYCLE_GID"<"                               >> $TQR_LOG_FILE
            print "Parameter 2 = >"$INV_VER_NB"<"                              >> $TQR_LOG_FILE
            print "Parameter 3 = >"$3"<"                                       >> $TQR_LOG_FILE
            print "Abending "                                                  >> $TQR_LOG_FILE
            RETCODE=1.
        fi 
    fi
fi
print " "                                                                      >> $TQR_LOG_FILE

#----------------------------------
# Create the Package to be executed
#----------------------------------

if [[ $RETCODE = 0 ]]; then

    PKGEXEC=$ORA_PACKAGE_NME$ORA_PKG_CYCLE_INPUT

    print " "                                                                      >> $TQR_LOG_FILE
    print `date`                                                                   >> $TQR_LOG_FILE
    print "Beginning Package call of " $PKGEXEC                                    >> $TQR_LOG_FILE
    print " "                                                                      >> $TQR_LOG_FILE

    #----------------------------------
    # Oracle userid/password
    #----------------------------------

    db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

    #-------------------------------------------------------------------------#
    # Execute the SQL run the Package to manipulate the IPDR file
    #-------------------------------------------------------------------------#

# CANNOT INDENT THIS!!  IT WONT FIND THE EOF!
cat > $SQL_FILE << EOF
set linesize 5000
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

    print " "                                                                      >> $TQR_LOG_FILE
    print `date`                                                                   >> $TQR_LOG_FILE
    print "Package call Return Code is :" $RETCODE                                 >> $TQR_LOG_FILE
    print " "                                                                      >> $TQR_LOG_FILE
fi
    
if [[ $RETCODE = 0 ]]; then
    print "Successfully completed Package call of " $PKGEXEC                   >> $TQR_LOG_FILE
else
    print "Failure in Package call of " $PKGEXEC                               >> $TQR_LOG_FILE
    print " "                                                                  >> $TQR_LOG_FILE

    #ORACLE_PKG_RETCODE file will be empty if package was successful, will hold ORA errors if unsuccessful
    cat $ORACLE_PKG_RETCODE                                                    >> $TQR_LOG_FILE
    print " "                                                                  >> $TQR_LOG_FILE 
    print "===================== J O B  A B E N D E D ======================"  >> $TQR_LOG_FILE
    print "  Error Executing "$TQR_SCRIPTNAME"          "                          >> $TQR_LOG_FILE
    print "  Look in "$TQR_LOG_FILE                                                >> $TQR_LOG_FILE
    print "================================================================="  >> $TQR_LOG_FILE

    # Send the Email notification 

    export JOBNAME=$SCHEDULE" / called from RI_4500J in schedule RIOR4500"
    export TQR_SCRIPTNAME=$SCRIPT_PATH/$TQR_SCRIPTNAME
    export LOGFILE=$TQR_LOG_FILE
    export EMAILPARM4="  "
    export EMAILPARM5="  "

    print "Sending email notification with the following parameters"           >> $TQR_LOG_FILE
    print "JOBNAME is N/A"                                                     >> $TQR_LOG_FILE 
    print "TQR_SCRIPTNAME is " $TQR_SCRIPTNAME                                         >> $TQR_LOG_FILE
    print "LOGFILE is " $LOGFILE                                               >> $TQR_LOG_FILE
    print "EMAILPARM4 is " $EMAILPARM4                                         >> $TQR_LOG_FILE
    print "EMAILPARM5 is " $EMAILPARM5                                         >> $TQR_LOG_FILE
    print "****** end of email parameters ******"                              >> $TQR_LOG_FILE

    . $SCRIPT_PATH/rbate_email_base.ksh
    cp -f $TQR_LOG_FILE $LOG_ARCH_PATH/$TQR_LOG_ARCH.`date +"%Y%j%H%M"`
    exit $RETCODE
fi

#Clean up files 
rm -f $SQL_FILE
rm -f $ORACLE_PKG_RETCODE

print "....Completed executing " $TQR_SCRIPTNAME " ...."                           >> $TQR_LOG_FILE
mv -f $TQR_LOG_FILE $LOG_ARCH_PATH/$TQR_LOG_ARCH.`date +"%Y%j%H%M"`

return $RETCODE

