#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDMN0100_monthly_npi_xref_file_extract_to_gtradefin.ksh   
# Title         : NPI Xref data extract to gTradeFin
#
# Description   : This script will pull all non-internal NPI rows from the
#                 VRAP.TPHARM_NPI_XREF table, and deliver it to the 
#                 users gTradeFin LAN drive.
#
# Abends        : 
#                 
# Maestro Job   : GD_
#
# Parameters    : N/A 
#
# Output        : 
#
# Input Files   : Database
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 10-27-06   qcpi733     initial script
#-------------------------------------------------------------------------#
 
#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_script {
    RETCODE=$1
    EMAILPARM4='  '
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
    
    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE
}

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

#-------------------------------------------------------------------------#
# Call the Common used script functions to make functions available
#-------------------------------------------------------------------------#

. $SCRIPT_PATH/Common_GDX_Script_Functions.ksh

# Region specific variables
if [[ $REGION = "prod" ]]; then
    if [[ $QA_REGION = "true" ]]; then
        ALTER_EMAIL_ADDRESS=""
        NPI_XREF_LAN_DIR="/rebates_integration/npi_xref/test"
        UDB_SCHEMA_OWNER="VRAP"
    else
        ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
        NPI_XREF_LAN_DIR="/rebates_integration/npi_xref"
        UDB_SCHEMA_OWNER="VRAP"
    fi
else
    ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
    NPI_XREF_LAN_DIR="/rebates_integration/npi_xref/test"
    UDB_SCHEMA_OWNER="VRAP"
fi

# Variables
RETCODE=0
SCHEDULE="GDMN0100"
JOBNAME=""
SCRIPTNAME=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log"
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"
FTP_CMDS=$OUTPUT_PATH/$FILE_BASE"_ftpcmds.txt"
UDB_CONNECT_STRING="db2 -p connect to "$DATABASE" user "$CONNECT_ID" using "$CONNECT_PWD
UDB_SQL_STRING=""
UDB_SQL_FILE=$SQL_PATH/$FILE_BASE"_udb_sql.sql"
UDB_OUTPUT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_udb_msg.dat"
TPHARM_NPI_XREF_DAT=$OUTPUT_PATH/$FILE_BASE".dat"
TPHARM_NPI_XREF_TRG=$OUTPUT_PATH/$FILE_BASE".trg"
FTP_TPHARM_NPI_XREF_DAT="TPHARM_NPI_XREF_data_extract_"
FTP_TPHARM_NPI_XREF_TRG="TPHARM_NPI_XREF_data_extract_"
TPHARM_NPI_XREF_CNT_DAT=$OUTPUT_PATH/"$FILE_BASE"_udb_cnt.dat
TPHARM_NPI_XREF_CNT=""
LAST_PROCESSED_MONTH_YYYYMM=$OUTPUT_PATH/$FILE_BASE"_proc_month.dat"

export FTP_HOST="AZSHISP00"

# SQL Constants

rm -f $LOG_FILE
rm -f $TPHARM_NPI_XREF_DAT
rm -f $TPHARM_NPI_XREF_TRG
rm -f $UDB_OUTPUT_MSG_FILE
rm -f $UDB_SQL_FILE
rm -f $FTP_CMDS
rm -f $TPHARM_NPI_XREF_CNT_DAT
rm -f $LAST_PROCESSED_MONTH_YYYYMM
 
function run_ftp {
    typeset _FTP_COMMANDS=$(cat) # pulls stdin into a variable
    typeset _FTP_OUTPUT=""
    typeset _ERROR_COUNT=""
    
    print "Transferring to $FTP_HOST using commands:"                          >> $LOG_FILE
    print "$_FTP_COMMANDS"                                                     >> $LOG_FILE
    print ""                                                                   >> $LOG_FILE
    _FTP_OUTPUT=$(print "$_FTP_COMMANDS" | ftp -i -v $FTP_HOST)
    RETCODE=$?  
    
    print "$_FTP_OUTPUT"                                                       >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        print "Errors occurred during ftp."                                    >> $LOG_FILE
        exit_script $RETCODE
    fi
    
    # Parse the ftp output for errors
    # 400 and 500 level replies are errors
    # You have to vilter out the bytes sent message
    # it may say something 404 bytes sent and you don't
    # want to mistake this for an error message. 
    _ERROR_COUNT=$(echo "$_FTP_OUTPUT" | egrep -v 'bytes (sent|received)' | egrep -c '^\s*[45][0-9][0-9]')
    if [[ $_ERROR_COUNT -gt 0 ]]; then
        print "Errors occurred during ftp."                                    >> $LOG_FILE
        RETCODE=5
        exit_script $RETCODE
    fi
}

#-------------------------------------------------------------------------#
# First step is to back up the extract the data to a comma delimited file.
#-------------------------------------------------------------------------#

print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the UDB EXPORT from VRAP.TPHARM_NPI_XREF"                      >> $LOG_FILE

#cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

print "export to $TPHARM_NPI_XREF_DAT of del modified by coldel, SELECT PMCY_NCPDP_ID, PMCY_NPI_ID FROM $UDB_SCHEMA_OWNER.TPHARM_NPI_XREF WHERE UPPER(PMCY_NCPDP_GEN_CD) != 'Y';" >> $UDB_SQL_FILE

#99EOFSQLTEXT99
 
print " "                                                                      >> $LOG_FILE
cat $UDB_SQL_FILE                                                              >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

$UDB_CONNECT_STRING                                                            >> $LOG_FILE
db2 -stvxf $UDB_SQL_FILE                                                       >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

RETCODE=$?

print " "                                                                      >> $LOG_FILE
if [[ $RETCODE != 0 ]]; then 
    print "Error exporting data from TPHARM_NPI_XREF. "                        >> $LOG_FILE
    print " Return Code = "$RETCODE                                            >> $LOG_FILE
    print "Check Import error log: "$UDB_OUTPUT_MSG_FILE                       >> $LOG_FILE
    print "Here are last 20 lines of that file - "                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    tail -20 $UDB_OUTPUT_MSG_FILE                                              >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Data output file is: "$TPHARM_NPI_XREF_DAT                          >> $LOG_FILE
    exit_script $RETCODE
else
    print "Return Code from UDB Export = "$RETCODE                             >> $LOG_FILE
    print "Successful extract - continue with script."                         >> $LOG_FILE
    EXISTING_DATA_EXP_FLAG='Y'
fi

print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Next step is to get the counts for what should have been extracted.
#   Also get the ESTIMATED month this run is for.  This is an estimate based
#   on the design that this job will run monthly, and even if rerun, the last
#   processing month is still 2 weeks prior to todays date.
#-------------------------------------------------------------------------#

print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the COUNT on TPHARM_NPI_XREF"                                  >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

UDB_SQL_STRING="select count(*) from $UDB_SCHEMA_OWNER.TPHARM_NPI_XREF WHERE UPPER(PMCY_NCPDP_GEN_CD) != 'Y'"
                 
print $UDB_SQL_STRING                                                          >> $LOG_FILE 

db2 -px $UDB_SQL_STRING  > $TPHARM_NPI_XREF_CNT_DAT 2> $UDB_OUTPUT_MSG_FILE

RETCODE=$?

cat $UDB_OUTPUT_MSG_FILE                                                           >> $LOG_FILE

print " "                                                                      >> $LOG_FILE

if [[ $RETCODE != 0 ]]; then 
    print "Error getting count from TPHARM_NPI_XREF. "                         >> $LOG_FILE
    print " Return Code = "$RETCODE                                            >> $LOG_FILE
    print "Check Import error log: "$UDB_OUTPUT_MSG_FILE                       >> $LOG_FILE
    print "Here are last 20 lines of that file - "                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    tail -20 $UDB_OUTPUT_MSG_FILE                                              >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Data output file is: "$TPHARM_NPI_XREF_CNT_DAT                      >> $LOG_FILE
    exit_script $RETCODE
else
    read TPHARM_CNT < $TPHARM_NPI_XREF_CNT_DAT
    export TPHARM_NPI_XREF_CNT=$TPHARM_CNT
    print "Record count = "$TPHARM_NPI_XREF_CNT                                >> $LOG_FILE
fi

print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the SELECT for the last PROCESSING MONTH"                      >> $LOG_FILE
print "  Get last processing month value in YYYYMM format"                     >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

UDB_SQL_STRING="select cast( cast((year( current date  - 1 month)) as char(4)) || cast( substr(digits(month(current date - 1 month)), 9) as char(2)) as char(6)) from sysibm.sysdummy1"

print $UDB_SQL_STRING                                                          >> $LOG_FILE 

db2 -px $UDB_SQL_STRING  > $LAST_PROCESSED_MONTH_YYYYMM 2> $UDB_OUTPUT_MSG_FILE

RETCODE=$?

cat $UDB_OUTPUT_MSG_FILE                                                       >> $LOG_FILE

print " "                                                                      >> $LOG_FILE

if [[ $RETCODE != 0 ]]; then 
    print "Error getting processed YYYYMM. "                                   >> $LOG_FILE
    print " Return Code = "$RETCODE                                            >> $LOG_FILE
    print "Check Import error log: "$UDB_OUTPUT_MSG_FILE                       >> $LOG_FILE
    print "Here are last 20 lines of that file - "                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    tail -20 $UDB_OUTPUT_MSG_FILE                                              >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Data output file is: "$LAST_PROCESSED_MONTH_YYYYMM                  >> $LOG_FILE
    exit_script $RETCODE
else
    read PROCESSED_YYYYMM < $LAST_PROCESSED_MONTH_YYYYMM
    export LAST_PROCESSED_MONTH_YYYYMM=$PROCESSED_YYYYMM
    print "Last processed month YYYYMM = "$LAST_PROCESSED_MONTH_YYYYMM         >> $LOG_FILE
    FTP_TPHARM_NPI_XREF_DAT=$FTP_TPHARM_NPI_XREF_DAT$LAST_PROCESSED_MONTH_YYYYMM".txt"
    FTP_TPHARM_NPI_XREF_TRG=$FTP_TPHARM_NPI_XREF_TRG$LAST_PROCESSED_MONTH_YYYYMM".txt"
fi

print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Next step is to get the line count from the extract.
#-------------------------------------------------------------------------#

print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the LINE COUNT on $TPHARM_NPI_XREF_DAT"                        >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

export DATA_FILE_LINE_COUNT=`wc -l $TPHARM_NPI_XREF_DAT | cut -f3 -d ' '`

print "Line count is = $DATA_FILE_LINE_COUNT"                                  >> $LOG_FILE 

print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Next step is to compare the LINE COUNT of the record to the to SELECT COUNT.
#-------------------------------------------------------------------------#

print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the COMPARE"                                                   >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

print " Line Count   = "$DATA_FILE_LINE_COUNT                                  >> $LOG_FILE
print " SELECT Count = "$TPHARM_NPI_XREF_CNT                                   >> $LOG_FILE

print " "                                                                      >> $LOG_FILE


if [[ $DATA_FILE_LINE_COUNT != $TPHARM_NPI_XREF_CNT ]]; then

    RETCODE=9
    print "Error when comparing SELECT COUNT to LINE COUNT. "                  >> $LOG_FILE
    print " COUNTS DO NOT MATCH"                                               >> $LOG_FILE
    print " COUNTS DO NOT MATCH"                                               >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " Return Code = "$RETCODE                                            >> $LOG_FILE
    exit_script $RETCODE
else

    print "Counts Match, proceed to FTP step."                                 >> $LOG_FILE
    print "Number of records in ${TPHARM_NPI_XREF_DAT##/*/} is $DATA_FILE_LINE_COUNT " >> $TPHARM_NPI_XREF_TRG
fi

print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Next step is to FTP the data and trigger file to AZSHAPP00\gTradeFin.
#-------------------------------------------------------------------------#

print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the FTP."                                                      >> $LOG_FILE

## Build trigger file name with counts

{
    print "cd $NPI_XREF_LAN_DIR"
    print "put $TPHARM_NPI_XREF_DAT $FTP_TPHARM_NPI_XREF_DAT (replace"
    print "dir $FTP_TPHARM_NPI_XREF_DAT"
    print "put $TPHARM_NPI_XREF_TRG $FTP_TPHARM_NPI_XREF_TRG (replace"
    print "dir $FTP_TPHARM_NPI_XREF_TRG"
    print "bye"
} | run_ftp "$FTP_HOST"

#-------------------------------------------------------------------------#
# Script completed
#-------------------------------------------------------------------------#
{
    date +"%D %r %Z"
    print
    print
    print "....Completed executing $SCRIPTNAME ...."
} >> $LOG_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
exit $RETCODE

