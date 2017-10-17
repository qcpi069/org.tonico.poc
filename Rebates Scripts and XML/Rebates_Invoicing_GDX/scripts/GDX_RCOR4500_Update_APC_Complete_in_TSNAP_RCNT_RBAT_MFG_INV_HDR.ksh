#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_RCOR4500_Update_APC_Complete_in_TSNAP_RCNT_RBAT_MFG_INV_HDR.ksh
# Title         :
#
# Description   : updatestsnap apc typ and used in apc status on CaRe Invoice
#
# Maestro Job   : RIOR4500 GD_7758J
#
# Parameters    : None
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 11-11-09   qcpu70x     Initial Creation
# 05-25-17   qcpi2d6     Update LAST_UPDT_TS in INV HDR table
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_GDX_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
    RETCODE=$1
    EMAILPARM4='MAILPAGER'
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
    . $SCRIPT_PATH/Common_GDX_APC_Status_update.ksh 345 ERR >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH
    exit $RETCODE
}
#-------------------------------------------------------------------------#

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
    export ALTER_EMAIL_ADDRESS="kurt.gries@caremark.com"
    LOG_FILE_SIZE_MAX=100
        SYSTEM="DEVELOPMENT"
        #FTP_DIR="/DBprog"
        FTP_DIR="assign2"
fi

# Variables
RETCODE=0
SCHEDULE="RIOR4500"
JOB="GD_7758J"
FILE_BASE="GDX_RCOR4500_Update_APC_Complete_in_TSNAP_RCNT_RBAT_MFG_INV_HDR"
SCRIPTNAME=$FILE_BASE".ksh"

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log"`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"

# Cleanup from previous run
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   }  >> $LOG_FILE

# Call the GDX APC status update
. $SCRIPT_PATH/Common_GDX_APC_Status_update.ksh 345 STRT >> $LOG_FILE

#-------------------------------------------------------------------------#
# Connect and Update the tabless
#-------------------------------------------------------------------------#


db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"  >> $LOG_FILE

RETCODE=$?


   if [[ $RETCODE != 0 ]]; then
      print "Error: couldn't connect to database " $SCRIPTNAME " ...          "            >> $LOG_FILE
      print "Return code is : <" $RETCODE ">"           >> $LOG_FILE
      exit_error $RETCODE
   fi

UPDT_STMNT="Update Vrap.rcnt_rbat_mfg_inv_hdr  "
UPDT_STMNT="$UPDT_STMNT set apc_load_cd = '1',last_updt_ts=current timestamp,LAST_UPDT_USER_ID='GD_7758J' "
UPDT_STMNT="$UPDT_STMNT where inv_id in (select inv_id from vrap.vsnap_apc_dtl where snap_apc_typ_cd = 3 and INV_STAT_CD = 1) "

print "CaRe Invoice APC Status udpate - $UPDT_STMNT"  >> $LOG_FILE
db2 -px "$UPDT_STMNT" >> $LOG_FILE
RETCODE=$?

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: Update failed in " $SCRIPTNAME " ...          "            >> $LOG_FILE
      print "Return code is : <" $RETCODE ">"           >> $LOG_FILE
      exit_error $RETCODE
   fi

UPDT_STMNT="Update Vrap.TSNAP set SNAP_APC_TYP_CD = 4 where SNAP_APC_TYP_CD = 3 "

print "SNAP APC Type Code - $UPDT_STMNT"  >> $LOG_FILE
db2 -px "$UPDT_STMNT"  >> $LOG_FILE
RETCODE=$?

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: Update failed in " $SCRIPTNAME " ...          "            >> $LOG_FILE
      print "Return code is : <" $RETCODE ">"           >> $LOG_FILE
      exit_error $RETCODE
   fi

# Call the GDX APC status update
. $SCRIPT_PATH/Common_GDX_APC_Status_update.ksh 345 END

   if [[ $FILE_SIZE -gt $LOG_FILE_SIZE_MAX ]]; then
      mv -f $LOG_FILE $LOG_FILE_ARCH
   fi

exit $RETCODE