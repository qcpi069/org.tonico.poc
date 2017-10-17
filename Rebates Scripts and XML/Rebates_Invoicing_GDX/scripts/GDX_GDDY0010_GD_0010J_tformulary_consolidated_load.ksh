#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDDY0002_GD_0002J_tformulary_consolidated_load.ksh   
# Title         : Load for the TFORMULARY_CONSOLIDATED table.
#
# Description   : This script will pull the GPO Formulary IDs from the GPO
#                 system via an Oracle client, and build a flat file.  
#                 Then once the data is extracted, a UDB IMPORT REPLACE
#                 will occur for the TFORMULARY_CONSOLIDATED table, wiping  
#                 out all existing data, and loading the new GPO Formulary   
#                 IDs.  Once the GPO data has been loaded, then a UDB 
#                 SELECT INSERT from the VRAP.TFORMULARY table will run, 
#                 inserting rows for the Discount model into the 
#                 TFORMULARY_CONSOLIDATED table.
#                 Also insert PharmaCare formulary data into TFORMULARY_CONSOLIDATED table
#
# Abends        : Prior to performing the UDB IMPORT REPLACE, the script
#                 will EXPORT the data from the TFORMULARY_CONSOLIDATED. 
#                 If there are any issues during the script, AFTER the data
#                 has been deleted from TFORMULARY_CONSOLIDATED, the script 
#                 will automatically IMPORT the EXPORTed data.
#                 
# Maestro Job   : GDDY0002 GD_0002J
#
# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-14-05   qcpi733     Initial Creation.
# 08-07-07   qcpi08a     Add PharmaCare formulary data into TFORMULARY_CONSOLIDATED
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
        export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
        UDB_FROM_SCHEMA_OWNER="CLAIMSP"
        UDB_TO_SCHEMA_OWNER="VRAP"
        ORA_SCHEMA_OWNER="DWCORP"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        UDB_FROM_SCHEMA_OWNER="CLAIMSP"
        UDB_TO_SCHEMA_OWNER="VRAP"
        ORA_SCHEMA_OWNER="DWCORP"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
    UDB_FROM_SCHEMA_OWNER="CLAIMSP"
    UDB_TO_SCHEMA_OWNER="VRAP"
    ORA_SCHEMA_OWNER="DWCORP"
fi

RETCODE=0
BKUP_RETCODE=0
SCHEDULE="GDDY0002"
JOB="GD_0002J"
FILE_BASE="GDX_"$SCHEDULE"_"$JOB"_tformulary_consolidated_load"
SCRIPTNAME=$FILE_BASE".ksh"
# LOG FILES
LOG_FILE_ARCH=$FILE_BASE".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_ARCH
LOG_FILE_PHC=${LOG_ARCH_PATH}"/GDX_GD_0010J_tformulary_consolidated_load_phc.log"
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
GPO_FORMULARY_ID_DATA=$OUTPUT_PATH/$FILE_BASE"_gpo_formulary_ids.dat"
GPO_FORMULARY_ID_CNTS=$OUTPUT_PATH/$FILE_BASE"_gpo_formulary_id_cnts.lst"
TFORMULARY_BKUP_DATA=$OUTPUT_PATH/$FILE_BASE"_tformulary_cons_bkup_export.dat"
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
ORA_SQL_SHARED_CLAUSE="    FROM $ORA_SCHEMA_OWNER.mv_frmly vf "
#--- Next variable holds the UDB SQL to pull QL Formularies into the TFORMULARY_CONSOLIDATED table.
#--- The max_name subselect is done to pull the most recent Formulary name when multiple rows exist for one formulary id
UDB_QL_FORMULARY_SQL="SELECT  cast(frmly.formulary_id as char(10)) ,'Q' formulary_src_cd ,frmlynm.formulary_nm "
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL"       ,'01/01/1900' effective_date ,'12/31/9999' expiration_date"
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL" FROM  "$UDB_FROM_SCHEMA_OWNER".tformulary frmly "
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL"      ,(SELECT  frmly1.formulary_nm"
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL"               ,frmly1.formulary_id "
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL"               ,ROW_NUMBER() OVER (PARTITION BY frmly1.formulary_id"
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL"                    ORDER BY frmly1.dw_expiration_dt DESC"
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL"               ,frmly1.formulary_nm) max_name"
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL"            FROM  "$UDB_FROM_SCHEMA_OWNER".tformulary frmly1) frmlynm"
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL" WHERE    frmly.formulary_id = frmlynm.formulary_id"
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL" AND      frmlynm.max_name = 1"
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL" AND      frmly.dw_effective_dt < frmly.dw_expiration_dt"
UDB_QL_FORMULARY_SQL=$UDB_QL_FORMULARY_SQL" GROUP BY frmly.formulary_id ,frmlynm.formulary_nm"

rm -f $LOG_FILE
rm -f $ORA_SQL_FILE
rm -f $UDB_SQL_FILE
rm -f $UDB_MSG_FILE
rm -f $UDB_OUTPUT_MSG_FILE
rm -f $UDB_IMPORT_MSG_FILE
rm -f $SQL_PIPE_FILE

#-------------------------------------------------------------------------#
# Starting the script to load the TFORMULARY_CONSOLIDATED table
#-------------------------------------------------------------------------#
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the script to load the TFORMULARY_CONSOLIDATED table"          >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# First step is to back up the existing data, in case there is a problem
# during this script run.  In that case the script can restore the 
# original data for use while IT troubleshoots current problem.
#-------------------------------------------------------------------------#

print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the UDB EXPORT from VRAP.TFORMULARY_CONSOLIDATED"              >> $LOG_FILE
# Export data to a pipe delimited file.  This file can be used to send to users if requested.

cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

export to $TFORMULARY_BKUP_DATA of del modified by coldel| SELECT * FROM $UDB_TO_SCHEMA_OWNER.TFORMULARY_CONSOLIDATED;

99EOFSQLTEXT99
 
print " "                                                                      >> $LOG_FILE
cat $UDB_SQL_FILE >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

$UDB_CONNECT_STRING                                                            >> $LOG_FILE
db2 -stvxf $UDB_SQL_FILE                                                       >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

RETCODE=$?

print " "                                                                      >> $LOG_FILE
if [[ $RETCODE != 0 ]]; then 
    print "Error exporting data from TFORMULARY_CONSOLIDATED. "                >> $LOG_FILE
    print " Return Code = "$RETCODE                                            >> $LOG_FILE
    print "Check Import error log: "$UDB_OUTPUT_MSG_FILE                       >> $LOG_FILE
    print "Here are last 20 lines of that file - "                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    tail -20 $UDB_OUTPUT_MSG_FILE                                              >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Data output file is: "$TFORMULARY_BKUP_DATA                         >> $LOG_FILE
else
    print "Return Code from UDB Export = "$RETCODE                             >> $LOG_FILE
    print "Successful backup - continue with script."                          >> $LOG_FILE
    EXISTING_DATA_EXP_FLAG='Y'
fi

print " "                                                                      >> $LOG_FILE
print "=================================================================="     >> $LOG_FILE

if [[ $RETCODE = 0 ]]; then 
    #-------------------------------------------------------------------------#
    # Formulary ID Extract
    # Set up the Pipe file, then build and EXEC the new SQL.               
    # Get the record count from the input for validation of rows
    #-------------------------------------------------------------------------#
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Begin building Oracle SQL file for GPO Formulary ID Extract"        >> $LOG_FILE
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
    dd if=$SQL_PIPE_FILE of=$GPO_FORMULARY_ID_DATA bs=100k &

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
SELECT  vf.drug_list_nbr
       ,'|'
       ,drug_list_extnl_type
       ,'|'
       ,vf.drug_list_name
       ,'|'
       ,TO_CHAR(vf.eff_date,'MM/DD/YYYY')
       ,'|'
       ,nvl(to_char(vf.end_date,'MM/DD/YYYY'),'12/31/9999')
    $ORA_SQL_SHARED_CLAUSE       
    order by drug_list_extnl_type ,vf.drug_list_nbr 
;
spool off
spool $GPO_FORMULARY_ID_CNTS
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
    print "Completed extract of GPO Formulary IDs"                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        print "Failure in Extract "                                            >> $LOG_FILE
        print "Oracle error is "                                               >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -20 $GPO_FORMULARY_ID_DATA                                        >> $LOG_FILE
    else
        print "Successfull extract of GPO Formulary ID data."                  >> $LOG_FILE

        EXTRACT_REC_CNT=$(< $GPO_FORMULARY_ID_CNTS)

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
    #   Oracle instance.  Data contains GPO Formulary IDs to be added to 
    #   TFORMULARY_CONSOLIDATED.  Use REPLACE to truncate the existing data 
    #   in the TFORMULARY_CONSOLIDATED.  If script fails after this point 
    #   then the script will reload the TFORMULARY_CONSOLIDATED with
    #   its original data (prior to this script executing).
    #-------------------------------------------------------------------------#

    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Starting the UDB IMPORT into VRAP.TFORMULARY_CONSOLIDATED"          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    # Input file columns are pipe delimited (coldel|)

#CANNOT INDENT DOWN TO 99EOFSQLTEXT99 LINE
cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

import from $GPO_FORMULARY_ID_DATA of del modified by coldel| method p (1,2,3,4,5) commitcount 1000 REPLACE INTO $UDB_TO_SCHEMA_OWNER.TFORMULARY_CONSOLIDATED(FRMLY_ID,FRMLY_SRC_CD,FORMULARY_NM,EFF_DT,END_DT);

99EOFSQLTEXT99

    print " "                                                                  >> $LOG_FILE
    print "cat udb sql file "                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    cat $UDB_SQL_FILE                                                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "end cat of udb sql file "                                           >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    EXISTING_DATA_DEL_FLAG='Y'

    db2 -stvxf $UDB_SQL_FILE                                                   >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

    RETCODE=$?

    print " "                                                                  >> $LOG_FILE
    if [[ $RETCODE != 0 ]]; then 
        print "Error importing data into TFORMULARY_CONSOLIDATED. "            >> $LOG_FILE
        print "Return Code = "$RETCODE                                         >> $LOG_FILE
        print "Check Import error log: "$UDB_OUTPUT_MSG_FILE                   >> $LOG_FILE
        print "Here are last 30 lines of that file - "                         >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -30 $UDB_OUTPUT_MSG_FILE                                          >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Data Input file is: "$GPO_FORMULARY_ID_DATA                     >> $LOG_FILE
        print "Script will now reload TFORMULARY_CONSOLIDATED with "           >> $LOG_FILE 
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
    # Start the Refresh of DIScount Clients into TFORMULARY_CONSOLIDATED from TFORMULARY
    #-------------------------------------------------------------------------#

    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Starting the Insert of Discount Formularies into "                  >> $LOG_FILE
    print "  TFORMULARY_CONSOLIDATED"                                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

#CANNOT INDENT DOWN TO 99EOFSQLTEXT99 LINE
cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

insert into $UDB_TO_SCHEMA_OWNER.tformulary_consolidated $UDB_QL_FORMULARY_SQL;

99EOFSQLTEXT99
 
    print " "                                                                  >> $LOG_FILE
    print "cat udb sql file "                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    cat $UDB_SQL_FILE                                                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "end udb sql file "                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    db2 -stvxf $UDB_SQL_FILE                                                   >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

    RETCODE=$?

    print " "                                                                  >> $LOG_FILE
    if [[ $RETCODE != 0 ]]; then 
        print "Error INSERTing into TFORMULARY_CONSOLIDATED from TFORMULARY."  >> $LOG_FILE
        print "Return Code = "$RETCODE                                         >> $LOG_FILE
        print "Check UDB error log: "$UDB_OUTPUT_MSG_FILE                      >> $LOG_FILE
        print "Here are last 20 lines of that file - "                         >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -20 $UDB_OUTPUT_MSG_FILE                                          >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Script will now reload TFORMULARY_CONSOLIDATED with "           >> $LOG_FILE
        print "  original data."                                               >> $LOG_FILE 
    else
        print "Return Code from UDB INSERT = "$RETCODE                         >> $LOG_FILE
        print "Successful INSERT - continue with script."                      >> $LOG_FILE
    fi

    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
else
    print "Skipped UDB INSERT from TFORMULARY due to previous errors."         >> $LOG_FILE    
fi

print " "
print "=================================================================="     >> $LOG_FILE
    #-------------------------------------------------------------------------#
    #
    # Begin insert PharmaCare Formulary into TFORMULARY_CONSOLIDATED
    #
    #-------------------------------------------------------------------------#

if [[ $RETCODE = 0 ]]; then
    {
        print `date +"%D %r %Z"`                                                   
        print " Insert PharmaCare Formulary into VRAP.TFORMULARY_CONSOLIDATED "
        print " Common_java_db_interface.ksh GDX_GD_0010J_tformulary_consolidated_load_phc.xml" 
        print " Please read log file : " $LOG_FILE_PHC
        print ""
    }   >> $LOG_FILE
    
    $SCRIPT_PATH/Common_java_db_interface.ksh GDX_GD_0010J_tformulary_consolidated_load_phc.xml >> $LOG_FILE 

    RETCODE=$?
    print " "                                                                      >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
    {
        print " Error inserting PharmaCare Formulary into TFORMULARY_CONSOLIDATED. " 
        print " Return Code = "$RETCODE    
        print " Please check inserting error log: "$LOG_FILE_PHC                
        print " "                                          
        print " "                                         
        print " Script will reload TFORMULARY_CONSOLIDATED with original data. "

    }   >> $LOG_FILE
    else
    {
        print " Return Code from inserting PharmaCare Formulary = "$RETCODE     
        print " Successful Insert - continue with script."                     
        print " "                                                            
        print " " 
                                                         
    }   >> $LOG_FILE 
    fi

    print `date +"%D %r %Z"`                                                    >> $LOG_FILE
    print " "                                                                   >> $LOG_FILE

else
    print " Skipped insert PharmaCare Formulary due to previous error."         >> $LOG_FILE
fi

print " "                                                                      >> $LOG_FILE
print "=================================================================="     >> $LOG_FILE
 
#-------------------------------------------------------------------------#
# Check for invalid return code and need to reload original data   
#  ONLY do this if (1) the TFORMULARY_CONSOLIDATED table data was exported, and (2)
#  only if the existing data in TFORMULARY_CONSOLIDATED was truncated during the 
#  IMPORT of GPO Formulary IDs.
#-------------------------------------------------------------------------#
if [[ $RETCODE != 0 ]]; then
    if [[ $EXISTING_DATA_EXP_FLAG = 'Y' && $EXISTING_DATA_DEL_FLAG = 'Y' ]]; then 
        print " "                                                              >> $LOG_FILE
        print `date +"%D %r %Z"`                                               >> $LOG_FILE
        print "An error occurred after data in TFORMULARY_CONSOLIDATED was "   >> $LOG_FILE
        print "  truncated."                                                   >> $LOG_FILE
        print "A reload of the backup data is required. Starting UDB Import"   >> $LOG_FILE
        print "  using exported backup data."                                  >> $LOG_FILE
    # Input file columns are pipe delimited (coldel|)
        
#CANNOT INDENT DOWN TO 99EOFSQLTEXT99 LINE
cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

rollback;

import from $TFORMULARY_BKUP_DATA of del modified by coldel| method p (1,2,3,4,5) commitcount 1000 messages $UDB_IMPORT_MSG_FILE REPLACE INTO $UDB_TO_SCHEMA_OWNER.TFORMULARY_CONSOLIDATED(FRMLY_ID,FRMLY_SRC_CD,FORMULARY_NM,EFF_DT,END_DT);

99EOFSQLTEXT99

        print " "                                                              >> $LOG_FILE
        print "cat udb sql file "                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        cat $UDB_SQL_FILE                                                      >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "end showing udb sql file "                                      >> $LOG_FILE
        print " "                                                              >> $LOG_FILE

        db2 -stvxf $UDB_SQL_FILE                                               >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

        # - dont reset the RETCODE value or script will not fail as it should!!
        BKUP_RETCODE=$?

        print " "                                                              >> $LOG_FILE
        if [[ $BKUP_RETCODE != 0 ]]; then 
            print "Error importing data into TFORMULARY_CONSOLIDATED,"         >> $LOG_FILE 
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
            print "Data Input file is: "$TFORMULARY_BKUP_DATA                  >> $LOG_FILE
        else
            print "Return Code from UDB Import = "$BKUP_RETCODE                >> $LOG_FILE
            print "Successful Load of backup data - script will still abend."  >> $LOG_FILE
        fi

        print " "                                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
    else
        print "Skipped UDB IMPORT from >BACKUP< file because script "          >> $LOG_FILE    
        print "  did not truncate TFORMULARY_CONSOLIDATED."                    >> $LOG_FILE    
    fi
else
    print "Skipped UDB IMPORT from >BACKUP< file because script successful."   >> $LOG_FILE    
fi

print "=================================================================="     >> $LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#
 
if [[ $RETCODE != 0 ]]; then
    #  Abend - call the abend email script.  
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
print " "                                                                      >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE

