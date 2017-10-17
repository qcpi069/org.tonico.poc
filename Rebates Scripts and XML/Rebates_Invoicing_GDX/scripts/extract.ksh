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
FILE_BASE="GDX_"$SCHEDULE"_"$JOB"_Oracle_clm_extract_test"
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
GPO_RBATE_ID_DATA=$OUTPUT_PATH/$FILE_BASE"_gpo_clms2.dat"

rm -f $LOG_FILE
rm -f $ORA_SQL_FILE
rm -f $UDB_SQL_FILE
rm -f $UDB_MSG_FILE
rm -f $UDB_OUTPUT_MSG_FILE
rm -f $UDB_IMPORT_MSG_FILE
rm -f $SQL_PIPE_FILE

#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the script to load the TCLNT_MODEL table"                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

print "=================================================================="     >> $LOG_FILE

if [[ $RETCODE = 0 ]]; then 
    #-------------------------------------------------------------------------#
    # Rebate ID Extract
    # Set up the Pipe file, then build and EXEC the new SQL.               
    # Get the record count from the input for validation of rows
    #-------------------------------------------------------------------------#
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Begin building Oracle SQL file for CLAIM Extract TEST"           >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    #-------------------------------------------------------------------------#
    # Oracle userid/password
    #-------------------------------------------------------------------------#

    ORACLE_DB_USER_PASSWORD=`cat $SCRIPT_PATH/ora_user.fil`

    #-------------------------------------------------------------------------#
    # Create Oracle SQL file
    #-------------------------------------------------------------------------#


#original - working
#    rm -f $SQL_PIPE_FILE
#    mkfifo $SQL_PIPE_FILE
#    dd if=$SQL_PIPE_FILE of=$GPO_RBATE_ID_DATA bs=100k &

#CANNOT INDENT DOWN TO EOF LINE
#cat > $ORA_SQL_FILE << EOF
#set LINESIZE 700
#set trimspool on
#set arraysize 100
#set TERMOUT OFF
#set PAGESIZE 0
#set NEWPAGE 0
#set SPACE 0
#set ECHO OFF
#set FEEDBACK OFF
#set HEADING OFF 
#set WRAP off
#set serveroutput off
#set verify off
#whenever sqlerror exit 1
#set timing off
#spool $SQL_PIPE_FILE
#alter session enable parallel dml;




#copied from KC_2300J
    rm -f $SQL_PIPE_FILE
    mkfifo $SQL_PIPE_FILE
    dd if=$SQL_PIPE_FILE of=$GPO_RBATE_ID_DATA bs=100k &
    #{
    #   print "starting pipe copy....."
    #   #cat < $SQL_PIPE_FILE > $OUTPUT_PATH/$SQL_DATA_FILE
    #   dd if=$SQL_PIPE_FILE of=$OUTPUT_PATH/$SQL_DATA_FILE bs=100k 
    #   _rc=$?
    #   print "ending pipe copy [$_rc] ....."
    #   exit $_rc
    #} &

    cat > $ORA_SQL_FILE <<-EOF
        set LINESIZE 700
        set trimspool on
        set arraysize 100
        set TERMOUT OFF
        set PAGESIZE 0
        set NEWPAGE 0
        set SPACE 0
        set ECHO OFF
        set FEEDBACK OFF
        set HEADING OFF 
        set WRAP off
        set serveroutput off
        set verify off
        whenever sqlerror exit 1
        set timing off
        SPOOL $SQL_PIPE_FILE
        alter session enable parallel dml;
    EOF


select /*+
        ordered
        full(mf)
        full(scrc)
        full(vp)
        use_hash(scrc)
        use_hash(vp.t_phmcy)
        use_hash(vcs)
        no_expand
        driving_site(scrc)
        swap_join_inputs(vp.t_phmcy) */
        scrc.claim_gid
       || '|'
       || scrc.extnl_src_code
       || '|'
       || DECODE (scrc.extnl_src_code,
                  'RECAP', 'INT',
                  'RXC', 'INT',
                  'QLC', 'INT',
                  'EXT'
                 )
       || '|'
       || NVL (vcs.clm_lvl_1_id, scrc.extnl_claim_id)
       || '|'
       || vcs.clm_lvl_2_id
       || '|'
       || vcs.clm_lvl_3_id
       || '|'
       || scrc.nabp_code
       || '|'
       || scrc.dspnd_date
       || '|'
       || scrc.rx_nbr
       || '|'
       || scrc.new_refil_code
       || '|'
       || scrc.batch_date
       || '|'
       || scrc.ndc_code
       || '|'
       || NVL (vcs.nhu_typ_cd, 1)
       || '|'
       || NVL (vcs.multi_ingred_in, 0)
       || '|'
       || NVL (vcs.genc_avail_in, 0)
       || '|'
       || DECODE (vcs.gnrc_ind, 1, 0, 1)
       || '|'
       || vcs.calc_brnd_cd
       || '|'
       || scrc.unit_qty
       || '|'
       || scrc.days_sply
       || '|'
       || DECODE (scrc.mail_order_code, '1', '2', '3')
       || '|'
       || vcs.daw_typ_cd
       || '|'
       || scrc.claim_type
       || '|'
       || vcs.awp_unit_cst
       || '|'
       || scrc.cntrc_fee_paid
       || '|'
       || scrc.ingrd_cst
       || '|'
       || scrc.amt_paid
       || '|'
       || scrc.amt_copay
       || '|'
       || scrc.amt_copay
       || '|'
       || vcs.copay_src_code
       || '|'
       || vcs.prctr_zip_cd
       || '|'
       || vp.addr_zip_code
       || '|'
       || vcs.prctr_dea_nb
       || '|'
       || vcs.prctr_gid
       || '|'
       || vcs.pb_id
       || '|'
       || mf.drug_list_extnl_type
       || '|'
       || scrc.frmly_id
       || '|'
       || vcs.frmly_in
       || '|'
       || vcs.prim_secd_cov_cd
       || '|'
       || vcs.incntv_typ_cd
       || '|'
       || vcs.typ_fil_cd
       || '|'
       || vcs.clt_plan_typ_cd
       || '|'
       || vcs.clt_plan_id_tx
       || '|'
       || vcs.clt_plan_grp_id
       || '|'
       || scrc.rbate_id
       || '|'
       || 'G'
       || '|'
       || scrc.extnl_lvl_id1
       || '|'
       || DECODE (scrc.extnl_src_code,
                  'QLC', TO_CHAR (vcs.clt_plan_grp_id),
                  scrc.extnl_lvl_id2
                 )
       || '|'
       || scrc.extnl_lvl_id3
       || '|'
       || scrc.extnl_lvl_id4
       || '|'
       || scrc.extnl_lvl_id5
       || '|'
       || scrc.feed_id
       || '|'
       || scrc.mbr_gid
       || '|'
       || scrc.prior_athzn_flag
       || '|'
       || scrc.lcm_code
       || '|'
       || vcs.pmcy_ther_pref_cd
       || '|'
       || vcs.dsg_per_day_qty
       || '|'
       || vcs.unit_per_dose_qty
       || '|'
       || scrc.batch_date
       || '|'
       || vcs.drug_prc_src_cd
       || '|'
       || vcs.drug_prc_typ_cd
       || '|'
       || SYSDATE
FROM dwcorp.mv_frmly mf,
       dma_rbate2.s_claim_rbate_cycle scrc,
       dma_rbate2.v_phmcy vp,
       dma_rbate2.v_combined_scr vcs
 WHERE scrc.cycle_gid = 200544
   AND scrc.batch_date BETWEEN TO_DATE ('2005-10-01', 'YYYY-MM-DD')
                           AND TO_DATE ('2005-10-31', 'YYYY-MM-DD')
   AND scrc.claim_status_flag IN (0, 24, 26)
   AND scrc.batch_date = vcs.batch_date
   AND scrc.claim_gid = vcs.claim_gid
   AND scrc.frmly_gid = mf.drug_list_gid
   AND scrc.phmcy_gid = vp.phmcy_gid
   ;
quit;

EOF

    cat $ORA_SQL_FILE                                                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Finished building Oracel SQL file, start extracting data "          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

START_DATE=`date +"%D %r %Z"`

    $ORACLE_HOME/sqlplus -s $ORACLE_DB_USER_PASSWORD @$ORA_SQL_FILE

    RETCODE=$?

END_DATE=`date +"%D %r %Z"`

    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Completed extract of GPO clms"                                >> $LOG_FILE
    print "Started at $START_DATE and completed at $END_DATE" >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Start-$START_DATE"                                                  >> $LOG_FILE
    print "End  -$END_DATE"                                                    >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

fi

#rm -f $ORA_SQL_FILE
#rm -f $SQL_PIPE_FILE

cp -f $LOG_FILE $LOG_FILE`date +'%Y%j%H%M'`


print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE

exit $RETCODE

