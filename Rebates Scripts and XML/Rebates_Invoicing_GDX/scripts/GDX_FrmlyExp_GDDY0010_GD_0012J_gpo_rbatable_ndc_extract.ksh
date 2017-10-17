#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_FrmlyExp_GDDY0010_GD_0012J_gpo_rbatable_ndc_extract.ksh   
# Title         : Extract of Rebatable GPO NDCs for Formulary Expansion.
#
# Description   : This script will pull the GPO Rebatable NDCs from the GDX
#                 system, for use in the GPO Formulary Expansion process
#                 on REBDOM1.  
#                 The NDCs extracted from the GDX system will be input 
#                 into the GPO Formulary Expansion on the GPO system.
#
# Maestro Job   : GDDY0010 GD_0012J
#
# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-16-05   qcpi733     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS=""
        UDB_SCHEMA_OWNER="VRAP"
        ORA_SCHEMA_OWNER="DMA_RBATE2"
        FTP_IP=REBDOM1
        REBDOM1_INPUT_DIR="/staging/apps/rebates/prod/input"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        UDB_SCHEMA_OWNER="VRAP"
        ORA_SCHEMA_OWNER="DMA_RBATE2"
        FTP_IP=REBDOM1
        REBDOM1_INPUT_DIR="/staging/apps/rebates/prod/input"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
    UDB_SCHEMA_OWNER="VRAP"
    ORA_SCHEMA_OWNER="DMA_RBATE2"
    FTP_IP=DEVDOM3
    REBDOM1_INPUT_DIR="/staging/apps/rebates/dev3/input"
fi

RETCODE=0
SCHEDULE="GDDY0010"
JOB="GD_0012J"
FILE_BASE="GDX_FrmlyExp_"$SCHEDULE"_"$JOB"_gpo_rbatable_ndc_extract"
SCRIPTNAME=$FILE_BASE".ksh"
# LOG FILES
LOG_FILE_ARCH=$FILE_BASE".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_ARCH
# Oracle and UDB SQL files
ORA_SQL_FILE=$SQL_PATH/$FILE_BASE"_ora.sql"
UDB_SQL_FILE=$SQL_PATH/$FILE_BASE"_udb.sql"
UDB_CONNECT_STRING="db2 -p connect to "$DATABASE" user "$CONNECT_ID" using "$CONNECT_PWD
# SQL Message files
ORA_OUTPUT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_ora_sql.msg"
# Input files
#  This input file is the trigger for the Maestro schedule to submit this job. Remove after successful completion.
MAESTRO_IN_TRG_FILE=$INPUT_PATH/"rbate_RIOR4520_RI_4519J.trg"
# Output files
GPO_RBATABLE_NDC_INS_CNTS=$OUTPUT_PATH/$FILE_BASE"_ora_ins_cnts.dat"
GPO_RBATABLE_NDC_DATA=$OUTPUT_PATH/$FILE_BASE".dat"
GPO_RBATABLE_NDC_EXT_CNTS=$OUTPUT_PATH/$FILE_BASE"_udb_ext_cnts.dat"
FTP_CGD_FILE=$OUTPUT_PATH/$FILE_BASE"_ftpcommands.txt"
MAESTRO_OUT_TRG_FILE=$INPUT_PATH/"GDX_"$SCHEDULE"_"$JOB".trg"
# Misc
EXTRACT_REC_CNT=0
INSERT_REC_CNT=0
# SQL Commands
# -- This SQL is building a file with Oracle INSERT statements, so that the inserts can be run from
# --   the AIX box via the Oracle Client.  You cannot use DISTINCT command if not on the first 
# --   column, so a GROUP BY is being used to get only distinct NDCs.  Only the GPO Rebatable NDCs
# --   are needed.  The dummy DRUG_GID is used because the Oracle staging table needs to have
# --   the drug gid updated and present to be included in the Oracle Formulary Expansion.
# -- The extract SELECT is unique, but the FROM and WHERE clauses are used in the COUNT SQL.
GPO_RBATABLE_NDC_SEL="SELECT 'INSERT INTO "$ORA_SCHEMA_OWNER".s_gdx_drug_for_frmly_exp VALUES ('"
GPO_RBATABLE_NDC_SEL=$GPO_RBATABLE_NDC_SEL"       ,''''||SUBSTR(CAST(n11.drug_ndc_id AS CHAR(12)),1,11)||''''"
GPO_RBATABLE_NDC_SEL=$GPO_RBATABLE_NDC_SEL"       ,','"
GPO_RBATABLE_NDC_SEL=$GPO_RBATABLE_NDC_SEL"       ,0 drug_gid"
GPO_RBATABLE_NDC_SEL=$GPO_RBATABLE_NDC_SEL"       ,');'"
# now create the shared FROM clause - used in data extract and count retrieval
GPO_RBATABLE_NDC_FROM="    FROM  "$UDB_SCHEMA_OWNER".tcntrct    c"
GPO_RBATABLE_NDC_FROM=$GPO_RBATABLE_NDC_FROM"         ,"$UDB_SCHEMA_OWNER".trpt_reqmt r"
GPO_RBATABLE_NDC_FROM=$GPO_RBATABLE_NDC_FROM"         ,"$UDB_SCHEMA_OWNER".vrpt_cd    cd12"
GPO_RBATABLE_NDC_FROM=$GPO_RBATABLE_NDC_FROM"         ,"$UDB_SCHEMA_OWNER".trpt_ndc11 n11"
# now create the shared WHERE clause
GPO_RBATABLE_NDC_WHERE="    WHERE c.cntrct_id    = r.cntrct_id"
GPO_RBATABLE_NDC_WHERE=$GPO_RBATABLE_NDC_WHERE"    AND   r.rpt_typ_cd   = cd12.rpt_cd"
GPO_RBATABLE_NDC_WHERE=$GPO_RBATABLE_NDC_WHERE"    AND   cd12.rpt_cd_nm LIKE 'R%'"
GPO_RBATABLE_NDC_WHERE=$GPO_RBATABLE_NDC_WHERE"    AND   r.rpt_id       = n11.rpt_id"
GPO_RBATABLE_NDC_WHERE=$GPO_RBATABLE_NDC_WHERE"    AND   c.model_typ_cd = 'G' "     
# add the GROUP and ORDER for the extract only
GPO_RBATABLE_NDC_GRP_ORDR="    GROUP BY SUBSTR(CAST(n11.drug_ndc_id AS CHAR(12)),1,11)"
GPO_RBATABLE_NDC_GRP_ORDR=$GPO_RBATABLE_NDC_GRP_ORDR"    ORDER BY 1, 2;"
# now build the entire extract sql
GPO_RBATABLE_NDC_SQL=$GPO_RBATABLE_NDC_SEL$GPO_RBATABLE_NDC_FROM$GPO_RBATABLE_NDC_WHERE$GPO_RBATABLE_NDC_GRP_ORDR
# -- Need to get the counts of records pulled from the above sql
GPO_RBATABLE_NDC_SQL_CNTS_SEL="SELECT COUNT(DISTINCT n11.drug_ndc_id)"
# -- now build the entire counts SQL using the previously defined FROM and WHERE clauses
GPO_RBATABLE_NDC_SQL_CNTS=$GPO_RBATABLE_NDC_SQL_CNTS_SEL$GPO_RBATABLE_NDC_FROM$GPO_RBATABLE_NDC_WHERE";"

rm -f $LOG_FILE
rm -f $UDB_SQL_FILE
rm -f $ORA_SQL_FILE
rm -f $GPO_RBATABLE_NDC_DATA
rm -f $GPO_RBATABLE_NDC_INS_CNTS
rm -f $GPO_RBATABLE_NDC_EXT_CNTS 
rm -f $ORA_OUTPUT_MSG_FILE
rm -f $MAESTRO_OUT_TRG_FILE
rm -f $FTP_CGD_FILE

#-------------------------------------------------------------------------#
# Starting the script to Extract and load the GPO Rebatable NDCs
#-------------------------------------------------------------------------#
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the script to Extract and load the GPO Rebatable NDCs"         >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# First step is to extract the GPO Rebatable NDC rows from the GDX System.
#-------------------------------------------------------------------------#

print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the spooling of GPO Rebatable NDC rows"                        >> $LOG_FILE

cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

$GPO_RBATABLE_NDC_SQL

99EOFSQLTEXT99
 
print " "                                                                      >> $LOG_FILE
cat $UDB_SQL_FILE >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

$UDB_CONNECT_STRING                                                            >> $LOG_FILE
db2 -stxf $UDB_SQL_FILE                                                        >> $LOG_FILE > $GPO_RBATABLE_NDC_DATA

RETCODE=$?

print " "                                                                      >> $LOG_FILE
if [[ $RETCODE != 0 ]]; then 
    print "Error exporting data from TFORMULARY_CONSOLIDATED. "                >> $LOG_FILE
    print " Return Code = "$RETCODE                                            >> $LOG_FILE
    print "Check Import error log: "$GPO_RBATABLE_NDC_DATA                     >> $LOG_FILE
    print "Here are last 20 lines of that file - "                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    tail -20 $GPO_RBATABLE_NDC_DATA                                            >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Data output file is: "$GPO_RBATABLE_NDC_DATA                        >> $LOG_FILE
else
    print "Return Code from UDB Export = "$RETCODE                             >> $LOG_FILE
    print "Successful backup - continue with script."                          >> $LOG_FILE
fi

print " "                                                                      >> $LOG_FILE
print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

if [[ $RETCODE = 0 ]]; then 
    #-------------------------------------------------------------------------#
    # Next get counts of rows expected from above, for later validation
    #-------------------------------------------------------------------------#

    print "Starting to spool counts of GPO Rebatable NDC rows expected."       >> $LOG_FILE

cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

$GPO_RBATABLE_NDC_SQL_CNTS

99EOFSQLTEXT99
 
    print " "                                                                  >> $LOG_FILE
    cat $UDB_SQL_FILE                                                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    db2 -stxf $UDB_SQL_FILE                                                    >> $LOG_FILE > $GPO_RBATABLE_NDC_EXT_CNTS 

    RETCODE=$?

    if [[ $RETCODE != 0 ]]; then
        print "Failure in retrieving counts of extracted rows."                >> $LOG_FILE
        print "UDB error is "                                                  >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -20 $GPO_RBATABLE_NDC_EXT_CNTS                                    >> $LOG_FILE
    else
        print "Successfull row count of GPO Rebatable NDC data."               >> $LOG_FILE

        read EXTRACT_REC_CNT < $GPO_RBATABLE_NDC_EXT_CNTS
        #EXTRACT_REC_CNT=$(< $GPO_RBATABLE_NDC_EXT_CNTS)            

        print " "                                                              >> $LOG_FILE
        print "Number of rows Extracted - "$EXTRACT_REC_CNT                    >> $LOG_FILE
    fi

    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
else
    print "Skipped UDB Rebatable NDC counts due to previous error."            >> $LOG_FILE
fi

print " "                                                                      >> $LOG_FILE
print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

if [[ $RETCODE = 0 ]]; then 
    #-------------------------------------------------------------------------#
    # GPO Rebatable NDC Load into Oracle
    # The previous step built an INSERT SQL file that can be run from the 
    #   Oracle client to insert rows into the 
    #   DMA_RBATE2.S_GDX_DRUG_FOR_FRMLY_EXP table.
    #-------------------------------------------------------------------------#
    
    print "Begin Oracle Insert of GPO Rebatable NDCs."                         >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    #-------------------------------------------------------------------------#
    # Oracle userid/password
    #-------------------------------------------------------------------------#

    ORACLE_DB_USER_PASSWORD=`cat $SCRIPT_PATH/ora_user.fil`
 
#Build the top of the Oracle Insert file
#CANNOT INDENT DOWN TO EOF LINE
cat > $ORA_SQL_FILE << EOF
set TERMOUT OFF
whenever sqlerror exit 1
spool $ORA_OUTPUT_MSG_FILE
delete from $ORA_SCHEMA_OWNER.s_gdx_drug_for_frmly_exp;
commit;

set LINESIZE 800
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP off
set verify off
set trimspool on
EOF

    # Now Append the INSERT statements that were built in the previous step.
    cat $GPO_RBATABLE_NDC_DATA >> $ORA_SQL_FILE

    # Now add a COMMIT and then get the counts of rows from the table. 
    #   Use the counts from the spool file to compare to the number of rows extracted.
    print " "                                                                  >> $ORA_SQL_FILE
    print "commit; "                                                           >> $ORA_SQL_FILE
    print "spool off "                                                         >> $ORA_SQL_FILE
    print "spool "$GPO_RBATABLE_NDC_INS_CNTS                                   >> $ORA_SQL_FILE
    print "select count(*) from $ORA_SCHEMA_OWNER.s_gdx_drug_for_frmly_exp; "  >> $ORA_SQL_FILE
    print "quit "                                                              >> $ORA_SQL_FILE

    $ORACLE_HOME/sqlplus -s $ORACLE_DB_USER_PASSWORD @$ORA_SQL_FILE

    RETCODE=$?

    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Completed Oracle INSERT of GPO Rebatable NDCs"                      >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        print "Failure in Oracle insert of data "                              >> $LOG_FILE
        print "Oracle error is "                                               >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        tail -20 $ORA_OUTPUT_MSG_FILE                                          >> $LOG_FILE
        # Must have something in the next file to tail.  If abend occurs in DELETE or INSERT
        #  then the file would not have been created and tail will abend, but must have 
        #  this file in case SELECT COUNT abends.
        print " "                                                              >> $GPO_RBATABLE_NDC_INS_CNTS
        tail -20 $GPO_RBATABLE_NDC_INS_CNTS                                    >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Script will now abend."                                         >> $LOG_FILE
    else
        # Show the output results from the delete in the log.    
        cat  $ORA_OUTPUT_MSG_FILE                                              >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Successfull DELETE of GPO Rebatable NDC data."                  >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Successfull INSERT of GPO Rebatable NDC data."                  >> $LOG_FILE

        read INSERT_REC_CNT < $GPO_RBATABLE_NDC_INS_CNTS
        #INSERT_REC_CNT=$(< $GPO_RBATABLE_NDC_INS_CNTS)

        print " "                                                              >> $LOG_FILE
        print "The number of rows inserted was "$INSERT_REC_CNT                >> $LOG_FILE
        print " "                                                              >> $LOG_FILE

        if [[ $EXTRACT_REC_CNT = $INSERT_REC_CNT ]]; then
            print "The number of rows extracted "\($EXTRACT_REC_CNT\)" equals" >> $LOG_FILE
            print "  the number of rows INSERTED into Oracle"                  >> $LOG_FILE
            print "  "\($INSERT_REC_CNT\)"."                                   >> $LOG_FILE
            print "LOAD VALIDATED, script will continue"                       >> $LOG_FILE
        else
            print "The number of rows extracted "\($EXTRACT_REC_CNT\)" DOES "  >> $LOG_FILE
            print "  NOT MATCH the number of rows inserted via the IMPORT"     >> $LOG_FILE
            print "   "\($INSERT_REC_CNT\)"."                                  >> $LOG_FILE
            print "LOAD MISMATCH.  Script will now abend."                     >> $LOG_FILE
            if [[ $RETCODE = 0 ]]; then
                RETCODE=1
            fi
        fi
    fi

    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
else
    print "Skipped Oracle INSERT due to previous error."                       >> $LOG_FILE
fi

print " "                                                                      >> $LOG_FILE
print "=================================================================="     >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

if [[ $RETCODE = 0 ]]; then
    #-------------------------------------------------------------------------#
    # FTP Trigger file to REBDOM1 box in order to allow the GPO Formulary
    #   Expansion process to continue.
    #   Use of the FTP Validation is not necessary as this is not transferring
    #   data, only a trigger to run a Maestro job.
    #-------------------------------------------------------------------------#

    print "Starting the FTP trigger to continue with the Formulary Expansion"  >> $LOG_FILE
    print "  Maestro schedule."                                                >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print `date +"%D %r %Z"`                                                   >> $MAESTRO_OUT_TRG_FILE
    print " "                                                                  >> $MAESTRO_OUT_TRG_FILE
    print "This trigger file is being sent from "                              >> $MAESTRO_OUT_TRG_FILE
    print "  "$SCRIPTNAME" on the "$REGION                                     >> $MAESTRO_OUT_TRG_FILE
    print "  GDX box.  This trigger file does not accompany a data file,"      >> $MAESTRO_OUT_TRG_FILE
    print "  rather it is only intended to trigger the Formulary Expansion"    >> $MAESTRO_OUT_TRG_FILE
    print "  process to continue running.  The GPO Rebatable NDCs have been"   >> $MAESTRO_OUT_TRG_FILE
    print "  successfully extracted from GDX and inserted into the "           >> $MAESTRO_OUT_TRG_FILE
    print "  DMA_RBATE2.S_GDX_DRUG_FOR_FRMLY_EXP table."                       >> $MAESTRO_OUT_TRG_FILE
    print " "                                                                  >> $MAESTRO_OUT_TRG_FILE
    
    print 'cd '$REBDOM1_INPUT_DIR                                              >> $FTP_CGD_FILE
    # tHE {FILE##/*/} trims off the current directory from the variable.
    print 'put '$MAESTRO_OUT_TRG_FILE ${MAESTRO_OUT_TRG_FILE##/*/} ' (replace' >> $FTP_CGD_FILE
    print 'quit'                                                               >> $FTP_CGD_FILE
   
    ftp -i $FTP_IP < $FTP_CGD_FILE                                             >> $LOG_FILE

    RETCODE=$?
    
    print " "                                                                  >> $LOG_FILE
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then 
        print "Error in FTP Maestro trigger to REBDOM1. "                      >> $LOG_FILE
        print "Return Code = "$RETCODE                                         >> $LOG_FILE
    else
        print "Successfully completed FTP."                                    >> $LOG_FILE
    fi
    print " "                                                                  >> $LOG_FILE
else
    print "Skipped FTP of trigger file to REBDOM1 due to previous error."      >> $LOG_FILE
fi

print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#
 
if [[ $RETCODE != 0 ]]; then
   EMAILPARM4="  "
   EMAILPARM5="  "
   
   . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh
   cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

rm -f $UDB_SQL_FILE
rm -f $ORA_SQL_FILE
rm -f $GPO_RBATABLE_NDC_INS_CNTS
rm -f $GPO_RBATABLE_NDC_EXT_CNTS 
rm -f $ORA_OUTPUT_MSG_FILE
rm -f $FTP_CGD_FILE
rm -f $MAESTRO_OUT_TRG_FILE
# Only remove this file after successful completion
rm -f $MAESTRO_IN_TRG_FILE

print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE


