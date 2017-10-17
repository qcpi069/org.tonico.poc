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

SCRIPT=RPS_KSOR9400_KS_9450J_inv_load_apc.ksh
JOB=ks9450j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0
REBNM=rbate_RIOR4500_RI_4500J_APC_rbated_clm_extract
SUBNM=rbate_RIOR4500_RI_4504J_APC_submttd_clm_extract
REBFILE=$REBNM.zip
SUBFILE=$SUBNM.zip
REBDATA=$DBLOAD_PATH/$REBNM.dat
SUBDATA=$DBLOAD_PATH/$SUBNM.dat
REBXTRA=$INPUT_PATH/ksz4014j.xref.dat
SUBXTRA=$INPUT_PATH/ksz4960j.xref.dat
REBXTRATRG=$INPUT_PATH/ksz4014j.trigger
SUBXTRATRG=$INPUT_PATH/ksz4960j.trigger
REBLOAD=$DBLOAD_PATH/$REBNM.lod
SUBLOAD=$DBLOAD_PATH/$SUBNM.lod
JAVAPGM1=jt003apc.class
LOD_STMT=
LFL=
DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log

FTP_PATH=/staging/apps/rebates/prod/output/apc
FTP_REB_IP=dmadom4

REB_DATA_CNT=0
SUB_DATA_CNT=0
REB_XTRA_CNT=0
SUB_XTRA_CNT=0

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

################################################################
# 1) examine Quarter parameter  yyyyQn
################################################################
print " input parm was: " $1   
print " input parm was: " $1   >> $LOG_FILE  
YEAR=""
QTR=""
QPARM=""
if [[ $# -eq 1 ]]; then
#   edit supplied parameter
    YEAR=`echo $1 |cut -c 1-4`
    QTR=`echo $1 |cut -c 6-6`
    if (( $YEAR > 1990 && $YEAR < 2050 )); then
      print ' using parameter YEAR of ' $YEAR
    else
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is yyyyQn.  Terminating script '
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is yyyyQn.  Terminating script '  >> $LOG_FILE 
      export RETCODE=12
    fi
    if (( $QTR > 0 && $QTR < 5 )); then
      print ' using parameter QUARTER of ' $QTR
    else
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is yyyyQn. Terminating script '
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is yyyyQn. Terminating script ' >> $LOG_FILE 
      export RETCODE=12
    fi
else
   export RETCODE=12
   print "aborting script - required parameter not supplied " 
   print "aborting script - required parameter not supplied "     >> $LOG_FILE  
fi
QPARM=$YEAR"Q"$QTR
print ' qparm is ' $QPARM
print ' year is ' $YEAR


################################################################
# 2) verify that the two xref files were sent from the mainframe
################################################################
if [[ $RETCODE == 0 ]]; then    
   if [[ ! -r $REBXTRA ]] ; then
      print "aborting script - required file " $REBXTRA " is not present " 
      print "aborting script - required file " $REBXTRA " is not present "    >> $LOG_FILE  
      export RETCODE=12
   fi
fi

if [[ $RETCODE == 0 ]]; then    
   if [[ ! -r $SUBXTRA ]] ; then
      print "aborting script - required file " $SUBXTRA " is not present " 
      print "aborting script - required file " $SUBXTRA " is not present "    >> $LOG_FILE  
      export RETCODE=12
   fi
fi


################################################################
# 3) get the submitted and rebated claim data files from Rebates
################################################################
if [[ $RETCODE == 0 ]]; then    
   print " doing ftp now ........................"
   FTP_CMD_FILE=$TMP_PATH"/"$JOB"_ftpcmds.txt"
   cat > $FTP_CMD_FILE << 99EOFSQLTEXT99
binary
cd $FTP_PATH
get $REBFILE    $DBLOAD_PATH/$REBFILE   
get $SUBFILE    $DBLOAD_PATH/$SUBFILE   
quit
99EOFSQLTEXT99
   cat $FTP_CMD_FILE                                                           >> $LOG_FILE
   ftp -i $FTP_REB_IP < $FTP_CMD_FILE                                          >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]] ; then
      print  ' !! ftp returned code ' $RETCODE 
      print `date` ' !! ftp returned code ' $RETCODE ' terminating script '   >> $LOG_FILE
      export RETCODE=12
   fi
fi
 
################################################################
# 4) unzip submitted claims
################################################################
if [[ $RETCODE == 0 ]]; then  
    print `date` " ftp completed okay, doing unzip/sort of " $DBLOAD_PATH/$SUBFILE
    print `date` " ftp completed okay, doing unzip/sort of " $DBLOAD_PATH/$SUBFILE  >> $LOG_FILE
    gzip -d -c -v $DBLOAD_PATH/$SUBFILE > $SUBDATA
    export RETCODE=$?
    if [[ $RETCODE != 0 ]]; then
       print `date` ' !! gzip/sort of '  $DBLOAD_PATH/$SUBFILE  ' returned code ' $RETCODE 
       print `date` ' !! gzip/sort of '  $DBLOAD_PATH/$SUBFILE  ' returned code ' $RETCODE ' terminating script '   >> $LOG_FILE
       export RETCODE=12
    fi
fi
#    delete the zip file to reclaim space
if [[ $RETCODE == 0 ]]; then  
    print `date` " unzip/sort of " $DBLOAD_PATH/$REBFILE " finished okay "
    print `date` " unzip/sort of " $DBLOAD_PATH/$REBFILE " finished okay " >> $LOG_FILE
    rm -f $DBLOAD_PATH/$SUBFILE 
fi


################################################################
# 5) unzip rebated claims
################################################################
if [[ $RETCODE == 0 ]]; then   
    gzip -d -c -v $DBLOAD_PATH/$REBFILE > $REBDATA
    export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print `date` ' !! unzip/sort of '  $DBLOAD_PATH/$REBFILE  ' returned code ' $RETCODE 
      print `date` ' !! unzip/sort of '  $DBLOAD_PATH/$REBFILE  ' returned code ' $RETCODE ' terminating script '   >> $LOG_FILE
      export RETCODE=12
   fi
fi
#    delete the zip file to reclaim space
if [[ $RETCODE == 0 ]]; then    
    print `date` " unzip/sort of " $DBLOAD_PATH/$REBFILE " finished okay "
    print `date` " unzip/sort of " $DBLOAD_PATH/$REBFILE " finished okay " >> $LOG_FILE
    rm -f $DBLOAD_PATH/$REBFILE 
fi

print " all zipping/sorting has been executed " `date`


################################################################
# 6) check that file counts match
################################################################
# rebated
if [[ $RETCODE == 0 ]]; then    
   REB_DATA_CNT=$(wc -l < $REBDATA)
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $REBDATA  
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $REBDATA  >> $LOG_FILE
   fi
fi
if [[ $RETCODE == 0 ]]; then    
   REB_XTRA_CNT=$(wc -l < $REBXTRA)
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $REBXTRA  
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $REBXTRA  >> $LOG_FILE
   fi
fi
if [[ $RETCODE == 0 ]]; then    
   if  [[ $REB_XTRA_CNT == $REB_DATA_CNT ]]; then
      print " rebated file counts "  $REB_XTRA_CNT " and " $REB_DATA_CNT " match okay "
      print " rebated file counts "  $REB_XTRA_CNT " and " $REB_DATA_CNT " match okay " >> $LOG_FILE
   else
      print " rebated file counts "  $REB_XTRA_CNT " and " $REB_DATA_CNT " do not match!!! terminating script!"
      print " rebated file counts "  $REB_XTRA_CNT " and " $REB_DATA_CNT " do not match!!! terminating script! " >> $LOG_FILE
      export RETCODE=12
   fi
fi

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
# 7) merge the main/extended files to formatted db2 loadfiles
################################################################
if [[ $RETCODE == 0 ]]; then    
   java $JAVA_XPATH/$JAVAPGM1 $REBDATA $REBXTRA $REBLOAD $QPARM  >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** ' $JAVAPGM1 ' returned ' $RETCODE ' processing ' $REBDATA  
     print `date` ' *** ' $JAVAPGM1 ' returned ' $RETCODE ' processing ' $REBDATA  >> $LOG_FILE
   else
     print `date` ' *** ' $JAVAPGM1 ' processed rebated file okay ' 
     print `date` ' *** ' $JAVAPGM1 ' processed rebated file okay '   >> $LOG_FILE
#    delete files to reclaim space
     rm -f $REBDATA
     rm -f $REBXTRA
   fi
fi

if [[ $RETCODE == 0 ]]; then    
   java $JAVA_XPATH/$JAVAPGM1 $SUBDATA $SUBXTRA $SUBLOAD $QPARM   >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** ' $JAVAPGM1 ' returned ' $RETCODE ' processing ' $SUBDATA  
     print `date` ' *** ' $JAVAPGM1 ' returned ' $RETCODE ' processing ' $SUBDATA  >> $LOG_FILE
   else
     print `date` ' *** ' $JAVAPGM1 ' processed submitted file okay ' 
     print `date` ' *** ' $JAVAPGM1 ' processed submitted file okay '   >> $LOG_FILE
#    delete files to reclaim space
     rm -f $SUBDATA
     rm -f $SUBXTRA
   fi
fi


################################################################
# 8) connect to udb
################################################################
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - cant connect to udb " 
      print "!!! terminating script - cant connect to udb "            >> $LOG_FILE  
   fi
fi


################################################################
# 9) db2load rebated - using replace to clear table
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
LFL=$LFL" pmcy_npi_id, pmt_sys_elig_cd, ADJD_BNFT_TYP_CD, PHMCY_TYP_CD, CLNT_DRUG_PRC_SRC_CD, CLNT_DRUG_PRC_TYP_CD) "

# using REPLACE to clear table
if [[ $RETCODE == 0 ]]; then    
      LOD_STMT=" of del modified by coldel|,usedefaults messages "$DBMSG_FILE" replace into "$SCHEMA".TAPC_DETAIL_"$QPARM" "$LFL" nonrecoverable "
      print " starting db2 load of "$REBLOAD " with load stmt="$LOD_STMT 
      print " starting db2 load of "$REBLOAD " with load stmt="$LOD_STMT  >> $LOG_FILE
      db2 -stvx load from $REBLOAD $LOD_STMT             >> $LOG_FILE 
      export RETCODE=$?
      if [[ $RETCODE != 0 ]]; then     
	print `date`" db2 load error on "$REBLOAD" - retcode: "$RETCODE
	print `date`" db2 load error on "$REBLOAD" - retcode: "$RETCODE   >> $LOG_FILE
      else
      	print `date`" db2 load of "$REBLOAD" was successful "
	print `date`" db2 load of "$REBLOAD" was successful "   >> $LOG_FILE
      fi
fi 

# using INSERT to append table
if [[ $RETCODE == 0 ]]; then    
      LOD_STMT=" of del modified by coldel|,usedefaults messages "$DBMSG_FILE" insert into "$SCHEMA".TAPC_DETAIL_"$QPARM" "$LFL" nonrecoverable "
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
# 10) clear check constraint from load
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

# rm -f $REBXTRA
# rm -f $SUBXTRA
# rm -f $REBXTRATRG
# rm -f $SUBXTRATRG
# rm -f $REBLOAD
# rm -f $SUBLOAD
rm -f $FTP_CMD_FILE
# rm -f $DBLOAD_PATH/$REBFILE   
# rm -f $DBLOAD_PATH/$SUBFILE   
# rm -f $DBMSG_FILE* 

print "return_code =" $RETCODE
exit $RETCODE
