#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script        : GDX_GD_1010J_NPI_Xref_load.ksh    
# Title         : Load NPI Xref file from Pharmacy Network
#                 
#
# Description   : This script waits for a fixed length ASCII file from 
#                 Pharmacy Network.  
#                 The file will be loaded into Rebate GDX table: 
#                         VRAP.TPHARM_NPI_XREF 
#                 and ORACLE table 
#                         RBATE_REG.TPHARM_NPI_XREF
#                 One copy of the input data files are backuped under
#                         $GDXROOT$/input/archive/npixref.
#                 The load is a full replace for both tables.
#
#
# Parameters    : N/A 
# 
# Output        : Log file as $LOG_FILE
#
# Input Files   : /GDX/prod/input/GDX_tpharm_npi_xref.dat
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 07-06-10   qcpi733     Removed step 4 which populated a SILVER CR table
# 08-10-06   qcpi03o     Initial Creation
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

   . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH
    exit $RETCODE
}
#-------------------------------------------------------------------------#
function reload_NPI {

   sql="import from $EXPORT_FILE of DEL
           commitcount 3000 messages "$DB2_MSG_FILE"
           replace into VRAP.TPHARM_NPI_XREF"
   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
print 'reload table tpharm_npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

   print "----------------------------------------------------------------"    >>$LOG_FILE

if [[ $RETCODE != 0 ]]; then
        print "ERROR: having problem to recover table from export file ......"  >> $LOG_FILE
        return 1
else
        print "Having problem with import. Reloaded table with backup......"  >> $LOG_FILE
        return 0
fi

}
#-------------------------------------------------------------------------#


# Region specific variables
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS=""
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="helen.tang@caremark.com"
fi


# Variables
RETCODE=0
SCHEDULE=
JOB=""
FILE_BASE=""
SCRIPTNAME=$(basename "$0")

# LOG FILES
LOG_FILE_ARCH=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE_NM=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_NM

DB2_MSG_FILE=$LOG_FILE.load

INPUT_FILE=$GDX_PATH/input/GDX_tpharm_npi_xref.dat
TRIGGER_FILE=$GDX_PATH/input/GDX_tpharm_npi_xref.trg
LOAD_FILE=$GDX_PATH/input/GDX_npi_xref_load.dat

EXPORT_FILE=$GDX_PATH/input/GDX_unload_npi_xref.bkp


#-------------------------------------------------------------------------#
# Starting the script and log the starting time. 
#-------------------------------------------------------------------------#
print "Starting the script $SCRIPTNAME ......"                                 >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

#-------------------------------------------------------------------------#
# Step 1. Split the file into header, detail and trailer files. 
#         Confirm the file record count matches the number in the trailer.
#-------------------------------------------------------------------------#

if [[ ! -f $INPUT_FILE  ]]; then
   print "ERROR: NPI XRef file not received......"                             >>$LOG_FILE
   exit_error 999
fi

TRAILER_REC=`tail -1 $INPUT_FILE`
grep -v ^HDR $INPUT_FILE > $INPUT_FILE.tmp
grep -v ^TRL $INPUT_FILE.tmp > $LOAD_FILE
rm -f $INPUT_FILE.tmp
FILE_COUNT=`wc -l $LOAD_FILE|cut -b -8`
TRAILER_COUNT=`echo $TRAILER_REC|cut -b 4-`

FILE_COUNT1=`expr $FILE_COUNT + 2`

if [[ $FILE_COUNT1 -ne $TRAILER_COUNT  ]]; then
   print "ERROR: record count doesn't match the trailer count......"           >>$LOG_FILE
   exit_error 999
fi

print "********************************************"                           >> $LOG_FILE
print "Step 1 - Verify input record count -Completed......"                    >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
#-------------------------------------------------------------------------#
# Step 2. Connect to UDB.
#         backup table vrap.tpharm_npi_xref.
#-------------------------------------------------------------------------#

   print "Connecting to GDX database......"                                    >>$LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >>$LOG_FILE
   RETCODE=$?
print 'RETCODE=<'$RETCODE'>'>> $LOG_FILE

if [[ $RETCODE != 0 ]]; then
   print "ERROR: couldn't connect to database......"                           >>$LOG_FILE
   exit_error $RETCODE
fi

   print "Connected to database, will start backup table vrap.tpharm_npi_xref 
           under $GDX_PATH/input directory"             >>$LOG_FILE
#-------------------------------------------------------------------------#
# Backup tables, export data into flat files.
#-------------------------------------------------------------------------#

   sql="export to $EXPORT_FILE of DEL select * from vrap.tpharm_npi_xref"
   echo "$sql"                                                                 >>$LOG_FILE
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print "----------------------------------------------------------------"    >>$LOG_FILE

if [[ $RETCODE != 0 ]]; then
    print "ERROR: Step 2 abend, having problem backup the table......"     >> $LOG_FILE
    exit_error 999
else
print "********************************************"                           >> $LOG_FILE
print "Step 2 -Backup TPHARM_NPI_XREF table - Completed ......"                >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
fi

#-------------------------------------------------------------------------#
# Step 3. Import data from input files, overlay the current tables 
#-------------------------------------------------------------------------#

   sql="import from $LOAD_FILE of asc
        modified by usedefaults
       method L (5 13, 14 20, 21 27, 28 37, 38 38, 39 40, 41 50, 51 60, 
        61 70, 71 80, 81 81, 82 82, 83 108, 109 116) 
        commitcount 3000 messages "$DB2_MSG_FILE"
           replace into vrap.tpharm_npi_xref
        (PMCY_GID, PMCY_BE_ID, PMCY_NCPDP_ID, PMCY_NPI_ID,
        PMCY_NCPDP_GEN_CD, PMCY_ST_ABBR_CD, PMCY_EFF_DT,
        PMCY_POST_EFF_DT, PMCY_TERM_DT, PMCY_POST_TERM_DT, 
        ROW_MOD_CD, ROW_ACTV_CD, UPDT_TS, UPDT_USER_ID)"


   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
print 'import npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

#-------------------------------------------------------------------------#
# run update, set space field to NULL 
#-------------------------------------------------------------------------#
   updtSql="update vrap.tpharm_npi_xref set pmcy_npi_id = null where PMCY_NPI_ID = ' '"
   echo "$updtSql"                                                                 >>$LOG_FILE
   db2 -px "$updtSql"                                                              >>$LOG_FILE

if [[ $RETCODE != 0 ]]; then
    print "ERROR: Step 3 abend, having problem import file......"          >> $LOG_FILE
    reload_NPI
    RETCODE=$?
    if [[ $RETCODE != 0 ]]; then
       print "ERROR: Step 3 - both import and reload to table rm_npi_xref failed......" >>$LOG_FILE
       exit_error 999
    fi
    print "Recovered table vrap.tpharm_npi_xref from export file......"    >> $LOG_FILE
# remove the exported file
    rm -f $EXPORT_FILE
    exit_error 999
else
print "********************************************"                           >> $LOG_FILE
print "Step 3 - Import data to table tpharm_npi_xref - Completed ......"       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
fi


    RETCODE=0
# remove the exported file
    rm -f $EXPORT_FILE
# remove the load file 
    rm -f $LOAD_FILE
# remove DB2 message
    rm -f $DB2_MSG_FILE
# backup the input data file to $GDXROOT/input/archive/npixref
    mv -f $INPUT_FILE $GDX_PATH/input/archive/npixref
    rm -f $TRIGGER_FILE 
# clean some old log file?
    `find "$LOG_ARCH_PATH" -name "GDX_NPI_XRef_load*" -mtime +35 -exec rm -f {} \;  `

print "********************************************"                           >> $LOG_FILE
print "Step 5 - Clean up - Completed ......"                                   >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

# move log file to archive with timestamp
        mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH

exit $RETCODE
