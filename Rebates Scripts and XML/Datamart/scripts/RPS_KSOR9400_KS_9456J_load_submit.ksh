#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_9450J_inv_load_apc.ksh
# Title         : Invoice Load
# Description   : This script will load the datamart APC tables with 
#                 quarterly invoice data.
# 
# Abends        : 
#                                 
# Parameters    : Period Id (required), eg  2006Q1
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-27-06   is89501     Initial Creation.
# 01-25-07   qcpi03o     Add two fields in TAPC_Detail_yyyyQq tables
#                           pmcy_npi_id, pmt_sys_elig_cd
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSOR9400_KS_9450J_load_submit.ksh
JOB=ks9450j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0
SUBNM=rbate_RIOR4500_RI_4504J_APC_submttd_clm_extract
SUBFILE=$SUBNM.zip
SUBDATA=$TMP_PATH/$SUBNM.dat
SUBXTRA=$INPUT_PATH/ksz4960j.xref.dat
SUBXTRATRG=$INPUT_PATH/ksz4960j.trigger
SUBLOAD=$TMP_PATH/$SUBNM.lod

JAVAPGM1=jt003apc
export CLASSPATH=$JAVA_XPATH/rpsdm.jar:$CLASSPATH

LOD_STMT=
LFL=
DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log

SUB_DATA_CNT=0
SUB_XTRA_CNT=0

APC_INIT=./APC.init

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

############################################################################
# 1) connect to udb and get Quarter parameter from the quarter_summary table
############################################################################

   $UDB_CONNECT_STRING                                                 >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - cant connect to udb " 
      print "!!! terminating script - cant connect to udb "            >> $LOG_FILE  
   else		
			QPARM=`db2 -x "select min(period_id) from rps.quarter_summary where RPS_ACTIVE_IND='0'"`
			print $QPARM > $APC_INIT

			TAPC_COUNT=`db2 -x "select count(*) from "$SCHEMA".TAPC_DETAIL_"$QPARM""`

			if [[ $TAPC_COUNT -gt 0 ]]; then
   			export RETCODE=12
   			print "aborting script - "$SCHEMA".TAPC_DETAIL_"$QPARM" is not empty " 
   			print "aborting script - "$SCHEMA".TAPC_DETAIL_"$QPARM" is not empty "     >> $LOG_FILE  
			fi   
   fi


################################################################
# 2) check that file counts match
################################################################
# submitted
if [[ $RETCODE == 0 ]]; then    
   SUB_DATA_CNT=$(wc -l < $SUBDATA)
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $SUBDATA  
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $SUBDATA  >> $LOG_FILE
   fi
fi
if [[ $RETCODE == 0 ]]; then    
   SUB_XTRA_CNT=$(wc -l < $SUBXTRA)
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $SUBXTRA  
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $SUBXTRA  >> $LOG_FILE
   fi
fi
if [[ $RETCODE == 0 ]]; then    
   if  [[ $SUB_XTRA_CNT == $SUB_DATA_CNT ]]; then
      print " submitted file counts "  $SUB_XTRA_CNT " and " $SUB_DATA_CNT " match okay "
      print " submitted file counts "  $SUB_XTRA_CNT " and " $SUB_DATA_CNT " match okay " >> $LOG_FILE
   else
      print " submitted file counts "  $SUB_XTRA_CNT " and " $SUB_DATA_CNT " do not match!!! terminating script!"
      print " submitted file counts "  $SUB_XTRA_CNT " and " $SUB_DATA_CNT " do not match!!! terminating script! " >> $LOG_FILE
      export RETCODE=12
   fi
fi


################################################################
# 3) merge the main/extended files to formatted db2 loadfiles
################################################################

if [[ $RETCODE == 0 ]]; then    
	 java $JAVAPGM1 $SUBDATA $SUBXTRA $SUBLOAD $QPARM   >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** ' $JAVAPGM1 ' returned ' $RETCODE ' processing ' $SUBDATA  
     print `date` ' *** ' $JAVAPGM1 ' returned ' $RETCODE ' processing ' $SUBDATA  >> $LOG_FILE
   else
     print `date` ' *** ' $JAVAPGM1 ' processed submitted file okay ' 
     print `date` ' *** ' $JAVAPGM1 ' processed submitted file okay '   >> $LOG_FILE
#    delete files to reclaim space
#     rm -f $SUBDATA
#     rm -f $SUBXTRA
   fi
fi



################################################################
# 4) db2load rebated - using replace to clear table
################################################################
LFL=" (PERIOD_ID, CLAIM_LVL1, CLAIM_LVL2, CLAIM_LVL3, NEW_RFIL_CD, RX_NB, MAIL_ORDER_CODE, DSPND_DATE, "
LFL=$LFL" UNIT_QTY, DAYS_SPLY, INGRD_CST, MBR_RBTE_DISC_AMT, PRIOR_ATHZN_FLAG, NDC, EXTNL_SRC_CODE, "
LFL=$LFL" EXTNL_LVL_ID1, EXTNL_LVL_ID2, EXTNL_LVL_ID3, EXTNL_LVL_ID4, EXTNL_LVL_ID5, RBATE_ID, "
LFL=$LFL" FRMLY_ID, LCM_CODE, COPAY_SRC_CODE, INSRD_ID, SFX_CODE, NABP_CODE, CHN_NBR, PPO_NBR, "
LFL=$LFL" PICO_NO, CNTRL_NO, BSKT_NAME, RBATE_ACCESS, RBATE_MRKT_SHR, RBATE_ADMIN_FEE, "
LFL=$LFL" AWP_UNIT_CST, EXCPT_STAT, EXCPT_CODE, INV_GID, CYCLE_GID_QQYY, CLM_USE_SRX_CD, GNRC_IND, "
LFL=$LFL" USER_FIELD6_FLG, CLAIM_TYPE, INV_MODEL, POSR_IND, POSR_RBAT_CLNT_SHR, POSR_RBAT_MBR_SHR, "
LFL=$LFL" POSR_RBAT_TOT_SHR, NHU_TYP_CD, MEDD_PLAN_TYP_CD, MEDD_CNTRC_ID, MEDD_PRTC_CD, MEDD_DRUG_CD, "
LFL=$LFL" FRMLY_DRUG_STAT_CD, FRMLY_DRUG_TIER_VL, PLAN_TIER_VL, AMT_PAID, CNTRC_FEE_PAID, AMT_COPAY, "
LFL=$LFL" CLAIM_GID, FRMLY_SRC_CD, BNFT_LVL_CD, POSR_CALC_MTHD_CD, POSR_RATE_PCT, POST_CLNT_SHR_PCNT, "
LFL=$LFL" POSR_MODL_PCT, STEP_THER_USE_CD, PAYER_ID, AMT_TAX, INS_CD, RAC, XR007_CG_NB, "
LFL=$LFL" pmcy_npi_id, pmt_sys_elig_cd, ADJD_BNFT_TYP_CD, PHMCY_TYP_CD, CLNT_DRUG_PRC_SRC_CD, CLNT_DRUG_PRC_TYP_CD, "
LFL=$LFL" Inv_frmly_stat_cd, calc_brnd_xlat_cd, incntv_typ_cd,rpt_id, dlvry_sys_cd)"

# using INSERT to append table
if [[ $RETCODE == 0 ]]; then    
      LOD_STMT=" of del modified by coldel|,usedefaults messages "$DBMSG_FILE" replace into "$SCHEMA".TAPC_DETAIL_"$QPARM" "$LFL" nonrecoverable "
      print " starting db2 load of "$SUBLOAD " with load stmt="$LOD_STMT 
      print " starting db2 load of "$SUBLOAD " with load stmt="$LOD_STMT  >> $LOG_FILE
      db2 -stvx load from $SUBLOAD $LOD_STMT             >> $LOG_FILE 
      export RETCODE=$?
      if [[ $RETCODE != 0 ]]; then     
	print `date`" db2 load error on "$SUBLOAD" - retcode: "$RETCODE
	print `date`" db2 load error on "$SUBLOAD" - retcode: "$RETCODE   >> $LOG_FILE
      else
      	print `date`" db2 load of "$SUBLOAD" was successful "
	print `date`" db2 load of "$SUBLOAD" was successful "   >> $LOG_FILE
      fi
fi

################################################################
# 5) clear check constraint from load
################################################################
if [[ $RETCODE == 0 ]]; then    
      print " validating check constraint after load "
      print " validating check constraint after load "   >> $LOG_FILE
      db2 -stvx set integrity for $SCHEMA.TAPC_DETAIL_$QPARM immediate checked    >> $LOG_FILE 
      export RETCODE=$?
      if [[ $RETCODE != 0 ]]; then     
	print `date`" db2 constraint validation error - retcode: "$RETCODE
	print `date`" db2 constraint validation error - retcode: "$RETCODE   >> $LOG_FILE
      else
      	print `date`" db2 load constraint validation was successful "
	print `date`" db2 load constraint validation was successful "   >> $LOG_FILE
      fi
fi


################################################################
# Z) disconnect from udb
################################################################
db2 -stvx connect reset                                                >> $LOG_FILE 
db2 -stvx quit                                                         >> $LOG_FILE 


# following scripts to be executed :
# build drug_client_sum
# build client_sum


#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                               >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE
   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOG_FILE 

#################################################################
# cleanup from successful run
#################################################################
mv $LOG_FILE       $LOG_ARCH_PATH/ 

rm -f $SUBXTRA
rm -f $SUBLOAD
rm -f $SUBXTRATRG
# rm -f $DBLOAD_PATH/$SUBFILE   
# rm -f $DBMSG_FILE* 

print "return_code =" $RETCODE
exit $RETCODE
