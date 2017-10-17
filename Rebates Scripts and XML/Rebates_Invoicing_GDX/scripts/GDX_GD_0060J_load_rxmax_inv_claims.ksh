#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script        : GDX_GD_0060J_load_rxmax_inv_claims.ksh    
# Title         : Load the GDX_GD_0060J_rxmax_inv_claims.dat file into
#         the vrap.trmax_inv_claims table.
#                 
#
# Description   : This script loads a pipe delimited file containg the 
#             PharamaCare invoiced claims. 
#                 The file will be loaded into Rebate GDX table: 
#                         vrap.trmax_inv_claims 
#                 
#                 The load is a full replace of the table.
#
#
# Parameters    : N/A 
# 
# Output        : Log file as $LOG_FILE
#
# Input Files   : GDX/prod/input
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 12-12-07   is45401     Added logic to query table after loading to 
#                        identify any duplicate claims and abend if found.
# 07-26-07   is31701     Initial Creation
# 
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
#-------------------------------------------------------------------------#
# Call the Common used script functions to make functions available
#-------------------------------------------------------------------------#
#. $SCRIPT_PATH/Common_GDX_Script_Functions.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    EMAILPARM4="MAILPAGER"
    EMAILPARM5="  "

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    {
        print "Sending email notification with the following parameters"

        print "JOBNAME is $JOBNAME"                     
        print "SCRIPTNAME is $SCRIPTNAME"                   
        print "LOG_FILE is $LOG_FILE"                       
        print "EMAILPARM4 is $EMAILPARM4"               
        print "EMAILPARM5 is $EMAILPARM5"

        print "****** end of email parameters ******"
    } >> $LOG_FILE

   . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH
    exit $RETCODE
}

#-------------------------------------------------------------------------#
# Region specific variables
#-------------------------------------------------------------------------#


if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_TO_ADDY=""
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXAPC@Caremark.com"
    else
        # Running in Prod region
        export ALTER_EMAIL_TO_ADDY=""
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXAPC@caremark.com"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_TO_ADDY="randy.redus@caremark.com"
    EMAIL_FROM_ADDY=$ALTER_EMAIL_TO_ADDY
# uncomment to send test emails to users
#    EMAIL_TO_ADDY="gdxitd@caremark.com, andrew.borushik@caremark.com,douglas.briggs@caremark.com,jim.dixon@caremark.com,paul.dressel@caremark.com,brian.epp@caremark.com,brent.knouse@caremark.com,sandip.paul@caremark.com,joel.shafron@caremark.com"
    EMAIL_TO_ADDY=$ALTER_EMAIL_TO_ADDY
fi


# Variables
RETCODE=0
SCHEDULE="GDDY0010"
JOB="GD_0060J"
SCRIPTNAME=$(basename $0 | sed -e 's/.ksh$//')

# LOG FILES
LOG_FILE_ARCH=$(echo $SCRIPTNAME|awk -F. "{print $1}")".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE_NM=$(echo $SCRIPTNAME|awk -F. "{print $1}")".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_NM

UDB_LOAD_MSG_FILE=$LOG_FILE".load"
UDB_LOAD_TABLE_NAME="VRAP.TRXMAX_INV_CLAIMS"
UDB_EXPORT_MSG_FILE=$OUTPUT_PATH/$SCRIPTNAME"_export_msg_file.txt"
UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS=$OUTPUT_PATH/$SCRIPTNAME"_export_data.dat"
UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS=$OUTPUT_PATH/$SCRIPTNAME"_export_data_colhdrs.dat"

RXMAX_DUP_CLAIM_EXPORT_SQL="export to $UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS of del modified by coldel| "
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" SELECT EXTNL_CLAIM_ID "
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,EXTNL_CLAIM_SEQ_NB"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,CLAIM_TYP"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,CARRIER_ID"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,NDC_ID"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,MANFCTR_ENTITY_ID"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,QUARTER_ID"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,FLAT_DISCNT_AMT"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,PP_DISCNT_AMT"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,PERF_RQSTD_DISCNT_AMT"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,BONUS_RQSTD_DISCNT_AMT"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ,ADMIN_FEE_AMT"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" FROM $UDB_LOAD_TABLE_NAME"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" WHERE (EXTNL_CLAIM_ID,EXTNL_CLAIM_SEQ_NB,CLAIM_TYP,CARRIER_ID) in"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL"     (SELECT EXTNL_CLAIM_ID,EXTNL_CLAIM_SEQ_NB,CLAIM_TYP,CARRIER_ID"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL"          FROM $UDB_LOAD_TABLE_NAME"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL"          GROUP BY EXTNL_CLAIM_ID,EXTNL_CLAIM_SEQ_NB,CLAIM_TYP,CARRIER_ID"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL"              HAVING COUNT(*) > 1)"
RXMAX_DUP_CLAIM_EXPORT_SQL=$RXMAX_DUP_CLAIM_EXPORT_SQL" ORDER BY 1,2,3,4"

INPUT_FILE="$GDX_PATH/input/GDX_GD_0060J_rxmax_inv_claims.dat"
TRIGGER_FILE="$GDX_PATH/input/GDX_GD_0060J_rxmax_inv_claims.trg"

ITD_EMAIL_INFO=$OUTPUT_PATH/$SCRIPTNAME"_email_itd_info.txt"
MAILFILE=$OUTPUT_PATH/"$SCRIPTNAME_email.txt"
EMAIL_SUBJECT="APC-Invoiced RxMax claims loaded to $(echo $REGION|dd conv=ucase 2>/dev/null) $UDB_LOAD_TABLE_NAME"
DUP_CLAIMS_FOUND_MSG=$OUTPUT_PATH/$SCRIPTNAME"_dup_check_msg.txt"

#cleanup from previous run
rm -f $MAILFILE
rm -f $LOG_FILE
rm -f $UDB_LOAD_MSG_FILE
rm -f $UDB_EXPORT_MSG_FILE
rm -f $UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS
rm -f $UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS
rm -f $DUP_CLAIMS_FOUND_MSG
rm -f $INPUT_FILE".old"
rm -f $TRIGGER_FILE".old"

#-------------------------------------------------------------------------#
# After having issues with file permissions post FTP of data, now we will
#   move the file around to gain ownership, then chmod the file for 
#   loading.
#-------------------------------------------------------------------------#
mv $INPUT_FILE $INPUT_FILE".old"
cp $INPUT_FILE".old" $INPUT_FILE
rm -f $INPUT_FILE".old"
chmod 777 $INPUT_FILE

mv $TRIGGER_FILE $TRIGGER_FILE".old"
cp $TRIGGER_FILE".old" $TRIGGER_FILE
rm -f $TRIGGER_FILE".old"
chmod 777 $TRIGGER_FILE


#-------------------------------------------------------------------------#
# Starting the script and log the starting time. 
#-------------------------------------------------------------------------#

print "Starting the script $SCRIPTNAME ......"                                 >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

#-------------------------------------------------------------------------#
# Compare records in the .dat file to the count in the trailer. 
#-------------------------------------------------------------------------#

FILE_CNT=`wc -l $INPUT_FILE|cut -b -8`
TRAILER_CNT=`cut -b 85-101 $TRIGGER_FILE`

print "File Cnt is  "$FILE_CNT                                                 >> $LOG_FILE
print "Trailer Cnt is  "$TRAILER_CNT                                           >> $LOG_FILE

if [[ $FILE_CNT -ne $TRAILER_CNT  ]]; then
   print "ERROR: record count does not match the trailer count......"           >>$LOG_FILE
   exit_error 999
fi


#-------------------------------------------------------------------------#
# Step 2. Connect to UDB using the loader Id.
#-------------------------------------------------------------------------#

   print "Connecting to GDX database......"                                    >>$LOG_FILE
   db2 -p "connect to $DATABASE user $LOAD_CONNECT_ID using $LOAD_CONNECT_PWD" >>$LOG_FILE
   RETCODE=$?
   print "RETCODE=<"$RETCODE">"                                                >> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: could not connect to database......"                        >>$LOG_FILE
      exit_error $RETCODE
   fi


#-------------------------------------------------------------------------#
# Step 3. load data from input files, overlay the current tables 
#-------------------------------------------------------------------------#
   
UDB_SQL_STRING="load from $INPUT_FILE of del"
UDB_SQL_STRING=$UDB_SQL_STRING" modified by coldel|"
UDB_SQL_STRING=$UDB_SQL_STRING" method P(4,5,6,7,8,9,3,10,11,12,13,14) "
UDB_SQL_STRING=$UDB_SQL_STRING" savecount 3000 messages $UDB_LOAD_MSG_FILE"
UDB_SQL_STRING=$UDB_SQL_STRING" replace into $UDB_LOAD_TABLE_NAME"
UDB_SQL_STRING=$UDB_SQL_STRING" (EXTNL_CLAIM_ID, EXTNL_CLAIM_SEQ_NB, CLAIM_TYP, CARRIER_ID,NDC_ID,"
UDB_SQL_STRING=$UDB_SQL_STRING"  MANFCTR_ENTITY_ID,QUARTER_ID, FLAT_DISCNT_AMT,PP_DISCNT_AMT,PERF_RQSTD_DISCNT_AMT,"
UDB_SQL_STRING=$UDB_SQL_STRING"  BONUS_RQSTD_DISCNT_AMT, ADMIN_FEE_AMT) "
UDB_SQL_STRING=$UDB_SQL_STRING" nonrecoverable data buffer 1000 sort buffer 1000 cpu_parallelism 1 "

   echo "$UDB_SQL_STRING"                                                      >>$LOG_FILE
   UDB_SQL_STRING=$(echo "$UDB_SQL_STRING" | tr "\n" " ")
   db2 -pxw "$UDB_SQL_STRING"                                                  >>$LOG_FILE
   RETCODE=$?
   
print "load RETCODE=<"$RETCODE">"                       >> $LOG_FILE
 
if [[ $RETCODE != 0 ]]; then
    print "ERROR: Step 3 abend, having problem loading file......"             >> $LOG_FILE
    exit_error 999
else
    print "********************************************"                       >> $LOG_FILE
    print "Step 3 - load of table $UDB_LOAD_TABLE_NAME - Completed ..."        >> $LOG_FILE
    print "********************************************"                       >> $LOG_FILE
fi

#-------------------------------------------------------------------------#
# Step 4.  Check for duplicate claims in TAPC_CLAIMS_RXMAX.                  
#            We want to check for duplicates, and if present include the
#            information in the notification email.
#-------------------------------------------------------------------------#
print " "                                                                      >> $LOG_FILE

UDB_SQL_STRING=$RXMAX_DUP_CLAIM_EXPORT_SQL

print $UDB_SQL_STRING                                                          >>$LOG_FILE
db2 -stvx $UDB_SQL_STRING                                                      >>$LOG_FILE

RETCODE=$?
   
print " "                                                                      >> $LOG_FILE
print "Export RETCODE=<"$RETCODE">"                                            >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
 
if [[ $RETCODE != 0 ]]; then
    print "ERROR: Step 4 abend, having problem checking and exporting dups."   >> $LOG_FILE
    exit_error $RETCODE
else
    print "********************************************"                       >> $LOG_FILE
    print "Step 4 - Export of dups in $UDB_LOAD_TABLE_NAME - Completed ..."    >> $LOG_FILE
    print "********************************************"                       >> $LOG_FILE
fi

print " "                                                                      >> $LOG_FILE

wc -l $UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS | read DUP_CLAIM_COUNT JUNK

RETCODE=$?

print " "                                                                      >> $LOG_FILE

if [[ $RETCODE != 0 ]]; then
    print "ERROR: Step 4 abend, having problem counting the rows in the "      >> $LOG_FILE
    print "$UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS file."                            >> $LOG_FILE
    exit_error $RETCODE
else
    if [[ $DUP_CLAIM_COUNT -gt 0 ]]; then 
        EMAIL_SUBJECT=$EMAIL_SUBJECT" - WARNING - DUPLICATE CLAIMS FOUND"
        print "\n\nWARNING: There were duplicate PHC claims identified after " >> $DUP_CLAIMS_FOUND_MSG
        print "the load to the $UDB_LOAD_TABLE_NAME completed.  Attached "     >> $DUP_CLAIMS_FOUND_MSG
        print "are the first 100 rows of duplicates found.  "                  >> $DUP_CLAIMS_FOUND_MSG
        print "To identify duplicate claims we looked at more than one row "   >> $DUP_CLAIMS_FOUND_MSG
        print "with the same EXTNL_CLAIM_ID, EXTNL_CLAIM_SEQ_NB, CLAIM_TYP, "  >> $DUP_CLAIMS_FOUND_MSG
        print "CARRIER_ID.  \n\nBecause our APC process does not allow for "   >> $DUP_CLAIMS_FOUND_MSG
        print "duplicate claims, these claims must be evaluated by the RxMax " >> $DUP_CLAIMS_FOUND_MSG
        print "business, and removed by the GDX IT Oncall."                    >> $DUP_CLAIMS_FOUND_MSG
        print "\nThe records in the email are pipe delimited.  You can copy "  >> $DUP_CLAIMS_FOUND_MSG
        print "and paste the records into a text file, and load them into "    >> $DUP_CLAIMS_FOUND_MSG
        print "Excel.  Headers are included in the first record.  "            >> $DUP_CLAIMS_FOUND_MSG

        print "\n\n\n\nITD info:\n\tJob: $JOB\n\tSchedule: $SCHEDULE"          >> $ITD_EMAIL_INFO
        print "\tScript: $SCRIPT_PATH/$SCRIPTNAME"                             >> $ITD_EMAIL_INFO
        print "\tSystem: $(echo $GDX_ENV_SETTING|dd conv=ucase 2>/dev/null)"   >> $ITD_EMAIL_INFO
        print "\tLog file: $LOG_FILE_ARCH"                                     >> $ITD_EMAIL_INFO

        DUPS_FOUND_FLAG="Y"
        UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS="EXTNL_CLAIM_ID|EXTNL_CLAIM_SEQ_NB|CLAIM_TYP|CARRIER_ID|NDC_ID|MANFCTR_ENTITY_ID|"
        UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS=$UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS"QUARTER_ID|FLAT_DISCNT_AMT|PP_DISCNT_AMT|"
        UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS=$UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS"PERF_RQSTD_DISCNT_AMT|BONUS_RQSTD_DISCNT_AMT|"
        UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS=$UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS"ADMIN_FEE_AMT"
    else
        print "\n\nWe checked for duplicate RxMax claims, and found none. "    >> $DUP_CLAIMS_FOUND_MSG
        # empty out the following two files used in the duplicate identified email
        print " "                                                              >> $UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS
        print " "                                                              >> $UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS
    fi
    cat $DUP_CLAIMS_FOUND_MSG                                                  >> $LOG_FILE
fi

print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Step 5.  send notification of load.                  
#-------------------------------------------------------------------------#

print "\nLoad of Invoiced RxMax Claims has just completed."                    >> $MAILFILE
print "The $UDB_LOAD_TABLE_NAME table has been loaded."                        >> $MAILFILE
cat $DUP_CLAIMS_FOUND_MSG                                                      >> $MAILFILE
print "\n\nFollowing are the load details:"                                    >> $MAILFILE
print "\n\n---------------------------------------------------"                >> $MAILFILE
print "\n\nSource Data File is : " $INPUT_FILE                                 >> $MAILFILE
print "\nFile Cnt is  "          $FILE_CNT                                     >> $MAILFILE
print "\n\n---------------------------------------------------\n\n\n"          >> $MAILFILE
print $UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS_COLHDRS                                >> $MAILFILE
head -100 $UDB_EXPORT_TRXMAX_INV_CLAIM_DUPS                                    >> $MAILFILE
cat $ITD_EMAIL_INFO                                                            >> $MAILFILE
print "\n\n------END OF EMAIL BODY----------------------------------"          >> $MAILFILE

chmod 777 $MAILFILE

mailx -r $EMAIL_FROM_ADDY -s "$EMAIL_SUBJECT" $EMAIL_TO_ADDY < $MAILFILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print " "                                                                  >> $LOG_FILE
    print "================== J O B  A B E N D E D ======="                    >> $LOG_FILE
    print "  Error sending email to Business "                                 >> $LOG_FILE
    print "  Look in " $LOG_FILE                                               >> $LOG_FILE
    print "==============================================="                    >> $LOG_FILE
            exit_error 999
else
    print "********************************************"                       >> $LOG_FILE
    print "Step 5 - Email sucessfully sent to : " $EMAIL_TO_ADDY               >> $LOG_FILE
    print "********************************************"                       >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
fi   

#-------------------------------------------------------------------------#
# Step 6 - check DUPS_FOUND_FLAG and abend if = "Y"
#-------------------------------------------------------------------------#

if [[ $DUPS_FOUND_FLAG == "Y" ]]; then
    print " "                                                                  >> $LOG_FILE
    print "Because of the duplicate claims, the job will abend here."          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "================== J O B  A B E N D E D ======="                    >> $LOG_FILE
    print "  Dups were found, abend. "                                         >> $LOG_FILE
    print "  Look in " $LOG_FILE                                               >> $LOG_FILE
    print "==============================================="                    >> $LOG_FILE
    exit_error 111
fi

print "********************************************"                           >> $LOG_FILE
print "Step 6 - DUPS_FOUND_FLAG checked and value = $DUP_FOUND_FLAG"           >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

#-------------------------------------------------------------------------#
# Step 7.  Clean up if successful                  
#-------------------------------------------------------------------------#

# cleanup files
mv $INPUT_FILE $INPUT_FILE".old"
mv $TRIGGER_FILE $TRIGGER_FILE".old"
rm -f $DUP_CLAIMS_FOUND_MSG
rm -f $UDB_LOAD_MSG_FILE
rm -f $MAILFILE
rm -f $UDB_EXPORT_MSG_FILE
rm -f $LOG_PATH/"*$JOB*.load.*"

print "********************************************"                           >> $LOG_FILE
print "Step 7 - Clean up - Completed ......"                                   >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

# move log file to archive with timestamp
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH

exit $RETCODE
