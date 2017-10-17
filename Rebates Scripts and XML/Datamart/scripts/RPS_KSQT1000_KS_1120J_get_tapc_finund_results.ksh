#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSQT1000_KS_1120J_get_tapc_finund_results.ksh
# Title         : this script will populate the rps.tapc_finund_results table 
#                 
# Description   : This script will build the
#                 1. TAPC_FINUND_RESULTS table
#                
#
# Abends        : None
#
#
# Parameters    : Period Id, Period Begin Date and Period End Date can be passed
#                   in to build this table for a previous period. See below for format.
#
# Output        : Log file as .$TIME_STAMP.log
#
# Exit Codes    : 0 to 2 = OK;  >2 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-03-2011  qcpi08a    add t.MAR_CD and t.CLM_USE_SRX_CD 
# 09-24-2009  qcpi03o    updated the extract sql to use new CR tables
#
# 07-29-09   qcpi733     Added GDX APC status update; removed export command
#                        from RETCODE assignments.
# 03-05-2008  is31701     Initial Creation.
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=$0
JOB=RPS_KSQT1000_KS_1120J_get_tapc_finund_results
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
UDB_LOADLOG_FILE=$LOG_PATH/$JOB"_load."$TIME_STAMP.log
PERIOD_FILE=$TMP_PATH/$JOB_period.dat
RETCODE=0

print " Starting script " $SCRIPT `date`
print " Starting script " $SCRIPT `date`                                       >> $LOG_FILE

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 300 STRT                          >> $LOG_FILE

# If a previous period is requested, parameters should be the Period Id
# in the format YYYYQn where n is 1 to 4 
# and period begin date and end date in the format MM/DD/YYYY

if [[ $# -eq 3 ]]; then
    PERIOD_ID=$1
    PERIOD_BEG_DT=$2
    PERIOD_END_DT=$3
    print "Period Id and date parameters supplied. They are "$PERIOD_ID" "$PERIOD_BEG_DT" "$PERIOD_END_DT >> $LOG_FILE 
else
    print "Period Id parameter was not supplied. It will be calculated "       >> $LOG_FILE
fi


##################################################################
# connect to udb
##################################################################

if [[ $RETCODE == 0 ]]; then
   $UDB_CONNECT_STRING                                                         >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!! aborting  - cant connect to udb "
      print "!!! aborting  - cant connect to udb "                             >> $LOG_FILE

      #Call the APC status update
      . `dirname $0`/RPS_GDX_APC_Status_update.ksh 300 ERR                     >> $LOG_FILE

      exit $RETCODE 
   fi
fi


#################################################################
# If the Period isn't supplied, get the current Period Id
#################################################################

PERIOD_SQL="SELECT SUBSTR(CAST(MAX(rbate_cycle_gid) AS CHAR(6)),1,4)||'Q'||SUBSTR(CAST(MAX(rbate_cycle_gid) AS CHAR(6)),6,1)
       ,CAST(MAX(rbate_cycle_gid) AS CHAR(6))
           ,CHAR(cycle_start_date,USA)
       ,CHAR(cycle_end_date,USA) 
           FROM rps.trbate_cycle
              WHERE rbate_cycle_gid = (SELECT MAX(rbate_cycle_gid) 
                         FROM rps.trbate_cycle
                    WHERE rbate_cycle_type_id = 2
                          AND rbate_cycle_status = UPPER('C'))
        GROUP BY CHAR(cycle_start_date,USA)
                 ,CHAR(cycle_end_date,USA)"

##echo "$PERIOD_SQL"                                                              >>$LOG_FILE
PERIOD_SQL=$(echo "$PERIOD_SQL" | tr '\n' ' ')


if [[ $# -eq 3 ]]; then
   print " Using supplied Period_Id. Period id is " $PERIOD_ID                 >> $LOG_FILE
   print " Period begin date " $PERIOD_BEG_DT                                  >> $LOG_FILE
   print " Period begin date " $PERIOD_END_DT                                  >> $LOG_FILE
else 
   print " Getting the period and begin and enddates  "                        >> $LOG_FILE     
   db2 -px $PERIOD_SQL  > $PERIOD_FILE                                  
   RETCODE=$?

   if [[ $RETCODE > 1 ]]; then
       print " "                                                               >> $LOG_FILE
       print "Error: select period, begin and end dates...... "                >> $LOG_FILE

       #Call the APC status update
       . `dirname $0`/RPS_GDX_APC_Status_update.ksh 300 ERR                    >> $LOG_FILE

       exit $RETCODE
   else
       if [[ $RETCODE = 1 ]]; then
          print " "                                                            >> $LOG_FILE
          print "No quarter found to process from VRAP.TDISCNT_PERIOD. "       >> $LOG_FILE

          #Call the APC status update
          . `dirname $0`/RPS_GDX_APC_Status_update.ksh 300 ERR                 >> $LOG_FILE

          exit $RETCODE
          print " "                                                            >> $LOG_FILE
       else
          print " "                                                            >> $LOG_FILE
          print "Cycle found to process from RPS.TRBATE_CYCLE "                >> $LOG_FILE
          read PERIOD_ID CYCLE_GID PERIOD_BEG_DT PERIOD_END_DT < $PERIOD_FILE 
          print "period id is "   $PERIOD_ID                                   >> $LOG_FILE
          print "quarter id is "  $CYCLE_GID                                   >> $LOG_FILE
          print "begin date is "  $PERIOD_BEG_DT                               >> $LOG_FILE
          print "end date is "    $PERIOD_END_DT                               >> $LOG_FILE
      print " "                                                                >> $LOG_FILE
       fi
    fi
fi

#################################################################
# now delete any existing rows for the current period.
#################################################################
                    
 DELETE_SQL="DELETE FROM RPS.TAPC_FINUND_RESULTS
        WHERE PERIOD_ID = '$PERIOD_ID'"
 
 echo "$DELETE_SQL"                                                            >>$LOG_FILE
 DELETE_SQL=$(echo "$DELETE_SQL" | tr '\n' ' ')
 print "delete sql is "$DELETE_SQL                       >>$LOG_FILE


if [[ $RETCODE == 0 ]]; then    
   print `date`" Delete any rows for this period on TAPC_FINUND_RESULTS. "
   print `date`" Delete any rows for this period on TAPC_FINUND_RESULTS. "     >> $LOG_FILE
                             
   db2 -px $DELETE_SQL                              >> $LOG_FILE                                                    

   RETCODE=$?

   if [[ $RETCODE > 2 ]]; then     
    print `date`" db2 error deleting TAPC_FINUND_RESULTS - retcode: "$RETCODE
    print `date`" db2 error deleting TAPC_FINUND_RESULTS - retcode: "$RETCODE  >> $LOG_FILE

    #Call the APC status update
    . `dirname $0`/RPS_GDX_APC_Status_update.ksh 300 ERR                       >> $LOG_FILE

    exit $RETCODE
   else
        print `date`" db2 delete to the TAPC_FINUND_RESULTS table was successful "
    print `date`" db2 delete to the TAPC_FINUND_RESULTS table was successful " >> $LOG_FILE
    RETCODE=0
   fi
fi 


#################################################################
# now execute the cursor load to insert data into the 
#   TAPC_FINUND_RESULTS table for the specified period.
###############################################################
if [[ $RETCODE == 0 ]]; then 
   print `date`" Inserting into TAPC_FINUND_RESULTS ... "
   print `date`" Inserting into TAPC_FINUND_RESULTS ... "                      >> $LOG_FILE 

db2 -stvxw "declare loadcurs cursor for
  SELECT
    t.PERIOD_ID
    ,t.RBATE_ID
    ,t.RAC
    ,reg.REBATE_TYPE
    ,t.EXTNL_LVL_ID1
    ,t.EXTNL_LVL_ID2
    ,t.EXTNL_LVL_ID3
    ,t.FRMLY_ID
    ,t.LCM_CODE
    ,t.CNTRL_NO
    ,t.PICO_NO
    ,cpa.CORP_NME
    ,t.EXCPT_STAT
    ,t.MAIL_ORDER_CODE
    ,CASE WHEN t.mail_order_code = '1' THEN
          CASE WHEN tmsn.phmcy_dspns_type = 'S' THEN 'SM'    --'SpecialtyRx Mail'
               WHEN tmsn.phmcy_dspns_type = 'M' THEN 'CM'    --'Caremark Mail'
               WHEN tpcc.phmcy_chain_code in ('039','177','380','608','782','008','940') THEN 'VM' --'CVS Mail' 
               ELSE 'OM' END  --OtherMail
     ELSE
          CASE WHEN tmsn.phmcy_dspns_type = 'S' THEN 'SR' --'SpecialtyRx Retail'
               WHEN tpcc.phmcy_chain_code in ('039','177','380','608','782','008','940') THEN 'CR' --'CVS Retail' 
               ELSE 'OR' END --OtherRetail
     END as finund_mail_order_code
    ,CASE WHEN (t.INV_MODEL = 'D' and RTRIM(reg.AP_COMPNY_CD) = '170' and reg.rebate_formula = 'A') THEN 'P'
          WHEN reg.MSTR_CLIENT_NAM = 'FEP' THEN 'F'
          WHEN (reg.MSTR_CLIENT_NAM = 'STATE OF MARYLAND' 
        OR  reg.CLIENT_NAME =  'STATE OF NEW YORK') THEN 'S' 
          ELSE t.INV_MODEL END as finund_model_code
     ,CASE WHEN (t.nabp_code  BETWEEN '4000000' AND '4099999') THEN 'Y'
         ELSE 'N' END as puerto_rico_ind  
    ,CASE WHEN t.MAIL_ORDER_CODE = '0' AND (t.DAYS_SPLY <= -84 OR t.DAYS_SPLY >= 84) THEN '1'
         ELSE '0' END as retail_90_ind
    ,t.NDC
    ,tdc.USC_CODE
    ,tdc.DSG_FORM
    ,tdc.STRGH_DESC
    ,tdc.ROUTE_NAME
    ,SUBSTR(CAST(tdc.GCN_NBR AS CHARACTER(8)),1,5)
    ,t.GNRC_IND
    ,t.EXTNL_SRC_CODE
    ,t.INV_MODEL
    ,SUM(t.INGRD_CST)
    ,SUM(t.AMT_PAID)
    ,SUM(t.CNTRC_FEE_PAID)
    ,SUM(t.AMT_TAX)
    ,SUM(t.AMT_COPAY)
    ,SUM(CASE WHEN t.CLAIM_TYPE = '+1' THEN  1
             WHEN t.CLAIM_TYPE = '-1'  THEN -1
             END) as rx_all_subm 
    ,SUM(CASE WHEN t.EXCPT_STAT = 'R' AND t.CLAIM_TYPE = '+1' THEN  1
             WHEN t.EXCPT_STAT = 'R' AND t.CLAIM_TYPE = '-1'  THEN -1
             ELSE 0 END) as rx_all_rbat_elig
    ,SUM(CASE WHEN t.rbate_access + t.rbate_mrkt_shr > 0 and t.claim_type = '+1' then  1
             WHEN t.rbate_access + t.rbate_mrkt_shr < 0 and t.claim_type = '-1' then -1
             ELSE 0 END) AS rx_all_rbate
    ,SUM(t.UNIT_QTY)
    ,SUM(t.UNIT_QTY * tdc.AWP) as awp_total
    ,SUM(t.UNIT_QTY * tdc.WHN) as whn_total
    ,SUM(CASE WHEN tdc.WHN = 0 THEN (tdc.WHN_CALC_RATIO * tdc.AWP * t.UNIT_QTY)
             ELSE (tdc.WHN * t.UNIT_QTY) END) as calc_whn_total
    ,SUM(t.DAYS_SPLY)
    ,SUM(t.RBATE_ACCESS)
    ,SUM(t.RBATE_MRKT_SHR)
    ,SUM(t.RBATE_ADMIN_FEE)
    ,t.FRMLY_DRUG_STAT_CD
    ,t.PMT_SYS_ELIG_CD
    ,tdc.DRUG_GID    
    ,t.RPT_ID
    ,t.INCNTV_TYP_CD
    ,t.CLM_USE_SRX_CD
    ,t.MAR_CD 
FROM 
    RPS.TAPC_DETAIL_$PERIOD_ID t 
    left outer join RPS.TDRUG_FINUND_CALC tdc
        on  t.NDC = tdc.NDC_NB
    left outer join RPS.CPAA106 cpa 
        on CAST(t.PICO_NO as INTEGER) = cpa.PICO_ID_NB AND t.CORP_CD = cpa.CORP_CD
    left outer join RPS.TPHMCY_CHAIN_CODES tpcc
        on t.NABP_CODE = tpcc.NABP_CODE 
    left outer join RPS.TMAIL_SPCLTY_NABP tmsn
        on t.NABP_CODE = tmsn.NABP_CODE
    left outer join  
( select distinct
'000'||trim(char(c.RBAT_ID)) as CLIENT_NBR, c.clnt_nm as CLIENT_NAME,
ca.RAC_ID as RAC, c.CLNT_TYP_CD as rebate_type, c.ap_co_cd as AP_COMPNY_CD,
ts.FORMULA as rebate_formula,m.mstr_clnt_nm as mstr_client_nam
from client_reg.crt_clnt c
        join client_reg.crt_mstr_clnt m
                on c.mstr_clnt_id = m.mstr_clnt_id
        join client_reg.crt_clnt_rule_assc ra
                on ra.rbat_id = c.rbat_id
        join client_reg.crt_prc_rule ru
                on ra.prc_rule_id = ru.prc_rule_id
        join client_reg.crt_prc_mstr pm
                on ru.prc_mstr_id = pm.prc_mstr_id
        join client_reg.crt_clnt_prc_pool_assc ca
                on c.rbat_id = ca.rbat_id
        join client_reg.crt_prc_pool p
                on p.prc_rule_id = ra.prc_rule_id and p.pool_typ_cd =ca.pool_typ_cd
        left outer join  (select distinct RAC_ID, FORMULA from rps.t_splits_pricing_base
                                where FORMULA='A'
                                        AND EFF_DT <='$PERIOD_END_DT'
                                        AND TERM_DT>='$PERIOD_BEG_DT') ts
                on ts.RAC_ID = ca.RAC_ID

where ra.EFF_DT <='$PERIOD_END_DT' and ra.TERM_DT>='$PERIOD_BEG_DT'
--        and c.RBAT_INV_EFF_DT <='$PERIOD_END_DT' and c.RBAT_INV_TERM_DT>='$PERIOD_BEG_DT'
) reg
       on t.RBATE_ID = reg.CLIENT_NBR
      AND t.RAC = reg.RAC
 WHERE t.PERIOD_ID = '$PERIOD_ID'
 GROUP BY 
     t.PERIOD_ID
    ,t.RBATE_ID
    ,t.RAC
    ,reg.REBATE_TYPE
    ,t.EXTNL_LVL_ID1
    ,t.EXTNL_LVL_ID2
    ,t.EXTNL_LVL_ID3
    ,t.FRMLY_ID
    ,t.LCM_CODE
    ,t.CNTRL_NO
    ,t.PICO_NO
    ,cpa.CORP_NME
    ,t.EXCPT_STAT
    ,t.MAIL_ORDER_CODE
    ,CASE WHEN t.mail_order_code = '1' THEN
          CASE WHEN tmsn.phmcy_dspns_type = 'S' THEN 'SM'    --'SpecialtyRx Mail'
               WHEN tmsn.phmcy_dspns_type = 'M' THEN 'CM'    --'Caremark Mail'
               WHEN tpcc.phmcy_chain_code in ('039','177','380','608','782','008','940') THEN 'VM' --'CVS Mail' 
               ELSE 'OM' END  --OtherMail
     ELSE
          CASE WHEN tmsn.phmcy_dspns_type = 'S' THEN 'SR' --'SpecialtyRx Retail'
               WHEN tpcc.phmcy_chain_code in ('039','177','380','608','782','008','940') THEN 'CR' --'CVS Retail' 
               ELSE 'OR' END --OtherRetail
     END 
    ,CASE WHEN (t.INV_MODEL = 'D' and RTRIM(reg.AP_COMPNY_CD) = '170' and reg.rebate_formula = 'A') THEN 'P'
          WHEN reg.MSTR_CLIENT_NAM = 'FEP' THEN 'F'
      WHEN (reg.MSTR_CLIENT_NAM = 'STATE OF MARYLAND' 
        OR  reg.CLIENT_NAME =  'STATE OF NEW YORK') THEN 'S'           
          ELSE t.INV_MODEL END 
    ,CASE WHEN (t.nabp_code  BETWEEN '4000000' AND '4099999') THEN 'Y'
         ELSE 'N' END   
    ,CASE WHEN t.MAIL_ORDER_CODE = '0' AND (t.DAYS_SPLY <= -84 OR t.DAYS_SPLY >= 84) THEN '1'
         ELSE '0' END 
    ,t.NDC
    ,tdc.USC_CODE
    ,tdc.DSG_FORM
    ,tdc.STRGH_DESC
    ,tdc.ROUTE_NAME
    ,SUBSTR(CAST(tdc.GCN_NBR AS CHARACTER(8)),1,5)
    ,t.GNRC_IND
    ,t.EXTNL_SRC_CODE
    ,t.INV_MODEL
    ,t.FRMLY_DRUG_STAT_CD
    ,t.PMT_SYS_ELIG_CD
    ,tdc.DRUG_GID    
    ,t.RPT_ID
    ,t.INCNTV_TYP_CD
    ,t.CLM_USE_SRX_CD
    ,t.MAR_CD     "                                    >> $LOG_FILE

RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error with TAPC_FINUND_RESULTS create cursor, retcode:  "$RETCODE  
      print "!!! error with TAPC_FINUND_RESULTS create cursor, retcode:  "$RETCODE     >> $LOG_FILE  
   fi
fi

if [[ $RETCODE == 0 ]]; then 
   print `date`" Starting load of TAPC_FINUND_RESULTS ... "
   print `date`" Starting load of TAPC_FINUND_RESULTS ... "                    >> $LOG_FILE  
   
   LOAD_SQL="load from loadcurs of cursor messages $UDB_LOADLOG_FILE insert into rps.TAPC_FINUND_RESULTS nonrecoverable "   

   LOAD_SQL=$(echo "$LOAD_SQL" | tr '\n' ' ')
   print "load sql is "$LOAD_SQL                                               >>$LOG_FILE
    
   db2 -stvxw $LOAD_SQL                                                        >>$LOG_FILE
 
   RETCODE=$?
   if [[ $RETCODE > 2 ]]; then 
      print "!!! error inserting into TAPC_FINUND_RESULTS, load retcode: "$RETCODE  
      print "!!! error inserting into TAPC_FINUND_RESULTS, load retcode: "$RETCODE  >> $LOG_FILE  
   fi
fi


#################################################################
# cleanup from successful run
#################################################################

if [[ $RETCODE > 2 ]]; then
    $RETCODE
    print "aborting script - error loading TDRUG_SQLSUMMARY_CALC "             >> $LOG_FILE

    #Call the APC status update
    . `dirname $0`/RPS_GDX_APC_Status_update.ksh 300 ERR                       >> $LOG_FILE

    exit $RETCODE
else
    print " Script " $SCRIPT " completed successfully on " `date`
    print " Script " $SCRIPT " completed successfully on " `date`              >> $LOG_FILE
    print "return_code =" $RETCODE                                             >> $LOG_FILE

    #Call the APC status update
    . `dirname $0`/RPS_GDX_APC_Status_update.ksh 300 END                       >> $LOG_FILE

    RETCODE=0
        
    mv $LOG_FILE            $LOG_ARCH_PATH/
        mv $UDB_LOADLOG_FILE*   $LOG_ARCH_PATH/
    if [[ $# -eq 0 ]]; then 
       rm $PERIOD_FILE  
    fi
fi

exit $RETCODE

