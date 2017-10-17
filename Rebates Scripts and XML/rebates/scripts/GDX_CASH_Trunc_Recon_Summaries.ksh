#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_CASH_Trunc_Recon_Summaries.ksh
# Title         :
#
# Description   : Queries the RCNT_RECN_SUMM_QUE and looks for
#                 RECN_SUMM_STAT_CD where there is an error or an summary
#                 in progress moving data from the Recon summaries into
#                 the TRBI database.
#                 When no process is running and no recons are in error
#                 then truncate the two Recon summary tables:
#                 VRAP.RCNT_RECN_PSTN_SUMM and VRAP.RCNT_RECN_OBJ_SUMM
#
# Maestro Job   : RCDYnnnn GD_nnnnJ
#
# Parameters    : None
#
# Output        : Log file as $LOG_DIR/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02-13-13   qcpi733     Initial Creation for ITPR0001971
# 08-05-13   qcpi2d6     Changed REGION to get the different streams
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RCI_Environment.ksh

  . /home/user/udbcae/sqllib/db2profile

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
   RETCODE=$1
   ERROR=$2
   EMAIL_SUBJECT=$SCRIPTNAME" Abended In "$REGION" "`date`

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

# Region specific variables
if [[ $REGION = "PROD" ]];   then
    export ALTER_EMAIL_TO_ADD=""
    EMAIL_TO_ADD="gdxitd@caremark.com"
fi
if [ $REGION = "SIT1" -o $REGION = "SIT2" ];   then
    export ALTER_EMAIL_TO_ADD="gdxsittest@caremark.com"
    EMAIL_TO_ADD="gdxsittest@caremark.com"
fi
if [ $REGION = "DEV1" -o $REGION = "DEV2" ];   then
    export ALTER_EMAIL_TO_ADD="randy.redus@caremark.com"
    EMAIL_TO_ADD="randy.redus@caremark.com"
fi

# Variables and temp files
RETCODE=0
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"

EMAIL_SUB="System cannot truncate Recon Summaries"
EMAIL_BODY=$OUTPUT_DIR/$SCRIPTNAME"_email_body.txt"
rm -f $EMAIL_BODY
print "Informational mostly, but if repeatedly occurring each week research "  >> $EMAIL_BODY
print "should ensue. \n\nThe GDX CASH UNIX script was not able to truncate  "  >> $EMAIL_BODY
print "the Recon summary tables because it found there were "                  >> $EMAIL_BODY
print "RECN_SUMM_STAT_CD values not in COMPLETE (5) or Error Resolved (110)."  >> $EMAIL_BODY
print "\n\nIf there are RCNT_RECN_SUMM_QUE.RECN_SUMM_STAT_CD error values of " >> $EMAIL_BODY
print "99-109, these need to be researched and reset to 1 or 110, otherwise "  >> $EMAIL_BODY
print "this truncate script will never issue the truncate."                    >> $EMAIL_BODY
print "\n\n--------------------"                                               >> $EMAIL_BODY
print "This email was generated from $SCRIPTNAME on the INFA box when the "    >> $EMAIL_BODY
print "script was unable to issue the truncate."                               >> $EMAIL_BODY
print "Scripts directory: $SCRIPTS_DIR"                                        >> $EMAIL_BODY

SQL_FILE=$OUTPUT_DIR/$FILE_BASE"_RCNT_RECN_SUMM_QUE.sql"
DATA_FILE=$OUTPUT_DIR/$FILE_BASE"_RCNT_RECN_SUMM_QUE_out.dat"

# LOG FILES
LOG_FILE_ARCH="${ARCH_LOG_DIR}/${FILE_BASE}.log"`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_DIR}/${FILE_BASE}.log"

rm -f $SQL_FILE
rm -f $DATA_FILE
rm -f $TODAYS_DATE_FILE
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print " "
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   }                                                                           > $LOG_FILE

#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

print " "                                                                      >> $LOG_FILE
sql="db2 -p connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"
db2 -p connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD                >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Error: couldn't connect to database " $SCRIPTNAME " ...          "   >> $LOG_FILE
   print "Return code is : <" $RETCODE ">"                                     >> $LOG_FILE
   exit_error $RETCODE
fi

#-------------------------------------------------------------------------#
# Get counts of Recon summary statuses where truncate cannot run
#-------------------------------------------------------------------------#

# If there are RCNT_RECN_SUMM_QUE rows where the RECN_SUMM_STAT_CD values reflect
#   that the Summary is running (values 1-4) or in error and needs to be researched
#   (error value not 110 then the truncates cannot run.

SQL_FILE="select count(*) from VRAP.RCNT_RECN_SUMM_QUE where RECN_SUMM_STAT_CD not in (10,110)"

print " "                                                                      >> $LOG_FILE
print "SQL to run: $SQL_FILE"                                                  >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

db2 -x $SQL_FILE > $DATA_FILE
RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print " "                                                                  >> $LOG_FILE
    print "ERROR: Select of row count from RCNT_RECN_SUMM_QUE"                 >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print $SQL_FILE                                                            >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Return code is : <" $RETCODE ">"                                    >> $LOG_FILE
    exit_error $RETCODE
fi

read row_cnt < $DATA_FILE

print " "                                                                      >> $LOG_FILE
print "Count returned: $row_cnt"                                               >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

# If the count returned is > 0 then cannot issue the truncate.  Simply complete the script.

if [[ $row_cnt -gt 0 ]]; then
    print " "                                                                  >> $LOG_FILE
    print "Cannot issue the truncate, email sent "                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    # Send email to group that the truncate did not run
    #quotes around the EMAIL_SUBJECT are required to preserve spaces in the subject
    mailx -s "$EMAIL_SUB"  $EMAIL_TO_ADD < $EMAIL_BODY
else
    print " "                                                                  >> $LOG_FILE
    print "All RCNT_RECN_SUMM_QUE rows are in ETL complete or 110 error "      >> $LOG_FILE
    print "status.  Issue the truncates"                                       >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    #Issue the truncate
    TRUNC_SQL="import from /dev/null of del replace into VRAP.RCNT_RECN_PSTN_SUMM"
    db2 -stvxw $TRUNC_SQL                                                      >> $LOG_FILE
    RETCODE=$?

    if [[ $RETCODE != 0 ]]; then
        print " "                                                              >> $LOG_FILE
        print "ERROR: Could not complete truncation:"                          >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print $TRUNC_SQL                                                       >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Return code is : <" $RETCODE ">"                                >> $LOG_FILE
        exit_error $RETCODE
    fi

    TRUNC_SQL="import from /dev/null of del replace into VRAP.RCNT_RECN_OBJ_SUMM"

    db2 -stvxw $TRUNC_SQL                                                      >> $LOG_FILE
    RETCODE=$?

    if [[ $RETCODE != 0 ]]; then
        print " "                                                              >> $LOG_FILE
        print "ERROR: Could not complete truncation:"                          >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print $TRUNC_SQL                                                       >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Return code is : <" $RETCODE ">"                                >> $LOG_FILE
        exit_error $RETCODE
    fi
fi #end row_cnt check

#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
{
    print "********************************************"
    print "Finishing the script $SCRIPTNAME ......"
    print `date +"%D %r %Z"`
    print "Final return code is : <" $RETCODE ">"
    print " "
}                                                                              >> $LOG_FILE

#-------------------------------------------------------------------------#
# move log file to archive with timestamp
#-------------------------------------------------------------------------#

rm -f $EMAIL_BODY
rm -f $SQL_FILE
rm -f $DATA_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH

exit $RETCODE

