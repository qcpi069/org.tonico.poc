#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GD_1022J_TFRMLY_DRUG_RESULTS_PHC_load.ksh 
# Title         : vrap.TDRUG import process
#
# Description   : Loads vrap.TFRMLY_DRUG_RESULTS_PHC data   
#
# Parameters    : None. 
#  
# Input         : n/a
# 
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 10-29-2007  K. Gries   Add the process to create on-formulary records
#                        for the off formulary records. Also, add 3 years to
#                        the end_dt for FDB formulary records.
# 08-16-2007  K. Gries   Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

LOG_FILE="$LOG_PATH/GDX_GD_1022J_TFRMLY_DRUG_RESULTS_PHC_load.log"
SCRIPT=$(basename $0)
cp -f $LOG_FILE $LOG_ARCH_PATH/GDX_GD_1022J_TFRMLY_DRUG_RESULTS_PHC_load.log.`date +"%Y%j%H%M"`
rm -f $LOG_FILE
echo 'log_file ' $LOG_FILE

CALLED_SCRIPT=$SCRIPT_PATH/"GDX_GD_1022J_TFRMLY_DRUG_RESULTS_PHC_load.ksh"
print `date` "Starting " $CALLED_SCRIPT                    >> $LOG_FILE
print " "                                                >> $LOG_FILE

prcs_id=$(. $SCRIPT_PATH/Common_Prcs_Log_Message.ksh "$0" "vrap.TFRMLY_DRUG_RESULTS_PHC load" "Starting $SCRIPT_PATH/GDX_GD_1021J_TFRMLY_DRUG_RESULTS_PHC_load.ksh UDB Load of vrap.TDRUG table ")
if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi

###################################################################################
#
# Delete the vrap.TFRMLY_DRUG_RESULTS_PHC. 
#
###################################################################################

print " "                                                >> $LOG_FILE
print `date` "DELETE-ing vrap.TFRMLY_DRUG_RESULTS_PHC  "       >> $LOG_FILE
print " "                                                >> $LOG_FILE

SQL_UPDATE_STRING="delete from vrap.TFRMLY_DRUG_RESULTS_PHC " 

print $SQL_UPDATE_STRING >> $LOG_FILE

db2 -p $SQL_UPDATE_STRING >> $LOG_FILE


RETCODE=$?

if [[ $RETCODE != 0 && $RETCODE != 1 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the DELETE vrap.TFRMLY_DRUG_RESULTS_PHC step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "$CALLED_SCRIPT  failed in the vrap.TFRMLY_DRUG_RESULTS_PHC DELETE Step.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   return $RETCODE
fi 

print " "                                                >> $LOG_FILE
print `date` "Completed DELETE-ing vrap.TFRMLY_DRUG_RESULTS_PHC  "       >> $LOG_FILE
print " "                                                >> $LOG_FILE 
###################################################################################
#
# Delete the vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE. 
#
###################################################################################
print " "                                                >> $LOG_FILE
print `date` "DELETE-ing vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE  "       >> $LOG_FILE
print " "                                                >> $LOG_FILE

SQL_UPDATE_STRING="delete from vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE  " 

print $SQL_UPDATE_STRING >> $LOG_FILE

db2 -p $SQL_UPDATE_STRING >> $LOG_FILE


RETCODE=$?

if [[ $RETCODE != 0 && $RETCODE != 1 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the DELETE vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE  step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "$CALLED_SCRIPT  failed in the vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE  DELETE Step.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   return $RETCODE
fi 

print " "                                                >> $LOG_FILE
print `date` "Completed DELETE-ing vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE  "       >> $LOG_FILE
print " "     
###################################################################################
#
# Populate the vrap.TFRMLY_DRUG_RESULTS_PHC. 
#
###################################################################################

SQL_UPDATE_STRING="insert into vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE  " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"(   FRMLY_ID, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    FRMLY_SRC_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    NDC_LC11_ID, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    NHU_TYP_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    BRND_DRUG_NM, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    FRMLY_DRUG_STAT_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    RBAT_PREF_STAT_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    EFF_DT, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING") "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"SELECT  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"     tdp.FRMLY_ID FRMLY_ID  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,'P' FRMLY_SRC_CD  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,te.NDC_LC11_ID NDC_LC11_ID "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,t.NHU_TYP_CD NHU_TYP_CD "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,case when tdp.FRMLY_DRUG_SRC_CD = 'FRM' "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"               then COALESCE(te.FDB_BRAND_NAME,t.drug_nm,'unknown')  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"          when tdp.FRMLY_DRUG_SRC_CD = 'VP' "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"               then COALESCE(te.PRDCT_NAME,te.LBL_NAME,'unknown') "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"          else COALESCE(te.LBL_NAME,t.drug_nm,'unknown')  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"      end  BRND_DRUG_NM "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,case when tdp.DRUG_LIST_STAT_CD in ('F','f')  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"               then '1'  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"          when tdp.DRUG_LIST_STAT_CD not in ('F','f')  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"               then '0'  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"          else '0'  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"     end FRMLY_DRUG_STAT_CD "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,tdp.RBAT_PREF_STAT_CD RBAT_PREF_STAT_CD "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,tdp.EFF_DT EFF_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,tdp.END_DT END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"FROM VRAP.TFRMLY_DRUG_PHC tdp  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,VRAP.TDRUG_EDW te  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,vrap.tdrug t  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"WHERE tdp.NDC_LC11_ID = te.NDC_LC11_ID  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and tdp.NDC_LC11_ID = t.NDC_LC11_ID  "
##)  u "
##SQL_UPDATE_STRING=$SQL_UPDATE_STRING"where u.frmly_drug_stat_CD = '1'   "


print " "                                                >> $LOG_FILE
print `date` "Starting INSERT #1 "       >> $LOG_FILE
print " "                                                >> $LOG_FILE

print $SQL_UPDATE_STRING >> $LOG_FILE

db2 -p $SQL_UPDATE_STRING >> $LOG_FILE


RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the INSERT INTO vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "$CALLED_SCRIPT  failed in the vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE INSERT Step.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   return $RETCODE
fi 

print " "                                                >> $LOG_FILE
print `date` "Completed INSERT #1 "       >> $LOG_FILE
print " "                                                >> $LOG_FILE

###################################################################################
#
# Populate the vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE #2. 
#
###################################################################################

SQL_UPDATE_STRING="insert into vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE  " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"(   FRMLY_ID, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    FRMLY_SRC_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    NDC_LC11_ID, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    NHU_TYP_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    BRND_DRUG_NM, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    FRMLY_DRUG_STAT_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    RBAT_PREF_STAT_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    EFF_DT, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING") "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  SELECT tdp.FRMLY_ID FRMLY_ID   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"      ,'P' FRMLY_SRC_CD   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"      ,tdp.NDC_LC11_ID NDC_LC11_ID   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"      ,t.NHU_TYP_CD NHU_TYP_CD   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"       ,case when tdp.FRMLY_DRUG_SRC_CD = 'FRM' "    
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                  then COALESCE(tdp.FDB_BRAND_NAME,t.drug_nm,'unknown') "    
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             when tdp.FRMLY_DRUG_SRC_CD = 'VP' "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                  then COALESCE(tdp.PRDCT_NAME,tdp.LBL_NAME,t.drug_nm,'unknown') "    
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                  else COALESCE(tdp.LBL_NAME,t.drug_nm,'unknown') "  
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         end BRND_DRUG_NM "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"      ,case when tdp.MS_GNRC_FLAG = 1 and tdp.FRMLY_DRUG_SRC_CD = 'VP' and tdp.DRUG_MDDB_SRC_FLAG = '1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 then '1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"            when tdp.FRMLY_DRUG_SRC_CD = 'VP' "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 then (case when tdp_iv.FRMLY_ON_CNT >= tdp_iv.FRMLY_OFF_CNT and tdp.DRUG_MDDB_SRC_FLAG = '1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                                 then '0'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                            when tdp_iv.FRMLY_ON_CNT < tdp_iv.FRMLY_OFF_CNT and tdp.DRUG_MDDB_SRC_FLAG = '1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                                 then '1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                                 else '0'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                        end)   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"            when tdp.GNRC_FLAG = '1' and tdp.FRMLY_DRUG_SRC_CD = 'FRM' and tdp.DRUG_FDB_SRC_FLAG ='1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 then '1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"            when tdp.FRMLY_DRUG_SRC_CD = 'FRM' "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 then (case when tdp_iv.FRMLY_ON_CNT >= tdp_iv.FRMLY_OFF_CNT and tdp.DRUG_FDB_SRC_FLAG ='1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                                 then '0'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                            when tdp_iv.FRMLY_ON_CNT < tdp_iv.FRMLY_OFF_CNT and tdp.DRUG_FDB_SRC_FLAG ='1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                                 then '1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                                 else '0'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                             end)   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 else '0'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"        end FRMLY_DRUG_STAT_CD   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"      ,cast(NULL as char(1)) RBAT_PREF_STAT_CD   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"      ,case when tdp.FRMLY_DRUG_SRC_CD = 'VP' and tdp.DRUG_MDDB_SRC_FLAG = '1' "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 then coalesce(tdp.MDDB_EFF_DT,tdp.eff_dt,'01-01-1900')   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"            when tdp.FRMLY_DRUG_SRC_CD = 'FRM' and tdp.DRUG_MDDB_SRC_FLAG = '1' "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 then coalesce(tdp.fdb_eff_dt,tdp.eff_dt,'01-01-1900')   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 else coalesce(tdp.eff_dt,'01-01-1900')   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"        end EFF_DT   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"      ,case when tdp.FRMLY_DRUG_SRC_CD = 'VP' and tdp.DRUG_MDDB_SRC_FLAG = '1' "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 then coalesce(tdp.MDDB_END_DT,tdp.END_DT,'12-31-2039')   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"            when tdp.FRMLY_DRUG_SRC_CD = 'FRM' and tdp.DRUG_MDDB_SRC_FLAG = '1' "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 then coalesce(tdp.FDB_END_DT + 3 years,tdp.END_DT,'12-31-2039')   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 else coalesce(tdp.END_DT,'12-31-2039')   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"        end END_DT   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" FROM (select tdpi.frmly_id   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.frmly_drug_src_cd   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.NDC_LC11_ID    "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.MS_GNRC_FLAG    "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.GNRC_FLAG    "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.DRUG_MDDB_SRC_FLAG    "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.DRUG_FDB_SRC_FLAG    "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.LBL_NAME    "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.PRDCT_NAME    "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.FDB_BRAND_NAME   " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.FDB_EFF_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.FDB_END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.MDDB_EFF_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.MDDB_END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.EFF_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             ,tdpi.END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         from   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"          (select tdpd.FRMLY_ID frmly_id   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,tdpd.frmly_drug_src_cd frmly_drug_src_cd   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,TE.NDC_LC11_ID NDC_LC11_ID   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.MS_GNRC_FLAG ms_gnrc_flag   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.GNRC_FLAG GNRC_FLAG   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.DRUG_MDDB_SRC_FLAG DRUG_MDDB_SRC_FLAG   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.DRUG_FDB_SRC_FLAG DRUG_FDB_SRC_FLAG   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.LBL_NAME LBL_NAME   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.PRDCT_NAME PRDCT_NAME  " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.FDB_BRAND_NAME FDB_BRAND_NAME   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.FDB_EFF_DT FDB_EFF_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.FDB_END_DT FDB_END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.MDDB_EFF_DT MDDB_EFF_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,te.MDDB_END_DT MDDB_END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,'01-01-1900' EFF_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                 ,coalesce(te.end_dt,'12-31-2039') END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             from (select a.frmly_id frmly_id  " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                                  ,a.frmly_drug_src_cd frmly_drug_src_cd   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                     from VRAP.TFRMLY_DRUG_PHC a group by a.frmly_id, a.frmly_drug_src_cd) tdpd   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                         ,VRAP.TDRUG_EDW te ) tdpi   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             left outer join vrap.TFRMLY_DRUG_RESULTS_phc_stage tdrps  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                  on (tdpi.frmly_id = tdrps.frmly_id and  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                      tdpi.ndc_lc11_id = tdrps.ndc_lc11_id)  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"           where tdrps.frmly_id is NULL "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"             and tdrps.ndc_lc11_id is NULL "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"       ) tdp             "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"      ,vrap.tdrug t   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"      ,(select tdpi.FRMLY_ID as FRMLY_ID   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"              ,sum(case when tdpi.DRUG_LIST_STAT_CD in ('F','f')   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                             then 1   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                             else 0   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                    end) as FRMLY_ON_CNT  " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"              ,sum(case when tdpi.DRUG_LIST_STAT_CD not in ('F','f')   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                             then 1   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                             else 0   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"                    end) as FRMLY_OFF_CNT   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"          from VRAP.TFRMLY_DRUG_PHC tdpi   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         group by tdpi.FRMLY_ID) tdp_iv   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"where tdp.NDC_LC11_ID = t.NDC_LC11_ID  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and tdp.FRMLY_ID = tdp_iv.FRMLY_ID    "

print " "                                                >> $LOG_FILE
print `date` "Starting INSERT #2 "       >> $LOG_FILE
print " "                                                >> $LOG_FILE
print $SQL_UPDATE_STRING >> $LOG_FILE

db2 -p $SQL_UPDATE_STRING >> $LOG_FILE


RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the INSERT INTO vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE step #2." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "$CALLED_SCRIPT  failed in the vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE INSERT Step #2.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   return $RETCODE
fi 


print " "                                                >> $LOG_FILE
print `date` "Completed INSERT #2 "       >> $LOG_FILE
print " "                                                >> $LOG_FILE


###################################################################################
#
# Populate the vrap.TFRMLY_DRUG_RESULTS_PHC #3. 
#
###################################################################################

SQL_UPDATE_STRING="insert into vrap.TFRMLY_DRUG_RESULTS_PHC  " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"(   FRMLY_ID, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    FRMLY_SRC_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    NDC_LC11_ID, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    NHU_TYP_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    BRND_DRUG_NM, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    FRMLY_DRUG_STAT_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    RBAT_PREF_STAT_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    EFF_DT, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING") "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"   select "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    a.FRMLY_ID,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    a.FRMLY_SRC_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    a.NDC_LC11_ID,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    a.NHU_TYP_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    a.BRND_DRUG_NM,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    a.FRMLY_DRUG_STAT_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    a.RBAT_PREF_STAT_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    a.EFF_DT,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    a.END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"from  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    (  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    SELECT   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.FRMLY_ID,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.FRMLY_SRC_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.NDC_LC11_ID,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.NHU_TYP_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.BRND_DRUG_NM,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.FRMLY_DRUG_STAT_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.RBAT_PREF_STAT_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.EFF_DT,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.END_DT  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"FROM vrap.TFRMLY_DRUG_RESULTS_PHC_STAGE tdp   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"union all "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"SELECT   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.FRMLY_ID FRMLY_ID,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    'P' FRMLY_SRC_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.NDC_LC11_ID NDC_LC11_ID,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    td.NHU_TYP_CD NHU_TYP_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    case when tdp.FRMLY_DRUG_SRC_CD = 'FRM'  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"              then COALESCE(te.FDB_BRAND_NAME,td.drug_nm,'unknown') "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         when tdp.FRMLY_DRUG_SRC_CD = 'VP'  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"              then COALESCE(te.PRDCT_NAME,te.LBL_NAME,td.drug_nm,'unknown')  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         else COALESCE(te.LBL_NAME,td.drug_nm,'unknown') " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"     end BRND_DRUG_NM,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    '1' FRMLY_DRUG_STAT_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.RBAT_PREF_STAT_CD RBAT_PREF_STAT_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    case when tdp.frmly_drug_src_cd = 'VP' and te.DRUG_MDDB_SRC_FLAG = '1' then coalesce(te.MDDB_EFF_DT,'01-01-1900') "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         when tdp.frmly_drug_src_cd = 'FRM' and te.DRUG_FDB_SRC_FLAG = '1' then coalesce(te.FDB_EFF_DT,'01-01-1900') "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         else '01-01-1900' "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"     end EFF_DT,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.EFF_DT - 1 DAY  END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"FROM VRAP.TFRMLY_DRUG_PHC tdp "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,VRAP.TDRUG_EDW te "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,vrap.tdrug td  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"WHERE tdp.EFF_DT > '01-01-1900'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and tdp.NDC_LC11_ID = te.NDC_LC11_ID "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and tdp.NDC_LC11_ID = td.NDC_LC11_ID   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and tdp.end_dt <= coalesce(te.end_dt,'12-31-2039') "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and tdp.DRUG_LIST_STAT_CD not in ('F','f') "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"union all "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"SELECT   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.FRMLY_ID FRMLY_ID,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    'P' FRMLY_SRC_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.NDC_LC11_ID NDC_LC11_ID,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    td.NHU_TYP_CD NHU_TYP_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    case when tdp.FRMLY_DRUG_SRC_CD = 'FRM'  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"              then COALESCE(te.FDB_BRAND_NAME,td.drug_nm,'unknown') "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         when tdp.FRMLY_DRUG_SRC_CD = 'VP'  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"              then COALESCE(te.PRDCT_NAME,te.LBL_NAME,td.drug_nm,'unknown')  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         else COALESCE(te.LBL_NAME,td.drug_nm,'unknown') " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"     end BRND_DRUG_NM,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    '1' FRMLY_DRUG_STAT_CD, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.RBAT_PREF_STAT_CD RBAT_PREF_STAT_CD,  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    tdp.END_DT + 1 DAY EFF_DT,   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    case when tdp.frmly_drug_src_cd = 'VP' and te.DRUG_MDDB_SRC_FLAG = '1' then coalesce(te.MDDB_END_DT,'12-31-2039') "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         when tdp.frmly_drug_src_cd = 'FRM' and te.DRUG_FDB_SRC_FLAG = '1' then coalesce(te.FDB_END_DT + 3 years,'12-31-2039')  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"         else  case when coalesce(te.end_dt,'12-31-2039') < '12-31-2039' then coalesce(te.end_dt,'12-31-2039') else '12-31-2039' end "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"     end END_DT "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"FROM VRAP.TFRMLY_DRUG_PHC tdp "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,VRAP.TDRUG_EDW te "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ,vrap.tdrug td "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"WHERE tdp.END_DT < '12-31-2039'  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and tdp.NDC_LC11_ID = te.NDC_LC11_ID "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and tdp.NDC_LC11_ID = td.NDC_LC11_ID   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and tdp.end_dt <= coalesce(te.end_dt,'12-31-2039') "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and tdp.DRUG_LIST_STAT_CD not in ('F','f') "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"    ) a "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"where a.frmly_drug_stat_CD = '1'   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and a.nhu_typ_cd is not null   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and a.FRMLY_DRUG_STAT_CD is not null   "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  and a.eff_dt <= a.end_dt   "



print " "                                                >> $LOG_FILE
print `date` "Starting INSERT #3 "       >> $LOG_FILE
print " "                                                >> $LOG_FILE
print $SQL_UPDATE_STRING >> $LOG_FILE

db2 -p $SQL_UPDATE_STRING >> $LOG_FILE


RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the INSERT INTO vrap.TFRMLY_DRUG_RESULTS_PHC step #2." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "$CALLED_SCRIPT  failed in the vrap.TFRMLY_DRUG_RESULTS_PHC INSERT Step #2.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   return $RETCODE
fi 


print " "                                                >> $LOG_FILE
print `date` "Completed INSERT #3 "       >> $LOG_FILE
print " "                                                >> $LOG_FILE

. $SCRIPT_PATH/Common_Prcs_End_Message.ksh "$prcs_id" ""
if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi

rm -f $DAT_FILE

print " "                                                      >> $LOG_FILE
print `date` "....Completed executing " $CALLED_SCRIPT " ...."   >> $LOG_FILE

return $RETCODE
