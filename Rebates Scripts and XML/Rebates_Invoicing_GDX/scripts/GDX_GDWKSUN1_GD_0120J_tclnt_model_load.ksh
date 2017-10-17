#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDWKSUN1_GD_0120J_tclt_model_load.ksh   
# Title         : Load for the TCLT_MODEL table.
#
# Description   : This script will pull the GPO Rebate IDs from the GPO
#                 system via an Oracle client, and build a flat file.  
#                 Then once the data is extracted, a UDB IMPORT REPLACE
#                 will occur for the TCLT_MODEL table, wiping out all 
#                 existing data, and loading the new GPO Rebate IDs.  
#                 Once the GPO data has been loaded, then a UDB SELECT
#                 INSERT against the VRAP.TCLT table will run, inserting
#                 rows for the Discount model into the TCLT_MODEL table.
#
# Abends        : Prior to performing the UDB IMPORT REPLACE, the script
#                 will EXPORT the data from the TCLT_MODEL.  If there 
#                 are any issues during the script, AFTER the data has
#                 been deleted from TCLT_MODEL, the script will 
#                 automatically IMPORT the EXPORTed data.
#                 
# Maestro Job   : GDWKSUN1 GD_0120J
#
# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-10-05   qcpi733     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#


cat <<END_TXT
===========================================================================
This job is no longer needed and will be removed in October 2005.
It has not been removed from Maestro yet.

The job to replace this is GD_1012J on R07PRD01.
===========================================================================
END_TXT
exit 0


  . `dirname $0`/Common_GDX_Environment.ksh
#-------------------------------------------------------------------------#
# Call the Common used script functions to make functions available
#-------------------------------------------------------------------------#
. $SCRIPT_PATH/Common_GDX_Script_Functions.ksh
 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        ALTER_EMAIL_ADDRESS=""
        SCHEMA_OWNER="VRAP"
    else
        # Running in Prod region
        ALTER_EMAIL_ADDRESS=""
        SCHEMA_OWNER="VRAP"
    fi
else
    # Running in Development region
    ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
    SCHEMA_OWNER="VRAP"
fi

RETCODE=0
BKUP_RETCODE=0
SCHEDULE="GDWKSUN1"
JOB="GD_0120J"
FILE_BASE="GDX_"$SCHEDULE"_"$JOB"_tclnt_model_load"
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
# Output files
SQL_PIPE_FILE=$OUTPUT_PATH/$FILE_BASE"_pipe.lst"
GPO_RBATE_ID_DATA=$OUTPUT_PATH/$FILE_BASE"_gpo_rbate_ids.dat"
GPO_RBATE_ID_CNTS=$OUTPUT_PATH/$FILE_BASE"_gpo_rbate_id_cnts.dat"
TCLT_BKUP_DATA=$OUTPUT_PATH/$FILE_BASE"_tclt_bkup_export.dat"
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
ORA_SQL_SHARED_CLAUSE="    FROM  rbate_reg.client clnt ,rbate_reg.rebate_invoice reb_inv "
ORA_SQL_SHARED_CLAUSE=$ORA_SQL_SHARED_CLAUSE" WHERE clnt.pcs_system_id                     = reb_inv.pcs_system_id"
ORA_SQL_SHARED_CLAUSE=$ORA_SQL_SHARED_CLAUSE" AND   NVL(reb_inv.rebate_inv_term_dt,TO_DATE('12319999','MMDDYYYY')) >= ADD_MONTHS(TO_DATE(TO_CHAR(SYSDATE)),-9)"
ORA_SQL_SHARED_CLAUSE=$ORA_SQL_SHARED_CLAUSE" AND   UPPER(clnt.client_nbr)                 = LOWER(clnt.client_nbr)"

rm -f $LOG_FILE
rm -f $ORA_SQL_FILE
rm -f $UDB_SQL_FILE
rm -f $UDB_MSG_FILE
rm -f $UDB_OUTPUT_MSG_FILE
rm -f $UDB_IMPORT_MSG_FILE
rm -f $SQL_PIPE_FILE

#-------------------------------------------------------------------------#
# Starting the script to load the TCLNT_MODEL table
#-------------------------------------------------------------------------#
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the script to load the TCLNT_MODEL table"                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# First step is to back up the existing data, in case there is a problem
# during this script run.  In that case the script can restore the 
# original data for use while IT troubleshoots current problem.
#-------------------------------------------------------------------------#

print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the UDB EXPORT from VRAP.TCLT_MODEL"                           >> $LOG_FILE
# Export data to a pipe delimited file.  This file can be used to send to users if requested.

print "export to $TCLT_BKUP_DATA of del modified by coldel| SELECT * FROM $SCHEMA_OWNER.TCLT_MODEL;" > $UDB_SQL_FILE

print " "                                                                      >> $LOG_FILE
cat $UDB_SQL_FILE                                                              >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

$UDB_CONNECT_STRING                                                            >> $LOG_FILE
db2 -stvxf $UDB_SQL_FILE                                                       >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

RETCODE=$?

print " "                                                                      >> $LOG_FILE
if [[ $RETCODE != 0 ]]; then 
    print "Error exporting data from TCLT_MODEL, Return Code = "$RETCODE       >> $LOG_FILE
    print "Check Import error log: "$UDB_OUTPUT_MSG_FILE                       >> $LOG_FILE
    print "Here are last 20 lines of that file - "                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    tail -20 $UDB_OUTPUT_MSG_FILE                                              >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Data output file is: "$TCLT_BKUP_DATA                               >> $LOG_FILE
else
    print "Return Code from UDB Export = "$RETCODE                             >> $LOG_FILE
    print "Successful backup - continue with script."                          >> $LOG_FILE
    EXISTING_DATA_EXP_FLAG='Y'
fi

print " "                                                                      >> $LOG_FILE
print "=================================================================="     >> $LOG_FILE

if [[ $RETCODE = 0 ]]; then 
    #-------------------------------------------------------------------------#
    # Rebate ID Extract
    # Set up the Pipe file, then build and EXEC the new SQL.               
    # Get the record count from the input for validation of rows
    #-------------------------------------------------------------------------#
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Begin building Oracle SQL file for GPO Rebate ID Extract"           >> $LOG_FILE
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
    dd if=$SQL_PIPE_FILE of=$GPO_RBATE_ID_DATA bs=100k &

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
SELECT  RTRIM(TO_CHAR(clnt.client_nbr)) AS rbate_id
       ,'|'
       ,'G' model_typ_cd
       ,'|'
       ,clnt.client_name AS rbate_id_nam
       ,'|' --next field is null because of CLIENT_CD field
    $ORA_SQL_SHARED_CLAUSE       
    order by 1
;
spool off
spool $GPO_RBATE_ID_CNTS
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
    print "Completed extract of GPO Rebate IDs"                                >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        print "Failure in Extract "                                            >> $LOG_FILE
        print "Oracle error is "                                               >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -20 $GPO_RBATE_ID_DATA                                            >> $LOG_FILE
    else
        print "Successfull extract of GPO Rebate ID data."                     >> $LOG_FILE

        EXTRACT_REC_CNT=$(< $GPO_RBATE_ID_CNTS) 

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
    # Start the DELETE of ALL Clients in the TCLT_MODEL table.
    # CANNOT run IMPORT...REPLACE on the TCLT_MODEL table because of the 
    #   MQT_TCLT_MODEL dependancy.
    #-------------------------------------------------------------------------#

    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Starting the Delete of Discount Clients from the TCLT_MODEL table." >> $LOG_FILE
    # Set the flag showing that the UDB Import was attempted.  This flag tells the script
    #   whether or not it should reload the backup data should the script fail during or
    #   after the TCLT_MODEL data was truncated.
    EXISTING_DATA_DEL_FLAG='Y'
    print " "                                                                  >> $LOG_FILE

    print "delete from $SCHEMA_OWNER.tclt_model;"                              >  $UDB_SQL_FILE

    db2 -stvxf $UDB_SQL_FILE                                                   >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

    RETCODE=$?

    print " "                                                                  >> $LOG_FILE
    if [[ $RETCODE != 0 ]]; then 
        print "Error DELETING from the $SCHEMA_OWNER.TCLT_MODEL table."        >> $LOG_FILE
        print "Return Code = "$RETCODE                                         >> $LOG_FILE
        print "Check UDB error log: "$UDB_OUTPUT_MSG_FILE                      >> $LOG_FILE
        print "Here are last 20 lines of that file - "                         >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -20 $UDB_OUTPUT_MSG_FILE                                          >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Script will NOT reload TCLT_MODEL because the data was not"     >> $LOG_FILE 
        print "  deleted successfully."                                        >> $LOG_FILE 
    else
        print " "                                                              >> $LOG_FILE
        print "cat udb sql file "                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        cat $UDB_OUTPUT_MSG_FILE                                               >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "end udb sql file "                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Return Code from UDB INSERT = "$RETCODE                         >> $LOG_FILE
        print "Successful DELETE - continue with script."                      >> $LOG_FILE
        # Set the flag showing that the DELETE was completed.  This flag tells the script
        #   whether or not it should reload the backup data should the script fail after this point.
        EXISTING_DATA_DEL_FLAG='Y'
    fi

    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
else
    print "Skipped UDB INSERT from TCLT due to previous errors."               >> $LOG_FILE    
fi

print "=================================================================="     >> $LOG_FILE


if [[ $RETCODE = 0 ]]; then
    #-------------------------------------------------------------------------#
    # Start the UDB DB2 IMPORT.  Import the data extracted above from the 
    #   Oracle instance.  Data contains GPO Rebate IDs to be added to TCLT_MODEL.
    #   CANNOT Use REPLACE because of MQT_TCNT_MODEL dependancy.
    #-------------------------------------------------------------------------#

    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Starting the UDB IMPORT into VRAP.TCLT_MODEL"                       >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    # Input file columns are pipe delimited (coldel|)


    print "import from $GPO_RBATE_ID_DATA of del modified by coldel| method p (1,2,3,4) commitcount 1000 INSERT INTO $SCHEMA_OWNER.TCLT_MODEL(CLT_ID,MODEL_TYP_CD,CLT_NM,CLIENT_CD);" > $UDB_SQL_FILE

    print "cat udb sql file "                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    cat $UDB_SQL_FILE                                                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "end udb sql file "                                                  >> $LOG_FILE

    db2 -stvxf $UDB_SQL_FILE                                                   >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

    RETCODE=$?

    print " "                                                                  >> $LOG_FILE
    if [[ $RETCODE != 0 ]]; then 
        print "Error importing data into TCLT_MODEL, Return Code = "$RETCODE   >> $LOG_FILE
        print "Check Import error log: "$UDB_OUTPUT_MSG_FILE                   >> $LOG_FILE
        print "Here are last 20 lines of that file - "                         >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -20 $UDB_OUTPUT_MSG_FILE                                          >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Data Input file is: "$GPO_RBATE_ID_DATA                         >> $LOG_FILE
        print "Script will now reload TCLT_MODEL with original data."          >> $LOG_FILE 
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
            print "  DOES NOT MATCH the number of rows inserted via the "      >> $LOG_FILE
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
 
if [[ $RETCODE = 0 ]]; then
    #-------------------------------------------------------------------------#
    # Start the Refresh of DIScount Clients into TCLT_MODEL from TCLT
    #-------------------------------------------------------------------------#

    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Starting the Insert of Discount Clients into TCLT_MODEL"            >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    print "insert into $SCHEMA_OWNER.tclt_model select tc.clt_id ,'D' ,tc.clt_nm ,tc.client_cd from $SCHEMA_OWNER.tclt tc order by tc.clt_id;" > $UDB_SQL_FILE

    db2 -stvxf $UDB_SQL_FILE                                                   >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

    RETCODE=$?

    print " "                                                                  >> $LOG_FILE
    if [[ $RETCODE != 0 ]]; then 
        print "Error INSERTing into TCLT_MODEL from TCLT."                     >> $LOG_FILE
        print "Return Code = "$RETCODE                                         >> $LOG_FILE
        print "Check UDB error log: "$UDB_OUTPUT_MSG_FILE                      >> $LOG_FILE
        print "Here are last 20 lines of that file - "                         >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -20 $UDB_OUTPUT_MSG_FILE                                          >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Script will now reload TCLT_MODEL with original data."          >> $LOG_FILE 
    else
        print "cat udb sql file "                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        cat $UDB_OUTPUT_MSG_FILE                                               >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "end udb sql file "                                              >> $LOG_FILE
        print "Return Code from UDB INSERT = "$RETCODE                         >> $LOG_FILE
        print "Successful INSERT - continue with script."                      >> $LOG_FILE
    fi

    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
else
    print "Skipped UDB INSERT from TCLT due to previous errors."               >> $LOG_FILE    
fi

print "=================================================================="     >> $LOG_FILE

#-------------------------------------------------------------------------#
# Check for invalid return code and need to reload original data   
#  ONLY do this if (1) the TCLT_MODEL table data was exported, and (2)
#  only if the existing data in TCLT_MODEL was truncated during the 
#  IMPORT of GPO Rebate IDs.
#-------------------------------------------------------------------------#
if [[ $RETCODE != 0 ]]; then
    if [[ $EXISTING_DATA_EXP_FLAG = 'Y' && $EXISTING_DATA_DEL_FLAG = 'Y' ]]; then 
        print " "                                                              >> $LOG_FILE
        print `date +"%D %r %Z"`                                               >> $LOG_FILE
        print "An error occurred after data in TCLT_MODEL was truncated."      >> $LOG_FILE
        print "A reload of the backup data is required. Starting UDB Import"   >> $LOG_FILE
        print "  using exported backup data."                                  >> $LOG_FILE
        # Input file columns are pipe delimited (coldel|)

        print "rollback;"                                                      >  $UDB_SQL_FILE 
        print " "                                                              >>  $UDB_SQL_FILE 
        print "delete from $SCHEMA_OWNER.tclt_model;"                          >> $UDB_SQL_FILE
        print " "                                                              >>  $UDB_SQL_FILE 
        print "import from $TCLT_BKUP_DATA of del modified by coldel| method p (1,2,3,4) commitcount 1000 messages $UDB_IMPORT_MSG_FILE INSERT INTO $SCHEMA_OWNER.TCLT_MODEL(CLT_ID,MODEL_TYP_CD,CLT_NM,CLIENT_CD);" >> $UDB_SQL_FILE 

        db2 -stvxf $UDB_SQL_FILE                                               >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

        # - dont reset the RETCODE value or script will not fail as it should!!
        BKUP_RETCODE=$?

        print " "                                                              >> $LOG_FILE
        if [[ $BKUP_RETCODE != 0 ]]; then 
            print "Error importing data into TCLT_MODEL,"                      >> $LOG_FILE 
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
            print "Data Input file is: "$TCLT_BKUP_DATA                        >> $LOG_FILE
        else
            print "cat udb sql file "                                          >> $LOG_FILE
            print " "                                                          >> $LOG_FILE
            cat $UDB_OUTPUT_MSG_FILE                                           >> $LOG_FILE
            print " "                                                          >> $LOG_FILE
            print "end udb sql file "                                          >> $LOG_FILE
            print "Return Code from UDB Import = "$BKUP_RETCODE                >> $LOG_FILE
            print "Successful Load of backup data - script will still abend."  >> $LOG_FILE
        fi

        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
    else
        print "Skipped UDB IMPORT from >BACKUP< file because script "          >> $LOG_FILE    
        print "  did not truncate TCLT_MODEL."                                 >> $LOG_FILE    
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
   print "===================== J O B  A B E N D E D ======================"   >> $LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                      >> $LOG_FILE
   print "  Look in "$LOG_FILE                                                 >> $LOG_FILE
   print "================================================================="   >> $LOG_FILE
   
   # Send the Email notification 
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

print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE

