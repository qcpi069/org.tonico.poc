#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_process_frmly_all.ksh   
# Title         : Snapshot refresh.
#
# Description   : Calls procedure process_frmly_all with input parm of 
#                 cycle_gid. This procedure creates a set of tables 
#                 containing the formulary status for basket and drug 
#                 combinations.
# Maestro Job   : RI_4520J
#
# Parameters    : Cycle_GID
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-25-05   is45401     Added logic to FTP trigger file to the GDX system.
#                        This trigger file will kick off the Formulary 
#                        On/Off Status extract, and load the table 
#                        VRAP.TFORMULARY_DRUG_STATUS.
# 08-08-2002  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]]; then
    if [[ $QA_REGION = "true" ]]; then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS=""
        FTP_IP=R07PRD01
        GDX_INPUT_DIR="/GDX/"$REGION"/input"
        SCHEMA_OWNER="dma_rbate2"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        FTP_IP=R07PRD01
        GDX_INPUT_DIR="/GDX/"$REGION"/input"
        SCHEMA_OWNER="dma_rbate2"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
    FTP_IP=dwhtest1
    GDX_INPUT_DIR=/GDX/test/input
    SCHEMA_OWNER="dma_rbate2"
fi

FILE_BASE="rbate_process_frmly_all"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_ARCH_FILE=$FILE_BASE".log"
LOG_FILE=$OUTPUT_PATH/$LOG_ARCH_FILE
MAESTRO_TRG_FILE=$INPUT_PATH/"rbate_RIOR4520_RI_4525J.trg"
FTP_CMDS=$INPUT_PATH/$FILE_BASE"_ftp_commands.txt"
SQL_FILE=$INPUT_PATH/$FILE_BASE".sql"
PKG_LOG=$OUTPUT_PATH/$FILE_BASE"_pkg_log.log"

rm -f $LOG_FILE
rm -f $MAESTRO_TRG_FILE
rm -f $FTP_CMDS
rm -f $SQL_FILE
rm -f $PKG_LOG

print " "                                                                      >> $LOG_FILE
print `date` "Starting script "$SCRIPTNAME                                     >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# PKGEXEC is the full SQL command to be executed
#-------------------------------------------------------------------------#
if [[ $# -lt 1 ]]; then
    print " "                                                                  >> $LOG_FILE
    print "Insufficient arguments passed to script."                           >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    exit 1
else
    CYCLE_GID=$1
    print "Input Parameter = "$1                                               >> $LOG_FILE
fi

export Package_Name=$SCHEMA_OWNER".pk_fe_frmly.process_fe_frmly_all"
PKGEXEC=$Package_Name\(\'$CYCLE_GID\'\);

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#

print " "                                                                      >> $LOG_FILE
print "Exec stmt is "$PKGEXEC                                                  >> $LOG_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

cat > $SQL_FILE << EOF
whenever sqlerror exit 1
SPOOL $PKG_LOG
SET TIMING ON
exec $PKGEXEC;
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

RETCODE=$?

print " "                                                                      >> $LOG_FILE

if [[ $RETCODE != 0 ]]; then
    print "Error when running "$PKGEXEC                                        >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Oracle error is - "                                                 >> $LOG_FILE
    tail -20 $PKG_LOG                                                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Script will now abend."                                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
else
    print `date` " Starting FTP Trigger to kick off Maestro job on GDX"        >> $LOG_FILE

    #-------------------------------------------------------------------------#
    # Build FTP trigger file and FTP file to GDX
    #-------------------------------------------------------------------------#

    print " "                                                                  >> $LOG_FILE
    print `date` "FTPing Trigger file to GDX to kick off job"                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    print " "                                                                  >> $MAESTRO_TRG_FILE
    print "This trigger file is being sent from "                              >> $MAESTRO_TRG_FILE
    print "  "$SCRIPTNAME" on the "$REGION                                     >> $MAESTRO_TRG_FILE
    print "  SUN box.  This trigger file does not accompany a data file,"      >> $MAESTRO_TRG_FILE
    print "  rather it is only intended to trigger the Maestro job that will"  >> $MAESTRO_TRG_FILE
    print "  extract the Formulary On/Off GPO data from Oracle and load it"    >> $MAESTRO_TRG_FILE
    print "  in the GDX VRAP.TFORMULARY_DRUG_STATUS table.  "                  >> $MAESTRO_TRG_FILE
    print " "                                                                  >> $MAESTRO_TRG_FILE

    print 'cd '$GDX_INPUT_DIR                                                  >> $FTP_CMDS
    print 'put ' $MAESTRO_TRG_FILE ${MAESTRO_TRG_FILE##/*/} ' (replace'        >> $FTP_CMDS
    print 'quit'                                                               >> $FTP_CMDS
    ftp -i  $FTP_IP < $FTP_CMDS                                                >> $LOG_FILE

    RETCODE=$?

    print " "                                                                  >> $LOG_FILE
    print `date` "FTP complete "                                               >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        print "FTP completed UNSUCCESSFULLY - Return code = "$RETCODE          >> $LOG_FILE
    else
        print "FTP Completed Successfully."                                    >> $LOG_FILE
    fi
fi

print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " "                                                                   >> $LOG_FILE
   print "===================== J O B  A B E N D E D ======================"   >> $LOG_FILE
   print "  Error Executing "$SCRIPTNAME                                       >> $LOG_FILE
   print "  Look in "$LOG_FILE                                                 >> $LOG_FILE
   print "================================================================="   >> $LOG_FILE
      
# Send the Email notification 
   export JOBNAME="RIOR4520 / RI_4520J"
   export SCRIPTNAME=$SCRIPTNAME
   export LOGFILE=$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters"            >> $LOG_FILE
   print "JOBNAME is " $JOBNAME                                                >> $LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME                                          >> $LOG_FILE
   print "LOGFILE is " $LOGFILE                                                >> $LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4                                          >> $LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5                                          >> $LOG_FILE
   print "****** end of email parameters ******"                               >> $LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

print " "                                                                      >> $LOG_FILE
print "....Completed executing rbate_process_frmly_all.ksh ...."               >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH_FILE.`date +"%Y%j%H%M"`

rm -f $MAESTRO_TRG_FILE
rm -f $FTP_CMDS
rm -f $SQL_FILE
rm -f $PKG_LOG

exit $RETCODE

