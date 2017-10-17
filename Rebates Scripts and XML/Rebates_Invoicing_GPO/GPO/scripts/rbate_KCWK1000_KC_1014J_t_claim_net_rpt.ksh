#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCWK1000_KC_1014J_t_claim_net_rpt.ksh   
# Title         : Pre-gather t_claim net report table.
#
# Description   : This report is the net counts that we expect in SCR from the dwcorp.t_claim table.  
# Maestro Job   : KC_1014J
#
# Parameters    : N/A
#         
# Input         : This script gets the cycle_gid from the pre-gather report control file 
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-15-09    ax04566    Added RxAmrica Claims
# 07-15-08    ur24xdp    Removed query against V_CLAIM_PHCA.  Since this view
#                        has been dropped in EDW.
# 12-22-07    is45401    Added TABLE_SOURCE column to the SQLs to identify
#                        what table the claims are being counted from.
# 09-15-05    Castillo   Modifications for Rebates Integration Phase 2
# 10-04-04    N. Tucker   Added Union all to bring in the Arcadian Claims.
# 01-05-2004  N. Tucker   Initial Creation.
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh
 
# for testing
#. /staging/apps/rebates/prod/scripts/rebates_env.ksh

# Set variables based on region
if [[ "$REGION" = "prod" ]]; then
        if [[ "$QA_REGION" = "true" ]]; then
                GDX_HOST=r07prd02
                REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
        else
                GDX_HOST=r07prd02
                REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
        fi
else
        GDX_HOST=r07tst07
        GDX_REMOTE_DIR=/GDX/test/input
        REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/test
fi

export SCHEDULE="KCWK1000"
export JOB="KC_1014J"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_t_claim_net_rpt"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export SQL_FILE=$FILE_BASE".sql"
export SQL_FILE_DATE_CNTRL=$FILE_BASE"_date_cntrl.sql"
export DAT_FILE=$FILE_BASE".dat"
export FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
export CTRL_FILE="rbate_pre_gather_rpt_control_file_init.dat"
export FTP_NT_IP=AZSHISP00

# Use this alias to print out the filename and line number an error occurred on
alias print_err='print "[$SCRIPTNAME:$LINENO]"'

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$FTP_CMDS

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#

print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE
print "Starting " $SCRIPTNAME                                                   >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# read the cntl file and execute sql for each cycle_gid 
#-------------------------------------------------------------------------#
READ_VARS='
    CYCLE_GID
    CYCLE_START_DATE
    CYCLE_END_DATE
    JUNK
'
while read $READ_VARS; do

    print " "                                                        >> $OUTPUT_PATH/$LOG_FILE
    print "Control file record read from " $OUTPUT_PATH/$CTRL_FILE   >> $OUTPUT_PATH/$LOG_FILE
    print `date`                                                     >> $OUTPUT_PATH/$LOG_FILE
    print " "                                                        >> $OUTPUT_PATH/$LOG_FILE
    print "Values are:"                                              >> $OUTPUT_PATH/$LOG_FILE
    print "CYCLE_GID = " $CYCLE_GID                                  >> $OUTPUT_PATH/$LOG_FILE
    print "CYCLE_START_DATE = " $CYCLE_START_DATE                    >> $OUTPUT_PATH/$LOG_FILE
    print "CYCLE_END_DATE = " $CYCLE_END_DATE                        >> $OUTPUT_PATH/$LOG_FILE
    
    DAT_FILE=$FILE_BASE'_'$CYCLE_GID'.dat'
    FILE_OUT=$DAT_FILE
    
    rm -f $INPUT_PATH/$SQL_FILE
    rm -f $OUTPUT_PATH/$DAT_FILE

    print "Output file for " $CYCLE_GID " is " $OUTPUT_PATH/$DAT_FILE  >> $OUTPUT_PATH/$LOG_FILE

    cat > $INPUT_PATH/$SQL_FILE <<- EOF
        SET LINESIZE 80
        SET TERMOUT OFF
        SET PAGESIZE 0
        SET NEWPAGE 0
        SET SPACE 0
        SET ECHO OFF
        SET FEEDBACK OFF
        SET HEADING OFF
        SET WRAP OFF
        set verify off
        whenever sqlerror exit 1
        SPOOL $OUTPUT_PATH/$DAT_FILE
        alter session enable parallel dml
        
        SELECT /*+ full(b) parallel(b,6) */ 
             A1.table_source
            ,','
            ,NVL(b.feed_id,'_NVL_')
            ,','
            ,NVL(b.extnl_src_code,'_NVL_')   
            ,','
            ,to_char(A1.report_date,'Month') 
            ,','
            ,count(A1.claim_gid)
        FROM DMA_RBATE2.V_BATCH@dwcorp_reb b, (
            SELECT /*+ full(tc) parallel(tc,12) */
                 'T_CLAIM' table_source
                ,claim_gid
                ,batch_gid
                ,claim_type
                ,batch_date AS report_date
            FROM DWCORP.T_CLAIM@dwcorp_reb tc
            WHERE
                (claim_type IN (1, -1) OR claim_type IS NULL)
                AND batch_date BETWEEN TO_DATE('$CYCLE_START_DATE','MMDDYYYY')
                    AND TO_DATE('$CYCLE_END_DATE','MMDDYYYY')
            UNION ALL
            SELECT /*+ full(vcmx) parallel(vcmx,12) */
                 'T_CLAIM_QL' table_source
                ,claim_gid
                ,batch_gid
                ,claim_typ_nb
                ,ql_blg_end_dt AS report_date
            FROM DWCORP.T_CLAIM_QL@dwcorp_reb vcmx
            WHERE 
                (claim_typ_nb in (1, -1) OR claim_typ_nb is NULL)
                AND ql_blg_end_dt BETWEEN TO_DATE('$CYCLE_START_DATE','MMDDYYYY')
                    AND TO_DATE('$CYCLE_END_DATE','MMDDYYYY')
                AND batch_dt BETWEEN ADD_MONTHS(TO_DATE('$CYCLE_START_DATE','MMDDYYYY'),-1)
                    AND ADD_MONTHS(TO_DATE('$CYCLE_END_DATE','MMDDYYYY'),1)
            UNION ALL
            SELECT /*+ full(mord) parallel(mord,12) */
                 'T_CLAIM_MORD_PHCA' table_source
                ,claim_gid
                ,batch_gid
                ,claim_type
                ,batch_date AS report_date
            FROM DWCORP.V_CLAIM_MORD_PHCA@dwcorp_reb mord
            WHERE
                (claim_type IN (1, -1) OR claim_type IS NULL)
                AND batch_date BETWEEN TO_DATE('$CYCLE_START_DATE','MMDDYYYY')
                    AND TO_DATE('$CYCLE_END_DATE','MMDDYYYY')
            UNION ALL
            SELECT /*+ full(tcr) parallel(tcr,12) */
                   'T_CLAIM_RXAM' table_source
                  ,claim_gid
                  ,batch_gid
                  ,claim_type
                  ,batch_dt AS report_date
             FROM DWCORP.T_CLAIM_RXAM@dwcorp_reb tcr 
            WHERE
                  (claim_type IN (1, -1) OR claim_type IS NULL)
              AND batch_dt BETWEEN TO_DATE('$CYCLE_START_DATE','MMDDYYYY')
                               AND TO_DATE('$CYCLE_END_DATE','MMDDYYYY')
        ) A1
        WHERE
            A1.batch_gid = b.batch_gid(+)
            AND (b.extnl_src_code IS NULL OR b.extnl_src_code != 'NOREB')
            AND A1.claim_type != 0
        GROUP BY
             a1.table_source
            ,NVL(b.feed_id,'_NVL_')
            ,NVL(b.extnl_src_code,'_NVL_')
            ,TO_CHAR(A1.report_date,'Month')
        ORDER BY a1.table_source,NVL(b.feed_id,'_NVL_');
        
        quit; 
         
EOF

    $ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE  >> $OUTPUT_PATH/$LOG_FILE
    RETCODE=$?

    print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
    print "SQLPlus complete for " $CYCLE_GID                                     >> $OUTPUT_PATH/$LOG_FILE
    print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
    print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE

    #-------------------------------------------------------------------------#
    # Check for good return from sqlplus.                  
    #-------------------------------------------------------------------------#

    if [[ $RETCODE != 0 ]]; then
        print_err "SQLPlus Error ($RETCODE)"                                      >> $OUTPUT_PATH/$LOG_FILE
        print "                                                                 " >> $OUTPUT_PATH/$LOG_FILE
        print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
        print "  Error Executing " $SCRIPT_PATH/$SCRIPTNAME                       >> $OUTPUT_PATH/$LOG_FILE
        print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
        print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
        
        cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
        exit $RETCODE
    fi

    #-------------------------------------------------------------------------#
    # FTP the report to an NT server                  
    #-------------------------------------------------------------------------#

    print 'Creating FTP command for PUT ' $OUTPUT_PATH/$FILE_OUT ' to ' $FTP_NT_IP >> $OUTPUT_PATH/$LOG_FILE
    print 'cd /'$REBATES_DIR                                                       >> $OUTPUT_PATH/$FTP_CMDS
    print 'put ' $OUTPUT_PATH/$FILE_OUT $FILE_OUT ' (replace'                      >> $OUTPUT_PATH/$FTP_CMDS

done < $OUTPUT_PATH/$CTRL_FILE

print 'quit'                                                                    >> $OUTPUT_PATH/$FTP_CMDS
print " "                                                                       >> $OUTPUT_PATH/$LOG_FILE
print "....Executing FTP  ...."                                                 >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
ftp -v -i $FTP_NT_IP < $OUTPUT_PATH/$FTP_CMDS                                   >> $OUTPUT_PATH/$LOG_FILE
RETCODE=$?
print ".... FTP complete   ...."                                                >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE


if [[ $RETCODE != 0 ]]; then
    print_err "Error ($RETCODE)"                                                 >> $OUTPUT_PATH/$LOG_FILE
    print "                                                                 "    >> $OUTPUT_PATH/$LOG_FILE
    print "===================== J O B  A B E N D E D ======================"    >> $OUTPUT_PATH/$LOG_FILE
    print "  Error in FTP of " $OUTPUT_PATH/$FTP_CMDS                            >> $OUTPUT_PATH/$LOG_FILE
    print "  Look in " $OUTPUT_PATH/$LOG_FILE                                    >> $OUTPUT_PATH/$LOG_FILE
    print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
    
    cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
    exit $RETCODE
fi

#-------------------------------------------------------------------------#
# Copy the log file over and end the job                  
#-------------------------------------------------------------------------#

print " "                                                                       >> $OUTPUT_PATH/$LOG_FILE
print "....Completed executing " $SCRIPT_PATH/$SCRIPTNAME " ...."               >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`

exit $RETCODE

