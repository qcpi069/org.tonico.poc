#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIOR4500_RI_4490J_rxmax_process.ksh   
# Title         : APC file processing.
#
# Description   : Add RXMAX claims into the TMP_QTR_RESULTS
# Maestro Job   : RIOR4500 RI_4490J
#
# Parameters    : N/A
#
# Output        : Log file as $OUTPUT_PATH/rbate_RIOR4500_RI_4490J_rxmax_process.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date        ID      PARTE #  Description
# ---------  ---------  -------  ------------------------------------------#
# 09-14-2007  K. Gries           Initial Creation Call RXMAX Procedure.
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
  if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
    export ALTER_EMAIL_ADDRESS='richard.hutchison@Caremark.com'
    MVS_FTP_PREFIX='TEST.X'
    SCHEMA_OWNER="dma_rbate2"
    FTP_DIR=/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/APC_files/test
  else
    # Running in Prod region
    export ALTER_EMAIL_ADDRESS=''
    MVS_FTP_PREFIX='PCS.P'
    SCHEMA_OWNER="dma_rbate2"
    FTP_DIR=/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/APC_files
  fi
else
  # Running in Development region
  export ALTER_EMAIL_ADDRESS='nick.tucker@Caremark.com'
  MVS_FTP_PREFIX='TEST.D'
  SCHEMA_OWNER="dma_rbate2"
  FTP_DIR=/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/APC_files/test
fi

RETCODE=0
RETCODE=0
SCHEDULE="RIOR4500"
JOB="RI_4490J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_rxmax_process"
SCRIPTNAME=$FILE_BASE".ksh"
APC_OUTPUT_DIR=$OUTPUT_PATH/apc
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
LOG_ARCH=$FILE_BASE".log"
SQL_FILE=$APC_OUTPUT_DIR/$FILE_BASE".sql"
ORA_PACKAGE_NME=$SCHEMA_OWNER".pk_rxmax_apc_processing.prc_rxmax_process_driver"
ORACLE_PKG_RETCODE=$OUTPUT_PATH/$FILE_BASE"_oracle_return_code.log"
FTP_COM_FILE=$OUTPUT_PATH/$FILE_BASE"_ftpcommands.txt"
FTP_IP=AZSHISP00
STAGING_DIR='/staging/rebate2/'
RXMAX_REBATED='apc_gdx_claims_replaced_by_rxmax_rebated.txt'
RXMAX_OMITTED='rxmax_claims_not_in_gdx_apc_status.txt'

rm -f $LOG_FILE
rm -f $SQL_FILE
rm -f $ORACLE_PKG_RETCODE

print $APC_OUTPUT_DIR >> $LOG_FILE

print "Starting "$SCRIPTNAME                                               >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
# PKGEXEC is the full SQL command to be executed
#-------------------------------------------------------------------------#

print " "                                                                      >> $LOG_FILE

if [[ $# -lt 1 ]]; then
    print "Cycle gid was not passed in, calling package without input parms."  >> $LOG_FILE
    ORA_PKG_CYCLE_INPUT=";"
else
    #At least one parameter was passed in, and the first parm should be Cycle_Gid
    CYCLE_GID=$1
    print "Quarterly Cycle GID passed to script is >"$1"<"                     >> $LOG_FILE
    ORA_PKG_CYCLE_INPUT=\($CYCLE_GID\)";"
    if [[ $# -eq 2 ]]; then 
        INV_VER_NB=$2
        print "Invoice Version passed to script is >"$INV_VER_NB"<"            >> $LOG_FILE
        ORA_PKG_CYCLE_INPUT=\($CYCLE_GID","$INV_VER_NB\)";"
    else
        if [[ $# -gt 2 ]]; then 
            #Error in input parms - more than 2 parameters passed in.
            print "More than two parameters were passed into the script."      >> $LOG_FILE
            print "Parameter 1 = >"$CYCLE_GID"<"                               >> $LOG_FILE
            print "Parameter 2 = >"$INV_VER_NB"<"                              >> $LOG_FILE
            print "Parameter 3 = >"$3"<"                                       >> $LOG_FILE
            print "Abending "                                                  >> $LOG_FILE
            RETCODE=1.
        fi 
    fi
fi
print " "                                                                      >> $LOG_FILE

#----------------------------------
# Create the Package to be executed
#----------------------------------

if [[ $RETCODE = 0 ]]; then

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

    print " "                                                                      >> $LOG_FILE
    print `date`                                                                   >> $LOG_FILE
    print "Package call Return Code is :" $RETCODE                                 >> $LOG_FILE
    print " "                                                                      >> $LOG_FILE
fi

if [[ $RETCODE = 0 ]]; then
    print "Successfully completed Package call of " $PKGEXEC                   >> $LOG_FILE
    print ' ' >> $LOG_FILE
    print "================= RXMAX APC process SQL COMPLETED =====================" >> $LOG_FILE
    print "RXMAX APC process FTP starting" >> $LOG_FILE
    print `date` >> $LOG_FILE
    print "================================================================="   >> $LOG_FILE
    print "cd " $FTP_DIR >> $FTP_COM_FILE
    print "put " $STAGING_DIR$RXMAX_REBATED" " $RXMAX_REBATED " (replace" >> $FTP_COM_FILE
    print "put " $STAGING_DIR$RXMAX_OMITTED" " $RXMAX_OMITTED " (replace" >> $FTP_COM_FILE
    print "quit" >> $FTP_COM_FILE
    ftp -i  $FTP_IP < $FTP_COM_FILE >> $LOG_FILE
    print "RXMAX APC process FTP completed" >> $LOG_FILE
else
    print ' ' >> $LOG_FILE
    print "=================== RXMAX APC process SQL FAILED ======================" >> $LOG_FILE
    print "RXMAX APC process SQL FAILED did not complete successfully" >> $LOG_FILE 
    print "UNIX Return code = " $RETCODE >> $LOG_FILE
    #ORACLE_PKG_RETCODE file will be empty if package was successful, will hold ORA errors if unsuccessful
    cat $ORACLE_PKG_RETCODE                                                    >> $LOG_FILE
    print " " >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    print "Failure in Package call of " $PKGEXEC                               >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE 
    print "===================== J O B  A B E N D E D ======================"  >> $LOG_FILE
    print "  Error Executing "$SCRIPTNAME"          "                          >> $LOG_FILE
    print "  Look in "$LOG_FILE                                                >> $LOG_FILE
    print "================================================================="  >> $LOG_FILE

    # Send the Email notification 

    export JOBNAME=$SCHEDULE
    export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
    export LOGFILE=$LOG_FILE
    export EMAILPARM4="  "
    export EMAILPARM5="  "

    print "Sending email notification with the following parameters"           >> $LOG_FILE
    print "JOBNAME is N/A"                                                     >> $LOG_FILE 
    print "SCRIPTNAME is " $SCRIPTNAME                                         >> $LOG_FILE
    print "LOGFILE is " $LOGFILE                                               >> $LOG_FILE
    print "EMAILPARM4 is " $EMAILPARM4                                         >> $LOG_FILE
    print "EMAILPARM5 is " $EMAILPARM5                                         >> $LOG_FILE
    print "****** end of email parameters ******"                              >> $LOG_FILE

    . $SCRIPT_PATH/rbate_email_base.ksh
    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
    exit $RETCODE
fi

#Clean up files 
rm -f $SQL_FILE
rm -f $ORACLE_PKG_RETCODE

print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE
