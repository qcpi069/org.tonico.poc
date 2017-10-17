#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIOR4500_RI_4502J_APC_rbated_clm_extract.ksh   
# Title         : APC file processing.
#
# Description   : Extracts APC records into the 323 byte format 
#                 for future split into 10,000,000 record files,
#                 zip and transmit to MVS
# Maestro Job   : RIOR4500 RI_4500J
#
# Parameters    : CYCLE_GID
#
# Output        : Log file as $OUTPUT_PATH/rbate_RIOR4500_RI_4502J_APC_rbated_clm_extract.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date        ID      PARTE #  Description
# ---------  ---------  -------  ------------------------------------------#
# 03-13-2008 is45401    35129    Increased LINESIZE from 527 to 549; added
#                                INV_FRMLY_STAT_CD,CALC_BRND_XLAT_CD,
#                                INCNTV_TYP_CD,RPT_ID,DLVRY_SYS_CD to extract.
#                                Removed CYCLE_GID and BATCH_DATE from the
#                                V_APC_CLMS WHERE clause.
# 09-14-2007  Gries      Initial Creation. Split from 4500J
#                                Split Script into 3 parts, RI_4500J is Build TMP QTR Results,
#                RI_4502J is the REebated APC Extract and
#                RI_4552J is the LCM AMT Rebated Extracted Report.
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
  export ALTER_EMAIL_ADDRESS='randy.redus@Caremark.com'
  MVS_FTP_PREFIX='TEST.D'
  SCHEMA_OWNER="dma_rbate2"
fi

RETCODE=0
APCType='REBATED'
FTP_IP='204.99.4.30'
SCHEDULE="RIOR4500"
JOB="RI_4502J"
APC_OUTPUT_DIR=$OUTPUT_PATH/apc
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_APC_rbated_clm_extract"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
LOG_ARCH=$FILE_BASE".log"
SQL_FILE=$APC_OUTPUT_DIR/$FILE_BASE".sql"
SQL_PIPE_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_pipe.lst"
SQL_LOG_FILE1=$APC_OUTPUT_DIR/$FILE_BASE"SQLLOG1.sql"
SQL_LOG_FILE2=$APC_OUTPUT_DIR/$FILE_BASE"SQLLOG2.sql"
DAT_FILE_OUTPUT=$APC_OUTPUT_DIR/"rbate_RIOR4500_RI_4500J_APC_rbated_clm_extract.dat"
MVS_FTP_COM_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_ftpcommands.txt" 
FTP_MVS_CNTLCARD_FILE=" '"$MVS_FTP_PREFIX".TM30D011.CNTLCARD(KSZ4900C)'"
FTP_MVS_SCL_TRIGGER=" '"$MVS_FTP_PREFIX".KSZ4900.KS15APC.SCL.TRIGGER'"
MVS_CNTLCARD_DAT=$APC_OUTPUT_DIR"/rbate_APC_"$APCType"_file_KSZ4900C.dat"
MVS_SCL_TRG=$APC_OUTPUT_DIR"/rbate_APC_extract_scl.trg"
FTP_MVS_RBATED_CLM_TRIGGER=" '"$MVS_FTP_PREFIX".KSZ4920J.APCFINAL.REBATED.DETL.TRIG'"
MVS_RBATED_CLM_TRIGGER=$APC_OUTPUT_DIR"/rbate_APC_rbated_clm.trg"

#added for SOX
CYCLE_GID_DAT=$APC_OUTPUT_DIR/$FILE_BASE"_closed_cycle_gid.dat"
CYCLE_GID_SQL=$APC_OUTPUT_DIR/$FILE_BASE"_closed_cycle_gid.sql"

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
set LINESIZE 549
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

SELECT SYSDATE BUILD_EXTRACT_START_TIME FROM DUAL;

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
   ||INV_FRMLY_STAT_CD 
   ||CALC_BRND_XLAT_CD 
   ||INCNTV_TYP_CD 
   ||RPT_ID
   ||DLVRY_SYS_CD
from $SCHEMA_OWNER.V_APC_CLMS b
where RBATED_EXCPT_ID = 1
  and PYMT_SYS_ELIG_CD = '1'
;

commit;

SELECT SYSDATE BUILD_EXTRACT_END_TIME FROM DUAL;

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
      print " "   >> $LOG_FILE
      print "================================================================="   >> $LOG_FILE
###      print 'put ' $MVS_RBATED_CLM_TRIGGER " " $FTP_MVS_RBATED_CLM_TRIGGER ' (replace' >> $MVS_FTP_COM_FILE
###      print "quit" >> $MVS_FTP_COM_FILE
###      ftp -i  $FTP_IP < $MVS_FTP_COM_FILE >> $LOG_FILE
    fi
fi
   
if [[ $RETCODE = 0 ]]; then

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

    print ' ' >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    print "Processing values for rbate_APC_extract_split.ksh are Rebate Year >"$Rbate_Yr"< and Rebate Qtr >"$Rbate_Qtr"<"  >> $LOG_FILE 
    print "Other parms passed - APCType >"$APCType"<" >> $LOG_FILE
    print "Calling Schedule >"$SCHEDULE"<, Calling Job >"$JOB"<"  >> $LOG_FILE
    print "calling rbate_APC_extract_split.ksh ASYNCHRONOUSLY " >> $LOG_FILE
    print `date` >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE

    . $SCRIPT_PATH/rbate_APC_extract_split.ksh $Rbate_Qtr $Rbate_Yr $APCType $SCHEDULE RI_4500J& 

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

