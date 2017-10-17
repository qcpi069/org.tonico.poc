#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIOR4500_RI_4500J_APC_rbated_clm_extract.ksh   
# Title         : APC file processing.
#
# Description   : Extracts APC records into the 323 byte format 
#                 for future split into 10,000,000 record files,
#                 zip and transmit to MVS
# Maestro Job   : RIOR4500 RI_4500J
#
# Parameters    : CYCLE_GID
#
# Output        : Log file as $OUTPUT_PATH/rbate_RIOR4500_RI_4500J_APC_rbated_clm_extract.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date        ID      PARTE #  Description
# ---------  ---------  -------  ------------------------------------------#
# 07-10-2007  is23301		 PSP,SPECS,etc.
# 03-31-2006  is00084		 Added the ORDER BY clause while querying data from
#                                TMP_APC_EXTRACT_TABLE to get the data ordered by CLAIM_GID
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
# 03/10/2005  IS23301   6002298  Modify set linesize statement to 333 from the 323 to 
#                                     accommodate the larger extract record. .
# 01/17/2005  IS00241   5999357  Change the where clause in the select statement
#                                when retrieving the cycle gid. Change the trigger 
#                                file name in the FTP_MVS_RBATED_CLM_TRIGGER 
#                                variable from .TRG to .TRIGGER.
#                                Change the trigger file name in the  
#                                FTP_MVS_SCL_TRIGGER variable from 
#                                KSZ4900.APC.TRIGGER to 
#                                KSZ4900.KS15APC.SCL.TRIGGER.
# 10/14/2004  is23301            Added tmp_apc_extract_table process.
# 06-30-04    IS45401   5994785  Added logic changes for SOX project;
#                                Replaced P status script with 
#                                TMP_QTR_RESULTS refresh;  added logic
#                                to get the CYCLE_GID if not passed in;
#                                replaced view to get claims from with
#                                V_APC_CLMS;
# 02/23/2004  is00241            Remove all export parms except for the variables
#                                used by script rbate_email_base.ksh.
#                                Change the CYR symbolic  to CQTRYY to match the
#                                KSZ0001C AND KSZ0000C control cards on the MVS.
#                                Add logic to create a trigger file and FTP the
#                                trigger file along with the symbolic control card.
#                                Move the FTP logic for the APC Rebated Detail 
#                                Trigger file to the end of the script.
# 05-16-2003  is45401            Made modifications to allow only Rebated claims
#                                to come through this script, and pass new parms
#                                to the next script in the process.  Renamed from
#                                the original rbate_APC_file_extract.ksh.
# 10-16-2002  K. Gries           Initial Creation.
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
  if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
    export ALTER_EMAIL_ADDRESS='richard.hutchison@Caremark.com'
    MVS_FTP_PREFIX='TEST.X'
    SCHEMA_OWNER="dma_rbate2"
  else
    # Running in Prod region
    export ALTER_EMAIL_ADDRESS=''
    MVS_FTP_PREFIX='PCS.P'
    SCHEMA_OWNER="dma_rbate2"
  fi
else
  # Running in Development region
  export ALTER_EMAIL_ADDRESS='nick.tucker@Caremark.com'
  MVS_FTP_PREFIX='TEST.D'
  SCHEMA_OWNER="dma_rbate2"
fi

RETCODE=0
APCType='REBATED'
FTP_IP='204.99.4.30'
SCHEDULE="RIOR4500"
JOB="RI_4500J"
APC_OUTPUT_DIR=$OUTPUT_PATH/apc
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_APC_rbated_clm_extract"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
LOG_ARCH=$FILE_BASE".log"
SQL_FILE=$APC_OUTPUT_DIR/$FILE_BASE".sql"
SQL_PIPE_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_pipe.lst"
SQL_LOG_FILE1=$APC_OUTPUT_DIR/$FILE_BASE"SQLLOG1.sql"
SQL_LOG_FILE2=$APC_OUTPUT_DIR/$FILE_BASE"SQLLOG2.sql"
DAT_FILE_OUTPUT=$APC_OUTPUT_DIR/$FILE_BASE".dat"
MVS_FTP_COM_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_ftpcommands.txt" 
EMAIL_TEXT_DATA_CENTER=$FILE_BASE"_email.txt"  
FTP_MVS_CNTLCARD_FILE=" '"$MVS_FTP_PREFIX".TM30D011.CNTLCARD(KSZ4900C)'"
FTP_MVS_SCL_TRIGGER=" '"$MVS_FTP_PREFIX".KSZ4900.KS15APC.SCL.TRIGGER'"
MVS_CNTLCARD_DAT=$APC_OUTPUT_DIR"/rbate_APC_"$APCType"_file_KSZ4900C.dat"
MVS_SCL_TRG=$APC_OUTPUT_DIR"/rbate_APC_extract_scl.trg"
FTP_MVS_RBATED_CLM_TRIGGER=" '"$MVS_FTP_PREFIX".KSZ4920J.APCFINAL.REBATED.DETL.TRIG'"
MVS_RBATED_CLM_TRIGGER=$APC_OUTPUT_DIR"/rbate_APC_rbated_clm.trg"

#added for SOX
CYCLE_GID_DAT=$APC_OUTPUT_DIR/$FILE_BASE"_closed_cycle_gid.dat"
CYCLE_GID_SQL=$APC_OUTPUT_DIR/$FILE_BASE"_closed_cycle_gid.sql"
TMP_QTR_RESULTS_CALL="rbate_"$SCHEDULE"_bld_tmp_qtr_results"
TMP_QTR_RESULTS_CALL_SCRIPT=$TMP_QTR_RESULTS_CALL".ksh"
TMP_QTR_RESULTS_CALL_SCRIPT_LOG=$TMP_QTR_RESULTS_CALL".log"
LCM_RPT_CALL="rbate_create_LCM_report"
LCM_RPT_CALL_SCRIPT=$LCM_RPT_CALL".ksh"
LCM_RPT_CALL_SCRIPT_LOG=$LCM_RPT_CALL".log"

rm -f $LOG_FILE
rm -f $DAT_FILE_OUTPUT
rm -f $MVS_CNTLCARD_DAT
rm -f $MVS_SCL_TRG
rm -f $MVS_FTP_COM_FILE
rm -f $SQL_PIPE
rm -f $FTP_MVS_RBATED_CLM_TRIGGER
rm -f $MVS_RBATED_CLM_TRIGGER
rm -f $CYCLE_GID_DAT
rm -f $CYCLE_GID_SQL

#Clean up previous runs trigger files - must do to allow reruns of the split job.  See Sleep in split job.
# NOTE that the Data Mart Trigger file name is used in the rbate_APC_extract_split.ksh, 
# the rbate_APC_extract_zip.ksh and the rbate_RIOR4500_RI_4504J_APC_submttd_clm_extract.ksh 
# scripts, so if the name changes, it must change in all four scripts.

rm -f $APC_OUTPUT_DIR/rbate_APC_extract_zip_DMART*.trg

print "Starting "$SCRIPTNAME                                                   >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
# PKGEXEC is the full SQL command to be executed
#-------------------------------------------------------------------------#

CYCLE_GID=$1
print ' '                                                                      >> $LOG_FILE

#added for SOX
if [[ $# -lt 1 ]]; then
    print "Cycle gid was not passed in, get CYCLE_GID from Oracle "            >> $LOG_FILE
    print "  where RBATE_CYCLE_STATUS = 'C'"                                   >> $LOG_FILE 
else
    print "Cycle gid was passed in, get CYCLE_GID from Oracle "                >> $LOG_FILE
    print "  where RBATE_CYCLE_STATUS = 'C' "                                  >> $LOG_FILE 
    print "  and use AND_CLAUSE variable"                                      >> $LOG_FILE 
    AND_CLAUSE="    AND rbate_cycle_gid = $CYCLE_GID" 
    print "  AND_CLAUSE variable is " $AND_CLAUSE                              >> $LOG_FILE 
fi    

    db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

### CANNOT INDENT THIS, DOWN TO EOF!
cat > $CYCLE_GID_SQL << EOF
set LINESIZE 200
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP off
set verify off
whenever sqlerror exit 1
SPOOL $CYCLE_GID_DAT
SELECT MAX(rbate_cycle_gid)
      ,' '
      ,TO_CHAR(cycle_start_date,'MM-DD-YYYY')
      ,' '
      ,TO_CHAR(cycle_end_date,'MM-DD-YYYY')
      ,' '
      ,substrb(MAX(rbate_cycle_gid),1,4)||decode(substrb(MAX(rbate_cycle_gid),6,1),1,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1)
                                                                                  ,2,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1)
                                                                                  ,3,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1)
                                                                                  ,4,     (((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1))
      ,' '
      ,substrb(MAX(rbate_cycle_gid),1,4)||decode(substrb(MAX(rbate_cycle_gid),6,1),1,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2)
                                                                                  ,2,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2)
                                                                                  ,3,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2)
                                                                                  ,4,     (((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2))     
      ,' '
      ,substrb(MAX(rbate_cycle_gid),1,4)||decode(substrb(MAX(rbate_cycle_gid),6,1),1,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3)
                                                                                  ,2,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3)
                                                                                  ,3,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3)
                                                                                  ,4,     (((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3))     
    FROM dma_rbate2.t_rbate_cycle
    WHERE rbate_cycle_gid = (SELECT MAX(rbate_cycle_gid) 
                                   FROM dma_rbate2.t_rbate_cycle
                                  WHERE rbate_cycle_type_id = 2
                                AND   rbate_cycle_status = UPPER('C') $AND_CLAUSE)
    GROUP BY cycle_start_date, cycle_end_date
;    
quit;
EOF
 
    $ORACLE_HOME/bin/sqlplus -s $db_user_password @$CYCLE_GID_SQL

    RETCODE=$?
 
    #  Leave READ here even if error occurred, to show what was written out.
    FIRST_READ=1
    while read input_CYCLE_GID input_QTR_STRT_DT input_QTR_END_DT input_MTH1_GID input_MTH2_GID input_MTH3_GID; do
      if [[ $FIRST_READ != 1 ]]; then
        print "Finishing control file read" >>  $LOG_FILE
      else
        FIRST_READ=0
        print "Cycle Gid from Oracle is          >"$input_CYCLE_GID"<"         >> $LOG_FILE
        print "Quarter Start Date from Oracle is >"$input_QTR_STRT_DT"<"       >> $LOG_FILE
        print "Quarter End Date from  Oracle is  >"$input_QTR_END_DT"<"        >> $LOG_FILE
        print "Month 1 Cycle Gid from Oracle is  >"$input_MTH1_GID"<"          >> $LOG_FILE
        print "Month 2 Cycle Gid from Oracle is  >"$input_MTH2_GID"<"          >> $LOG_FILE
        print "Month 3 Cycle Gid from Oracle is  >"$input_MTH3_GID"<"          >> $LOG_FILE
        CYCLE_GID=$input_CYCLE_GID
        QTR_STRT_DT=$input_QTR_STRT_DT
        QTR_END_DT=$input_QTR_END_DT
        MTH1_GID=$input_MTH1_GID
        MTH2_GID=$input_MTH2_GID
        MTH3_GID=$input_MTH3_GID
      fi
    done < $CYCLE_GID_DAT

if [[ -z $CYCLE_GID || -z $QTR_STRT_DT || -z $QTR_END_DT || -z $MTH1_GID || -z $MTH2_GID || -z $MTH3_GID ]]; then
    RETCODE=1
    print " "                                                                  >> $LOG_FILE
    print `date`                                                               >> $LOG_FILE
    print "Script abending because no data returned from Oracle."              >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Cycle Gid from Oracle is          >"$CYCLE_GID"<"                   >> $LOG_FILE
    print "Quarter Start Date from Oracle is >"$QTR_STRT_DT"<"                 >> $LOG_FILE
    print "Quarter End Date from  Oracle is  >"$QTR_END_DT"<"                  >> $LOG_FILE
    print "Month 1 Cycle Gid from Oracle is  >"$MTH1_GID"<"                    >> $LOG_FILE
    print "Month 2 Cycle Gid from Oracle is  >"$MTH2_GID"<"                    >> $LOG_FILE
    print "Month 3 Cycle Gid from Oracle is  >"$MTH3_GID"<"                    >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
fi


if  [[ $RETCODE = 0 ]]; then
    print ' '                                                                  >> $LOG_FILE
    CUR_PARM="'CUR'"
    print "calling script "$TMP_QTR_RESULTS_CALL_SCRIPT  "GGGGGGGGGGGGGGMM"                      >> $LOG_FILE
    print "calling script "$TMP_QTR_RESULTS_CALL_SCRIPT  $CYCLE_GID $CUR_PARM                      >> $LOG_FILE
    print `date`                                                               >> $LOG_FILE

    # TMP_QTR_RESULTS refresh script accepts two input parms, BUT NOT PASSING PARM HERE.
    #    The 2nd parm is invoice number, ONE or CUR, and APC is always CUR for Current Version
    #    and the default in the Oracle package is CUR.
    CUR_PARM="'CUR'"
    
    . $SCRIPT_PATH/$TMP_QTR_RESULTS_CALL_SCRIPT $CYCLE_GID $CUR_PARM
    #. $SCRIPT_PATH/rbate_RIOR4500_bld_tmp_qtr_results.ksh  $CYCLE_GID 

    RETCODE=$?
    print ' '                                                                  >> $LOG_FILE
    if  [[ $RETCODE != 0 ]]; then
        print "===================== SCRIPT FAILED ==========================" >> $LOG_FILE
        print "script "$TMP_QTR_RESULTS_CALL_SCRIPT "Failed."                  >> $LOG_FILE
        print "Look in " $OUTPUT_PATH/$TMP_QTR_RESULTS_CALL_SCRIPT_LOG          >> $LOG_FILE
        print `date`                                                           >> $LOG_FILE
        print "==============================================================" >> $LOG_FILE
    else
        print "==============================================================" >> $LOG_FILE
        print "script "$TMP_QTR_RESULTS_CALL_SCRIPT "completed successfully."  >> $LOG_FILE
        print `date`                                                           >> $LOG_FILE
        print "==============================================================" >> $LOG_FILE
###### commented out as it was a temporary change that needed to be removed in 01-2006
######        . $SCRIPT_PATH/rbate_RIOR4500_RI_4500J_special_update_of_TQR_call.ksh  $QTR_STRT_DT $QTR_END_DT
        RETCODE=$?
        if [[ $RETCODE != 0 ]]; then
           print "===================== SCRIPT FAILED ==========================" >> $LOG_FILE
           print "script rbate_RIOR4500_RI_4500J_special_update_of_TQR_call.ksh  Failed."  >> $LOG_FILE
           print `date`                                                           >> $LOG_FILE
           print "==============================================================" >> $LOG_FILE
	else
           print "==============================================================" >> $LOG_FILE
           print "script rbate_RIOR4500_RI_4500J_special_update_of_TQR_call.ksh  completed successfully."  >> $LOG_FILE
           print `date`                                                           >> $LOG_FILE
           print "==============================================================" >> $LOG_FILE
        fi
    fi
    print ' '                                                                  >> $LOG_FILE
fi

if [[ $RETCODE = 0 ]]; then
    print "================================================================="  >> $LOG_FILE
    print "calling script "$LCM_RPT_CALL_SCRIPT                                >> $LOG_FILE
    print `date`                                                               >> $LOG_FILE
    print "================================================================="  >> $LOG_FILE

    . $SCRIPT_PATH/$LCM_RPT_CALL_SCRIPT $CYCLE_GID

    RETCODE=$?

    print ' '                                                                  >> $LOG_FILE
    if  [[ $RETCODE != 0 ]]; then
      print "==================== SCRIPT FAILED =============================" >> $LOG_FILE
      print "script "$LCM_RPT_CALL_SCRIPT" Failed, Return Code = "$RETCODE     >> $LOG_FILE
      print "Look in " $OUTPUT_PATH/$LCM_RPT_CALL_SCRIPT_LOG                   >> $LOG_FILE
      print "LCM reporting needs to rerun."                                    >> $LOG_FILE
      print "We are continuing with the APC extract."                          >> $LOG_FILE
      print "================================================================" >> $LOG_FILE
      RETCODE=0
    else
      print "================= SCRIPT COMPLETED SUCCESSFULLY ================" >> $LOG_FILE
      print "script "$LCM_RPT_CALL_SCRIPT" completed successfully."            >> $LOG_FILE
      print `date`                                                             >> $LOG_FILE
      print "================================================================" >> $LOG_FILE
    fi
    print ' '                                                                  >> $LOG_FILE
fi

if [[ $RETCODE = 0 ]]; then

    # Start FTP the KSZ4900C MVS Control Card to the MVS
    
    print $CYCLE_GID > awk_input.dat

    Rbate_Yr=`nawk 'BEGIN { getline ndate;
                        $1 = substr(ndate,3,2)
            print $1
                        exit
                      }' < awk_input.dat`

    Rbate_Qtr=`nawk 'BEGIN { getline ndate;
                        $1 = substr(ndate,5,2)
                        print $1
            exit
                      }' < awk_input.dat`

    if [ $Rbate_Qtr = '41' ]; then
        Rbate_Qtr='Q1'
    fi
    if [ $Rbate_Qtr = '42' ]; then
        Rbate_Qtr='Q2'
    fi
    if [ $Rbate_Qtr = '43' ]; then
        Rbate_Qtr='Q3'
    fi
    if [ $Rbate_Qtr = '44' ]; then
        Rbate_Qtr='Q4'
    fi
    
    print " " >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    print "FTPing the KSZ4900C MVS Control Card to the MVS. "  >> $LOG_FILE
    print "Parms used in the CNTLCARD - APCType " $APCType ","  >> $LOG_FILE
    print "Rbate_Yr = " $Rbate_Yr ", and Rbate_Qtr " $Rbate_Qtr "." >> $LOG_FILE
    print `date` >> $LOG_FILE

    print "//*  THIS CONTROL CARD FILE IS GENERATED FROM UNIX KORN SCRIPT "   >> $MVS_CNTLCARD_DAT
    print "//*  " $SCRIPTNAME    >> $MVS_CNTLCARD_DAT
    print "//*  ITS PURPOSE IS TO MAKE AVAILABLE THE PROPER SUBSTITUTION  "   >> $MVS_CNTLCARD_DAT
    print "//*  VARIABLES FOR NAMING THE APC FILE PROPERLY THAT HAS BEEN  "   >> $MVS_CNTLCARD_DAT
    print "//*  SENT UP FROM UNIX.                                        "   >> $MVS_CNTLCARD_DAT
    print "//*                                                            "   >> $MVS_CNTLCARD_DAT
    print "//   SET CQTRYY=""'"$Rbate_Yr"'" "             CURRENT YEAR"        >> $MVS_CNTLCARD_DAT
    print "//   SET CQTR=""'"$Rbate_Qtr"'" "            CURRENT QUARTER"      >> $MVS_CNTLCARD_DAT

    print "Control Card Built - " $MVS_CNTLCARD_DAT >>$LOG_FILE
    print "Trigger file for loading SCL KS15APC to the schedule."   >> $MVS_SCL_TRG
    print 'put ' $MVS_CNTLCARD_DAT " " $FTP_MVS_CNTLCARD_FILE ' (replace' >> $MVS_FTP_COM_FILE
    print 'put ' $MVS_SCL_TRG " " $FTP_MVS_SCL_TRIGGER ' (replace' >> $MVS_FTP_COM_FILE  
    print "=================================================================" >> $LOG_FILE
    print "quit" >> $MVS_FTP_COM_FILE
    
    print " " >> $LOG_FILE
    print "================== CONCATENATE FTP COMMANDS =========================" >> $LOG_FILE
    print "Start Concatenating FTP Commands " >> $LOG_FILE
    cat $MVS_FTP_COM_FILE >> $LOG_FILE
    print "End Concatenating FTP Commands " >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    #do not capture return code here, if cat to the log failed, do not end script.

    ftp -i  $FTP_IP < $MVS_FTP_COM_FILE >> $LOG_FILE

    RETCODE=$?
    
    if  [[ $RETCODE != 0 ]]; then
        print " " >> $LOG_FILE
        print "================= FTP COMMAND FAILED ============================" >> $LOG_FILE
        print "FTP of MVS Control Card FAILED." >> $LOG_FILE
        print `date` >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
    else
        print " " >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
        print "MVS Control Card ftp process complete "  >> $LOG_FILE
        print `date` >> $LOG_FILE
        # End FTP the KSZ4900C MVS Control Card to the MVS
        print "=================================================================" >> $LOG_FILE
    fi
fi

if [[ $RETCODE = 0 ]]; then
    #-------------------------------------------------------------------------#
    # Set parameters to use in PL/SQL call.
    #-------------------------------------------------------------------------#

    print "executing APC Extract SQL" >> $LOG_FILE
    print `date` >> $LOG_FILE

    #----------------------------------
    # Oracle userid/password
    #----------------------------------

    db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

    #-------------------------------------------------------------------------#
    # Remove the previous SQL, then build and EXEC the new SQL.               
    #                                                                         
    #-------------------------------------------------------------------------#

    export Table_Name="tmp_apc_extract_table"
    export Package_Name=$SCHEMA_OWNER".pk_cycle_util.truncate_table"
    PKGEXEC=$Package_Name\(\'$Table_Name\'\);

# The following statements can not be indented.

# Output spooled here must match the layout of the MVS Copybook KSZ4APCX

    rm -f $SQL_PIPE_FILE

    mkfifo $SQL_PIPE_FILE
    dd if=$SQL_PIPE_FILE of=$DAT_FILE_OUTPUT bs=100k &

cat > $SQL_FILE << EOF
set LINESIZE 527
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP off
set verify off
whenever sqlerror exit 1
alter session set optimizer_mode='first_rows';

spool $SQL_LOG_FILE1
EXEC $PKGEXEC; 

insert /*+ append parallel(a,8) full(a) */ into $SCHEMA_OWNER.tmp_apc_extract_table a
(formatted_data_row)
SELECT /*+ append parallel(b,8) full(b) */ 
    claim_lvl_1_id
   ||claim_lvl_2_id
   ||claim_lvl_3_id
   ||new_refil_code
   ||rx_nbr
   ||mail_order_code
   ||dspnd_date
   ||unit_qty
   ||days_sply
   ||ingrd_cst
   ||mbr_rbte_disc_amt
   ||prior_athzn_flag
   ||ndc_code
   ||extnl_src_code
   ||extnl_lvl_id1
   ||extnl_lvl_id2
   ||extnl_lvl_id3
   ||extnl_lvl_id4
   ||extnl_lvl_id5
   ||rbate_id
   ||frmly_id
   ||lcm_code
   ||copay_src_code
   ||insrd_id
   ||sfx_code
   ||nabp_code
   ||chn_nbr
   ||ppo_nbr
   ||pico_no
   ||cntrl_no
--   ||rbate_lvl_id
   ||bskt_name
   ||rbate_access
   ||rbate_mrkt_shr
   ||rbate_admin_fee
   ||awp_unit_cst
   ||excpt_stat
   ||excpt_code
   ||inv_gid
   ||qtr
   ||year_yy
   ||srx_drug_flg
   ||gnrc_ind
   ||user_field6_flag
   ||claim_type
--   ||apc_file_filler
   ||model_typ_cd
   ||rtmd_elig_cd
   ||rtmd_clnt_shr_amt
   ||rtmd_mbr_shr_amt
   ||rtmd_tot_shr_amt
   ||nhu_typ_cd
   ||medd_plan_typ_cd
   ||medd_cntrc_id
   ||medd_prtc_cd
   ||medd_drug_cd
   ||frmly_drug_stat_cd
   ||frmly_drug_tier_vl
   ||plan_tier_vl
   ||amt_paid
   ||cntrc_fee_paid
   ||amt_copay
   ||claim_gid
   ||frmly_src_cd
   ||bnft_lvl_cd
   ||rtmd_calc_mthd_cd
   ||rtmd_rate_pct
   ||rtmd_clnt_shr_pct
   ||rtmd_modl_pct
   ||step_ther_use_cd
   ||payer_id
   ||amt_tax
   ||ins_cd
   ||PHMCY_NPI_ID
   ||PYMT_SYS_ELIG_CD
   ||ADJD_BNFT_TYP_CD 
   ||PHMCY_TYP_CD 
   ||CLNT_DRUG_PRC_SRC_CD 
   ||CLNT_DRUG_PRC_TYP_CD   
from $SCHEMA_OWNER.V_APC_CLMS b
where RBATED_EXCPT_ID = 1
  and PYMT_SYS_ELIG_CD = '1'
  and CYCLE_GID in ( $CYCLE_GID, $MTH1_GID, $MTH2_GID, $MTH3_GID )
  and BATCH_DATE between TO_DATE('$QTR_STRT_DT','MM-DD-YYYY')
                 and     TO_DATE('$QTR_END_DT','MM-DD-YYYY')
;

commit;
SPOOL $SQL_PIPE_FILE

SELECT  /*+
        first_rows
        full(a)
        parallel(a,24)
           */
    a.formatted_data_row
FROM
    $SCHEMA_OWNER.tmp_apc_extract_table a
ORDER BY SUBSTR(a.formatted_data_row,432,12)
;

spool $SQL_LOG_FILE2

Select /*+ parallel(a,12) */
      'APC Rebated record count is ' || count(*) ||' from tmp_apc_extract_table.'
  from $SCHEMA_OWNER.tmp_apc_extract_table a
;  

quit;

EOF

    $ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

print " "
cat $db_user_password
print " "
    RETCODE=$?

    #-------------------------------------------------------------------------#
    # Check for good return and Log.                  
    #-------------------------------------------------------------------------#

    if  [[ $RETCODE != 0 ]]; then
      print ' ' >> $LOG_FILE
      print "=================== APC EXTRACT SQL FAILED ======================" >> $LOG_FILE
      print "APC Extract SQL did not complete successfully" >> $LOG_FILE 
      print "UNIX Return code = " $RETCODE >> $LOG_FILE
      tail -20 $DAT_FILE_OUTPUT >> $LOG_FILE
      print " " >> $LOG_FILE
      print "=================================================================" >> $LOG_FILE
    else
      print ' ' >> $LOG_FILE
      print "================= APC EXTRACT SQL COMPLETED =====================" >> $LOG_FILE
      print "completed executing APC Extract SQL" >> $LOG_FILE
      print `date` >> $LOG_FILE
      print "=================================================================" >> $LOG_FILE
      print " "   >> $LOG_FILE
      print "================================================================="   >> $LOG_FILE
      print ".... SQL_LOG_FILE1  ...."   >> $LOG_FILE
      cat  $SQL_LOG_FILE1 >> $LOG_FILE  
      print " "   >> $LOG_FILE
      print "================================================================="   >> $LOG_FILE
      print ".... SQL_LOG_FILE2  ...."   >> $LOG_FILE
      cat $SQL_LOG_FILE2 >> $LOG_FILE
      print " "   >> $LOG_FILE
      print "================================================================="   >> $LOG_FILE
      print 'put ' $MVS_RBATED_CLM_TRIGGER " " $FTP_MVS_RBATED_CLM_TRIGGER ' (replace' >> $MVS_FTP_COM_FILE
      print "quit" >> $MVS_FTP_COM_FILE
      ftp -i  $FTP_IP < $MVS_FTP_COM_FILE >> $LOG_FILE
    fi
fi
   
if [[ $RETCODE = 0 ]]; then

    print ' ' >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    print "Processing values for rbate_APC_extract_split.ksh are Rebate Year >"$Rbate_Yr"< and Rebate Qtr >"$Rbate_Qtr"<"  >> $LOG_FILE 
    print "Other parms passed - APCType >"$APCType"<" >> $LOG_FILE
    print "Calling Schedule >"$SCHEDULE"<, Calling Job >"$JOB"<"  >> $LOG_FILE
    print "calling rbate_APC_extract_split.ksh ASYNCHRONOUSLY " >> $LOG_FILE
    print `date` >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE

    . $SCRIPT_PATH/rbate_APC_extract_split.ksh $Rbate_Qtr $Rbate_Yr $APCType $SCHEDULE $JOB& 

    RETCODE=$?

    if  [[ $RETCODE != 0 ]]; then
        print ' ' >> $LOG_FILE
        print "================== SCRIPT FAILED ================================" >> $LOG_FILE
        print "script rbate_APC_extract_split.ksh Failed." >> $LOG_FILE
        print "If no message in this script shows error, then look in  >> $LOG_FILE
        print " $OUTPUT_PATH"/rbate_APC_extract_split.log" >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
        print ' ' >> $LOG_FILE
    else
        print ' ' >> $LOG_FILE
        print "================= SCRIPT COMPLETED SUCCESSFULLY =================" >> $LOG_FILE
        print "Asynchronous call to rbate_APC_extract_split.ksh successful" >> $LOG_FILE
        print `date` >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
    fi
fi 

if [[ $RETCODE = 0 ]]; then

    print " " >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    print "FTPing the APC Rebated Detail Trigger file to the MVS. "  >> $LOG_FILE
    print `date` >> $LOG_FILE

    rm -f $MVS_FTP_COM_FILE
    print 'Trigger file for MVS Rebated Detail claims for cycle ' $CYCLE_GID >> $MVS_RBATED_CLM_TRIGGER
    print 'This trigger file kicks off job KSZ4920J on the MVS system ' >> $MVS_RBATED_CLM_TRIGGER
    print 'put ' $MVS_RBATED_CLM_TRIGGER " " $FTP_MVS_RBATED_CLM_TRIGGER ' (replace' >> $MVS_FTP_COM_FILE
    print "=================================================================" >> $LOG_FILE
    print "quit" >> $MVS_FTP_COM_FILE
    
    print " " >> $LOG_FILE
    print "================== CONCATENATE FTP COMMANDS =========================" >> $LOG_FILE
    print "Start Concatenating FTP Commands for APC Rebated Detail Trigger file" >> $LOG_FILE
    cat $MVS_FTP_COM_FILE >> $LOG_FILE
    print "End Concatenating FTP Commands " >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    #do not capture return code here, if cat to the log failed, do not end script.

    ftp -i  $FTP_IP < $MVS_FTP_COM_FILE >> $LOG_FILE

    RETCODE=$?
    
    if  [[ $RETCODE != 0 ]]; then
        print " " >> $LOG_FILE
        print "================= FTP COMMAND FAILED ============================" >> $LOG_FILE
        print "FTP of APC Rebated Detail Trigger FAILED." >> $LOG_FILE
        print `date` >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
    else
        print " " >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
        print "MVS APC Rebated Detail Trigger ftp process complete "  >> $LOG_FILE
        print `date` >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
    fi
fi

#start script abend logic
if  [[ $RETCODE != 0 ]]; then
    print "APC Extract Failed - error message is: " >> $LOG_FILE 
    print ' ' >> $LOG_FILE 
    print "===================== J O B  A B E N D E D ======================" >> $LOG_FILE
    print "  Error Executing "$SCRIPTNAME"          " >> $LOG_FILE
    print "  Look in "$LOG_FILE       >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE

    # Send the Email notification 

    export JOBNAME=$SCHEDULE" / "$JOB
    export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
    export LOGFILE=$LOG_FILE
    export EMAILPARM4="  "
    export EMAILPARM5="  "

    print "Sending email notification with the following parameters" >> $LOG_FILE
    print "JOBNAME is " $JOBNAME >> $LOG_FILE 
    print "SCRIPTNAME is " $SCRIPTNAME >> $LOG_FILE
    print "LOGFILE is " $LOGFILE >> $LOG_FILE
    print "EMAILPARM4 is " $EMAILPARM4 >> $LOG_FILE
    print "EMAILPARM5 is " $EMAILPARM5 >> $LOG_FILE
    print "****** end of email parameters ******" >> $LOG_FILE

    . $SCRIPT_PATH/rbate_email_base.ksh
    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
    exit $RETCODE
fi

#Clean up files - DO NOT REMOVE THE MVS_CNTCARD_DAT FILE!  Required for RI_4508J job.
rm -f $SQL_FILE
# do not remove SQL_PIPE_FILE - issue came up where pipe file was deleted before all records spooled out.
##rm -f $SQL_PIPE_FILE
rm -f $MVS_SCL_TRG
rm -f $MVS_FTP_COM_FILE
rm -f $CYCLE_GID_DAT
rm -f $CYCLE_GID_SQL

print "....Completed executing " $SCRIPTNAME " ...."   >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE

