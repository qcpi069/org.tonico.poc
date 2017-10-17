#!/bin/ksh
#set -x
#--------------------------------------------------------------------------#
#   Date                  Description
# ----------  ----------  -------------------------------------------------#
#
# 09/30/2011   qcoi08g    Change the IP address from 204.99.13.27 to
#                         paz1trendvip.caremarkrx.net.
# 08-01-2009   qcpi08a    Initial Creation.
#
#--------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark GDX Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        SYSTEM="UAT"
        export SMTP_HOST="paz1trendvip.caremarkrx.net"
        export TO_MAIL="ITDREBCNTRCTR@caremark.com"
        export FROM_MAIL="APCToSAP@caremark.com"
    else
        # Running in Prod region
        SYSTEM="PRD"
        export SMTP_HOST="paz1trendvip.caremarkrx.net"
        export TO_MAIL="ITDREBCNTRCTR@caremark.com"
        export FROM_MAIL="APCToSAP@caremark.com"
    fi
else
    # Running in Development region
    SYSTEM="DEV"
    export SMTP_HOST="paz1trendvip.caremarkrx.net"
    export TO_MAIL="yanping.zhao@caremark.com"
    export FROM_MAIL="APCToSAP@caremark.com"
fi

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
   RETCODE=$1
   ERROR=$2
   EMAIL_SUBJECT="APC_To_SAP_Ready_Status Error "$SYSTEM

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   {
        print " "
        print $ERROR
        print " "
        print " !!! Aborting !!!"
        print " "
        print "return_code = " $RETCODE
        print " "
        print " ------ Ending script " $SCRIPT `date`
   }    >> $LOG_FILE

   mailx -s "$EMAIL_SUBJECT" $TO_MAIL                        < $LOG_FILE
   cp -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE
}

cd $SCRIPT_PATH

#-------------------------------------------------------------------------#
# Variables
#-------------------------------------------------------------------------#

RETCODE=0
SCRIPTNAME=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG_FILE=$LOG_PATH/$FILE_BASE".log"
LOG_FILE_ARCH=$LOG_ARCH_PATH/$FILE_BASE".log."`date +"%Y%j%H%M"`
SQL_STATEMENT=$INPUT_PATH/$FILE_BASE."sql"

rm -f $LOG_FILE
rm -f $SQL_STATEMENT

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   } > $LOG_FILE

#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

   print "Connecting to GDX database......"                                    >> $LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >> $LOG_FILE
   RETCODE=$?
   print "Connect to $DATABASE: RETCODE=<" $RETCODE ">"                        >> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: couldn't connect to database......"                        >> $LOG_FILE
      exit_error $RETCODE
   fi

#-------------------------------------------------------------------------#
# Create SQL Statement
#-------------------------------------------------------------------------#

cat > $SQL_STATEMENT << EOFSQL

   UPDATE VRAP.RCNT_RECN_DSTR_HDR 
      SET DSTR_STAT_CD = 10
    WHERE DSTR_STAT_CD = 3;

   UPDATE VRAP.TSNAP
      SET SNAP_XMIT_STAT_CD = 10
    WHERE SNAP_XMIT_STAT_CD = 3; 
     
EOFSQL

#-------------------------------------------------------------------------#
# Update Status 
#-------------------------------------------------------------------------#

   print "Update Status ...... "                >> $LOG_FILE

   db2 -txf $SQL_STATEMENT             >> $LOG_FILE

   RETCODE=$?
   print "Update Status, RETCODE=<" $RETCODE ">"        >> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then                           
       print " "                                           >> $LOG_FILE
       print "Error: Update Status ...... "                >> $LOG_FILE
       exit_error $RETCODE
   fi

#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
   {
      print "********************************************"
      print "Finishing the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "Final return code is : <" $RETCODE ">"
   }  >> $LOG_FILE

#-------------------------------------------------------------------------#
# move log file to archive with timestamp
#-------------------------------------------------------------------------#

   mv -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE
 
