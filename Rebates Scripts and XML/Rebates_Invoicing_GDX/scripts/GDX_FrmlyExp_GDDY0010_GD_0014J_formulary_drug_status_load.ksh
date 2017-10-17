#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_FrmlyExp_GDDY0010_GD_0014J_tformulary_drug_status_load.ksh   
# Title         : Load for the TFORMULARY_DRUG_STATUS table.
#
# Description   : This script will pull the GPO Formulary ON/OFF data 
#                 that is built during the GPO Formulary Expansion 
#                 process, and load it to the VRAP.TFORMULARY_DRUG_STATUS
#                 table for use in market share.
#
# Abends        : Prior to performing the UDB IMPORT REPLACE, the script
#                 will EXPORT the data from the TFORMULARY_DRUG_STATUS. 
#                 If there are any issues during the script, AFTER the data
#                 has been deleted from TFORMULARY_DRUG_STATUS, the script 
#                 will automatically IMPORT the EXPORTed data.
#                 
# Maestro Job   : GDDY0010 GD_0014J
#
# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-22-05   qcpi733     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
#-------------------------------------------------------------------------#
# Call the Common used script functions to make functions available
#-------------------------------------------------------------------------#
. $SCRIPT_PATH/Common_GDX_Script_Functions.ksh
 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS=""
        UDB_TO_SCHEMA_OWNER="VRAP"
        ORA_SCHEMA_OWNER="DMA_RBATE2"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        UDB_TO_SCHEMA_OWNER="VRAP"
        ORA_SCHEMA_OWNER="DMA_RBATE2"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
    UDB_TO_SCHEMA_OWNER="VRAP"
    ORA_SCHEMA_OWNER="DMA_RBATE2"
fi

RETCODE=0
BKUP_RETCODE=0
SCHEDULE="GDDY0010"
JOB="GD_0014J"
FILE_BASE="GDX_FrmlyExp_"$SCHEDULE"_"$JOB"_tformulary_drug_status_load"
SCRIPTNAME=$FILE_BASE".ksh"
# LOG FILES
LOG_FILE_ARCH=$FILE_BASE".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_ARCH
# Oracle and UDB SQL files
ORA_SQL_FILE=$SQL_PATH/$FILE_BASE"_ora.sql"
UDB_SQL_FILE=$SQL_PATH/$FILE_BASE"_udb.sql"
UDB_CONNECT_STRING="db2 -p connect to "$DATABASE" user "$CONNECT_ID" using "$CONNECT_PWD
# UDB Message files
UDB_OUTPUT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_udb_sql.msg"
UDB_IMPORT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_udb_imp.msg"
UDB_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_udb.msg"
# Input files
#   This file is the trigger for the Maestro job that runs this script. Delete upon successful run.
MAESTRO_TRG_FILE=$INPUT_PATH/"rbate_RIOR4520_RI_4525J.trg"
# Output files
SQL_PIPE_FILE=$OUTPUT_PATH/$FILE_BASE"_pipe.lst"
GPO_FORMULARY_DRUG_STATUS_DATA=$OUTPUT_PATH/$FILE_BASE"_gpo_formulary_drug_status.dat"
GPO_FORMULARY_DRUG_STATUS_CNTS=$OUTPUT_PATH/$FILE_BASE"_gpo_formulary_drug_status_cnts.dat"
TFORMULARY_DRUG_BKUP_DATA=$OUTPUT_PATH/$FILE_BASE"_tformulary_cons_bkup_export.dat"
# Flags
EXISTING_DATA_DEL_FLAG='N'
EXISTING_DATA_EXP_FLAG='N'
# Misc
DB_ROWS_READ=0
DB_ROWS_SKIPPED=0
DB_ROWS_INSERTED=0
DB_ROWS_UPDATED=0
DB_ROWS_REJECTED=0
DB_ROWS_COMMITTED=0
EXTRACT_REC_CNT=0
#--- Next variable contains Oracle SQL used in two places, but clause must be identical at all times
ORA_SQL_SHARED_CLAUSE="    FROM DWCORP.mv_frmly mf ,$ORA_SCHEMA_OWNER.v_drug_remote vdr ,$ORA_SCHEMA_OWNER.v_frmly_drug vfd "
ORA_SQL_SHARED_CLAUSE=$ORA_SQL_SHARED_CLAUSE" WHERE vfd.frmly_gid = mf.drug_list_gid"
ORA_SQL_SHARED_CLAUSE=$ORA_SQL_SHARED_CLAUSE" AND   vfd.drug_gid  = vdr.drug_gid"
ORA_SQL_SHARED_CLAUSE=$ORA_SQL_SHARED_CLAUSE" AND   UPPER(vfd.frmly_flag) = LOWER(vfd.frmly_flag)"
#above WHERE UPPER/LOWER check is to prevent alpha chars from being in result set.
 
rm -f $LOG_FILE
rm -f $ORA_SQL_FILE
rm -f $UDB_SQL_FILE
rm -f $UDB_MSG_FILE
rm -f $UDB_OUTPUT_MSG_FILE
rm -f $UDB_IMPORT_MSG_FILE
rm -f $SQL_PIPE_FILE
rm -f $GPO_FORMULARY_DRUG_STATUS_CNTS
rm -f $GPO_FORMULARY_DRUG_STATUS_DATA

#-------------------------------------------------------------------------#
# Starting the script to load the TFORMULARY_DRUG_STATUS table
#-------------------------------------------------------------------------#
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the script to load the TFORMULARY_DRUG_STATUS table"           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# First step is to back up the existing data, in case there is a problem
# during this script run.  In that case the script can restore the 
# original data for use while IT troubleshoots current problem.
#-------------------------------------------------------------------------#

print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the UDB EXPORT from VRAP.TFORMULARY_DRUG_STATUS"               >> $LOG_FILE
# Export data to a pipe delimited file.  This file can be used to send to users if requested.

cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

export to $TFORMULARY_DRUG_BKUP_DATA of del modified by coldel| SELECT * FROM $UDB_TO_SCHEMA_OWNER.TFORMULARY_DRUG_STATUS;

99EOFSQLTEXT99
 
print " "                                                                      >> $LOG_FILE
cat $UDB_SQL_FILE                                                              >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

$UDB_CONNECT_STRING                                                            >> $LOG_FILE
db2 -stvxf $UDB_SQL_FILE                                                       >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

RETCODE=$?

print " "                                                                      >> $LOG_FILE
if [[ $RETCODE != 0 ]]; then 
    print "Error exporting data from TFORMULARY_DRUG_STATUS. "                 >> $LOG_FILE
    print " Return Code = "$RETCODE                                            >> $LOG_FILE
    print "Check Import error log: "$UDB_OUTPUT_MSG_FILE                       >> $LOG_FILE
    print "Here are last 20 lines of that file - "                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    tail -20 $UDB_OUTPUT_MSG_FILE                                              >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Data output file is: "$TFORMULARY_DRUG_BKUP_DATA                    >> $LOG_FILE
else
    print "Return Code from UDB Export = "$RETCODE                             >> $LOG_FILE
    print "Successful backup - continue with script."                          >> $LOG_FILE
    EXISTING_DATA_EXP_FLAG='Y'
fi

print " "                                                                      >> $LOG_FILE
print "=================================================================="     >> $LOG_FILE

if [[ $RETCODE = 0 ]]; then 
    #-------------------------------------------------------------------------#
    # Formulary Drug Status Extract
    # Set up the Pipe file, then build and EXEC the new SQL.               
    # Get the record count from the input for validation of rows
    #-------------------------------------------------------------------------#
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Begin building Oracle SQL file for GPO Formulary Drug Status "      >> $LOG_FILE
    print "  Extract"                                                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    #-------------------------------------------------------------------------#
    # Oracle userid/password
    #-------------------------------------------------------------------------#

    ORACLE_DB_USER_PASSWORD=`cat $SCRIPT_PATH/ora_user.fil`

    #-------------------------------------------------------------------------#
    # Create Oracle SQL file
    #-------------------------------------------------------------------------#

    rm -f $SQL_PIPE_FILE
    mkfifo $SQL_PIPE_FILE
    dd if=$SQL_PIPE_FILE of=$GPO_FORMULARY_DRUG_STATUS_DATA bs=100k &

#CANNOT INDENT DOWN TO EOF LINE
cat > $ORA_SQL_FILE << EOF
set LINESIZE 800
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP off
set verify off
set trimspool on
whenever sqlerror exit 1
alter session enable parallel dml;
 
spool $SQL_PIPE_FILE;
SELECT  mf.drug_list_extnl_type formulary_source
       ,'|'
       ,mf.drug_list_nbr formulary_id
       ,'|'
       ,vdr.ndc_code NDC
       ,'|'
       ,1 nhu_type_cd
       ,'|'
       ,DECODE(TO_NUMBER(vfd.frmly_flag),1,1,0) formulary_status
       ,'|'
       ,vfd.eff_date eff_dt
       ,'|'
       ,nvl(vfd.end_date,TO_DATE('12-31-9999','mm-dd-yyyy')) end_dt
    $ORA_SQL_SHARED_CLAUSE       
    order by 2,3
;
spool off
spool $GPO_FORMULARY_DRUG_STATUS_CNTS
SELECT ltrim(rtrim(to_char(count(*)))) 
$ORA_SQL_SHARED_CLAUSE
;
quit;
EOF

    cat $ORA_SQL_FILE                                                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Finished building Oracel SQL file, start extracting data "          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    $ORACLE_HOME/sqlplus -s $ORACLE_DB_USER_PASSWORD @$ORA_SQL_FILE

    RETCODE=$?

    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Completed extract of GPO Formulary Drug Status"                     >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        print "Failure in Extract "                                            >> $LOG_FILE
        print "Oracle error is "                                               >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -50 $GPO_FORMULARY_DRUG_STATUS_DATA                               >> $LOG_FILE
        cat -q $GPO_FORMULARY_DRUG_STATUS_CNTS                                 >> $LOG_FILE
    else
        print "Successfull extract of GPO Formulary Drug Status data."         >> $LOG_FILE

        EXTRACT_REC_CNT=$(< $GPO_FORMULARY_DRUG_STATUS_CNTS)

        print "The number of rows extracted was "$EXTRACT_REC_CNT          >> $LOG_FILE
        print "Compare to number of rows loaded via IMPORT (further down)."    >> $LOG_FILE
    fi

    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
else
    print "Skipped Oracle Extract due to previous error."                      >> $LOG_FILE
fi

print "=================================================================="     >> $LOG_FILE

if [[ $RETCODE = 0 ]]; then
    #-------------------------------------------------------------------------#
    # Start the UDB DB2 IMPORT.  Import the data extracted above from the 
    #   Oracle instance.  Data contains GPO Formulary Drug Status to be added 
    #   to TFORMULARY_DRUG_STATUS.  Use REPLACE to truncate the existing data 
    #   in the TFORMULARY_DRUG_STATUS.  If script fails after this point 
    #   then the script will reload the TFORMULARY_DRUG_STATUS with
    #   its original data (prior to this script executing).
    #-------------------------------------------------------------------------#

    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Starting the UDB IMPORT into VRAP.TFORMULARY_DRUG_STATUS"           >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    # Input file columns are pipe delimited (coldel|)

#CANNOT INDENT DOWN TO 99EOFSQLTEXT99 LINE
cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

import from $GPO_FORMULARY_DRUG_STATUS_DATA of del modified by coldel| method p (1,2,3,4,5,6,7) commitcount 1000 REPLACE INTO $UDB_TO_SCHEMA_OWNER.TFORMULARY_DRUG_STATUS(FRMLY_SRC_CD,FRMLY_ID,DRUG_NDC_ID,NHU_TYP_CD,FRMLY_DRUG_STAT_CD,EFF_DT,END_DT);

99EOFSQLTEXT99

    print " "                                                                  >> $LOG_FILE
    print "cat udb sql file "                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    cat $UDB_SQL_FILE >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "end cat of udb sql file " >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    EXISTING_DATA_DEL_FLAG='Y'

    db2 -stvxf $UDB_SQL_FILE                                                   >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

    RETCODE=$?

    print " "                                                                  >> $LOG_FILE
    if [[ $RETCODE != 0 ]]; then 
        print "Error importing data into TFORMULARY_DRUG_STATUS. "             >> $LOG_FILE
        print "Return Code = "$RETCODE                                         >> $LOG_FILE
        print "Check Import error log: "$UDB_OUTPUT_MSG_FILE                   >> $LOG_FILE
        print "Here are last 30 lines of that file - "                         >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -30 $UDB_OUTPUT_MSG_FILE                                          >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Data Input file is: "$GPO_FORMULARY_DRUG_STATUS_DATA            >> $LOG_FILE
        print "Script will now reload TFORMULARY_DRUG_STATUS with "            >> $LOG_FILE 
        print "original data."                                                 >> $LOG_FILE
    else
        print "Return Code from UDB Import = "$RETCODE                         >> $LOG_FILE
        print "Successful Load - continue with script."                        >> $LOG_FILE
        
        # call the function to get the results of the import.  
        #  Function script is called from Environmental variable script.
        CME_Get_db2_Import_Results $UDB_OUTPUT_MSG_FILE

        print "     Rows Read by Import: "$DB_ROWS_READ                        >> $LOG_FILE
        print " Rows Inserted by Import: "$DB_ROWS_INSERTED                    >> $LOG_FILE
        print " Rows Rejected by Import: "$DB_ROWS_REJECTED                    >> $LOG_FILE
        print "Rows Committed by Import: "$DB_ROWS_COMMITTED                   >> $LOG_FILE

        print " "                                                              >> $LOG_FILE

        if [[ $EXTRACT_REC_CNT = $DB_ROWS_INSERTED ]]; then
            print "The number of rows extracted "\($EXTRACT_REC_CNT\)      >> $LOG_FILE
            print "  equals the number of rows inserted via the IMPORT "       >> $LOG_FILE
            print \($DB_ROWS_INSERTED\)"."                                     >> $LOG_FILE
            print "LOAD VALIDATED, script will continue"                       >> $LOG_FILE
        else
            print "The number of rows extracted "\($EXTRACT_REC_CNT\)      >> $LOG_FILE
            print "  DOES NOT MATCH the number of rows inserted via the"       >> $LOG_FILE
            print "  IMPORT "\($DB_ROWS_INSERTED\)"."                          >> $LOG_FILE
            print "LOAD MISMATCH.  Script will now abend."                     >> $LOG_FILE
            if [[ $RETCODE = 0 ]]; then
                RETCODE=1
            fi
        fi

        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
    fi
 
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

else
    print "Skipped UDB Import step due to previous errors."                    >> $LOG_FILE    
fi

print "=================================================================="     >> $LOG_FILE
 
#-------------------------------------------------------------------------#
# Check for invalid return code and need to reload original data   
#  ONLY do this if (1) the TFORMULARY_DRUG_STATUS table data was exported, and (2)
#  only if the existing data in TFORMULARY_DRUG_STATUS was truncated during the 
#  IMPORT of GPO Formulary Drug Status.
#-------------------------------------------------------------------------#
if [[ $RETCODE != 0 ]]; then
    if [[ $EXISTING_DATA_EXP_FLAG = 'Y' && $EXISTING_DATA_DEL_FLAG = 'Y' ]]; then 
        print " "                                                              >> $LOG_FILE
        print `date +"%D %r %Z"`                                               >> $LOG_FILE
        print "An error occurred after data in TFORMULARY_DRUG_STATUS was "    >> $LOG_FILE
        print "  truncated."                                                   >> $LOG_FILE
        print "A reload of the backup data is required. Starting UDB Import"   >> $LOG_FILE
        print "  using exported backup data."                                  >> $LOG_FILE
    # Input file columns are pipe delimited (coldel|)
        
#CANNOT INDENT DOWN TO 99EOFSQLTEXT99 LINE
cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

rollback;

import from $TFORMULARY_DRUG_BKUP_DATA of del modified by coldel method p (1,2,3,4,5,6,7) commitcount 1000 messages $UDB_IMPORT_MSG_FILE REPLACE INTO $UDB_TO_SCHEMA_OWNER.TFORMULARY_DRUG_STATUS(FRMLY_SRC_CD,FRMLY_ID,DRUG_NDC_ID,NHU_TYP_CD,FRMLY_DRUG_STAT_CD,EFF_DT,END_DT);

99EOFSQLTEXT99

        print " "                                                              >> $LOG_FILE
        print "cat udb sql file "                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        cat $UDB_SQL_FILE >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "end showing udb sql file " >> $LOG_FILE
        print " "                                                              >> $LOG_FILE

        db2 -stvxf $UDB_SQL_FILE                                               >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

        # - dont reset the RETCODE value or script will not fail as it should!!
        BKUP_RETCODE=$?

        print " "                                                              >> $LOG_FILE
        if [[ $BKUP_RETCODE != 0 ]]; then 
            print "Error importing data into TFORMULARY_DRUG_STATUS,"          >> $LOG_FILE 
            print "Return Code = "$BKUP_RETCODE                                >> $LOG_FILE
            print "Check Import error log: "$UDB_IMPORT_MSG_FILE               >> $LOG_FILE
            print "Here are last 20 lines of that file - "                     >> $LOG_FILE
            print " "                                                          >> $LOG_FILE
            print " "                                                          >> $LOG_FILE
            tail -20 $UDB_IMPORT_MSG_FILE                                      >> $LOG_FILE
            print " "                                                          >> $LOG_FILE
            print "***BACKUP DATA HAS NOT BEEN RELOADED***"                    >> $LOG_FILE
            print "***BACKUP DATA HAS NOT BEEN RELOADED***"                    >> $LOG_FILE
            print " "                                                          >> $LOG_FILE
            print "Data Input file is: "$TFORMULARY_DRUG_BKUP_DATA             >> $LOG_FILE
        else
            print "Return Code from UDB Import = "$BKUP_RETCODE                >> $LOG_FILE
            print "Successful Load of backup data - script will still abend."  >> $LOG_FILE
        fi

        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
    else
        print "Skipped UDB IMPORT from >BACKUP< file because script "          >> $LOG_FILE    
        print "  did not truncate TFORMULARY_DRUG_STATUS."                     >> $LOG_FILE    
    fi
else
    print "Skipped UDB IMPORT from >BACKUP< file because script successful."   >> $LOG_FILE    
fi

print "=================================================================="     >> $LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#
 
if [[ $RETCODE != 0 ]]; then
   print " "                                                                   >> $LOG_FILE
   EMAILPARM4="  "
   EMAILPARM5="  "
   
   . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh
   cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

rm -f $ORA_SQL_FILE
rm -f $UDB_SQL_FILE
rm -f $UDB_MSG_FILE
rm -f $UDB_OUTPUT_MSG_FILE
rm -f $UDB_IMPORT_MSG_FILE
rm -f $SQL_PIPE_FILE
# Remove this next file only on successful execution - Maestro trigger file for this job
rm -r $MAESTRO_TRG_FILE

print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE



