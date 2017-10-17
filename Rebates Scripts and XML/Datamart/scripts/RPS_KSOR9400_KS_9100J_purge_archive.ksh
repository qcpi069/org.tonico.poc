#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_9100J_purge_archive.ksh
# Title         : RPS Purge Archive
# Description   : This script will purge one quarter data out of 
#                 the following tables:
#                       rps.ksrb103_inv_lnamt
#			rps.ksrb222_fesump
#			rps.ksrb223_fesumc
#			rps.ksrb250_distr
#			rps.tapc_lcm_summary
#		  The purged quarter summary data will be copied to 
#		  history tables:
#			rps.t_sl_client_sum_$YEAR
#			rps.t_sl_client_pico_sum_$YEAR
#			rps.t_claims_$YEAR
#			rps.ksrb250_$YEAR
#			rps.t_inv_lnamt_sum_$YEAR
#			rps.t_rebate_id_qtr_$YEAR
#			rps.ksrb223_$YEAR
#		  This script will be kicked off by MVS job KSZ6250.
# 
# Abends        : 
#                                 
# Parameters    : Period Id (required), eg  2004Q1
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02-08-08   qcpi03o     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=$0
JOB=$(echo $0|awk -F. '{print $1}')
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0
DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log
DCDATA=$DBLOAD_PATH/ks9100.tmp
#DCDATA=ks9100.tmp
DCSQL=$TMP_PATH/$JOB.sql


print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

################################################################
# 1) examine PeriodID parameter  yyyyQn
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
QTR="Q"$QTR
print ' qparm is ' $QPARM
print ' year is ' $YEAR
print ' quarter is ' $QTR

################################################################
# 1) connect to udb
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
# 2) Archive KSRB222 summary data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then 
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT INV_QTR,
	    PICO_ID,
            CONTRACT_ID,
            NDC_ID,
            REBATE_ID,
            RAC_ID,
            TRAN_TYPE_CD,
            STMT_ID,
            AMOUNT
    FROM rps.f_sl_client_pico_sum
     WHERE INV_QTR = '$QPARM';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`                                                   >> $LOG_FILE
print " *** end of sql display."                                     >> $LOG_FILE

fi

#
# extract to file
#
if [[ $RETCODE == 0 ]]; then
   db2 -tvf $DCSQL                                                   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!!aborting script - error exporting table rps.f_sl_client_pico_sum "               >> $LOG_FILE
   fi
fi


#
# chmod it so db2 load can see it
#
if [[ $RETCODE == 0 ]]; then
   chmod 777 $DCDATA                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - cant chmod " $DCDATA
      print "aborting script - cant chmod " $DCDATA                  >> $LOG_FILE
   fi
fi


#
# load db2
#
if [[ $RETCODE == 0 ]]; then
   print " Starting db2 load " `date`                                >> $LOG_FILE
	echo "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.t_sl_client_pico_sum_$YEAR nonrecoverable"   >> $LOG_FILE

   db2 "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.t_sl_client_pico_sum_$YEAR nonrecoverable"   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_sl_client_pico_sum_$YEAR with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
      print " WARNING - LOAD TERMINATE ACTION IS REQUIRED!!! "           >> $LOG_FILE
   fi
fi

################################################################
# 3) Archive KSRB223 summary data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT INV_QTR,
            REBATE_ID,
            RAC_ID,
            TRAN_TYPE_CD,
            STMT_ID,
            AMOUNT
    FROM rps.f_sl_client_sum
     WHERE INV_QTR = '$QPARM';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`                                                   >> $LOG_FILE
print " *** end of sql display."                                     >> $LOG_FILE

fi

#
# extract to file
#
if [[ $RETCODE == 0 ]]; then
   db2 -tvf $DCSQL                                                   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!!aborting script - error exporting table rps.f_sl_client_sum "               >> $LOG_FILE
   fi
fi


#
# chmod it so db2 load can see it
#
if [[ $RETCODE == 0 ]]; then
   chmod 777 $DCDATA                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - cant chmod " $DCDATA
      print "aborting script - cant chmod " $DCDATA                  >> $LOG_FILE
   fi
fi


#
# load db2
#
if [[ $RETCODE == 0 ]]; then
   print " Starting db2 load " `date`
   print " Starting db2 load " `date`                                >> $LOG_FILE
   db2 "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.t_sl_client_sum_$YEAR nonrecoverable"   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_sl_client_sum_$YEAR with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
      print " WARNING - LOAD TERMINATE ACTION IS REQUIRED!!! "           >> $LOG_FILE
   fi
fi

################################################################
# 4) Archive KSRB223 data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT     FINEV_SUMM_ID  , 
    RBAT_BILL_PRD_NM ,  
    BE_TYP_CD        , 
    BE_ID            , 
    RBAT_AFIL_CD     , 
    CG_NB            , 
    TRAN_TYP_CD      , 
    INCL_CD          , 
    FSMR_AMT         , 
    DETL_OBJ_TYP_CD  , 
    DETL_OBJ_ID      , 
    LAST_UPDT_PGM_NM , 
    LAST_UPDT_USER_NB, 
    LAST_UPDT_TS     , 
    FINEV_POST_TS     
    FROM rps.ksrb223_fesumc
     WHERE RBAT_BILL_PRD_NM = '$QPARM';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`                                                   >> $LOG_FILE
print " *** end of sql display."                                     >> $LOG_FILE

fi

#
# extract to file
#
if [[ $RETCODE == 0 ]]; then
   db2 -tvf $DCSQL                                                   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!!aborting script - error exporting table rps.ksrb223_fesumc "               >> $LOG_FILE
   fi
fi


#
# chmod it so db2 load can see it
#
if [[ $RETCODE == 0 ]]; then
   chmod 777 $DCDATA                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - cant chmod " $DCDATA
      print "aborting script - cant chmod " $DCDATA                  >> $LOG_FILE
   fi
fi


#
# load db2
#
if [[ $RETCODE == 0 ]]; then
   print " Starting db2 load " `date`
   print " Starting db2 load " `date`                                >> $LOG_FILE
   db2 "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.ksrb223_$YEAR nonrecoverable"   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading ksrb223_$YEAR with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
      print " WARNING - LOAD TERMINATE ACTION IS REQUIRED!!! "           >> $LOG_FILE
   fi
fi

################################################################
# 5) Archive KSRB300 data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT INV_QTR,
            REBATE_ID,
            RAC_ID,
            ELIG_STRUC_ID,
            LCM_ID_RPS,
            LCM_ID_ORIG,
            STMT_ID,
            RX_ALL_RBAT,
            RX_ALL_SUBM,
            RX_SRX_RBAT,
            RX_SRX_SUBM,
            RX_BRND_RBAT,
            RX_BRND_SUBM,
            RX_BRND_SRX_RBAT,
            RX_BRND_SRX_SUBM,
            RX_BLU_RBAT,
            RX_BLU_SUBM,
            RX_BLU_BRND_RBAT,
            RX_BLU_BRND_SUBM,
            FINEV_POST_TS
    FROM rps.f_claims
     WHERE INV_QTR = '$QPARM';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`                                                   >> $LOG_FILE
print " *** end of sql display."                                     >> $LOG_FILE

fi

#
# extract to file
#
if [[ $RETCODE == 0 ]]; then
   db2 -tvf $DCSQL                                                   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!!aborting script - error exporting table rps.f_claims "               >> $LOG_FILE
   fi
fi


#
# chmod it so db2 load can see it
#
if [[ $RETCODE == 0 ]]; then
   chmod 777 $DCDATA                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - cant chmod " $DCDATA
      print "aborting script - cant chmod " $DCDATA                  >> $LOG_FILE
   fi
fi


#
# load db2
#
if [[ $RETCODE == 0 ]]; then
   print " Starting db2 load " `date`
   print " Starting db2 load " `date`                                >> $LOG_FILE
   db2 "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.t_claims_$YEAR nonrecoverable"   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_claims_$YEAR with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
      print " WARNING - LOAD TERMINATE ACTION IS REQUIRED!!! "           >> $LOG_FILE
   fi
fi

################################################################
# 6) Archive KSRB250 data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT DSTR_ID,
BE_TYP_CD,  
BE_ID ,
RBAT_AFIL_CD,
RBAT_BILL_PRD_NM ,
CLCT_PRD_BEG_DT  ,
CLCT_PRD_END_DT  ,
OBJ_STAT_CD      ,
PMT_POST_CD      ,
PMT_RLS_DT       , 
AP_VEND_ID       ,
VOID_TRANS_CD    , 
PMT_AMT          ,
PMT_MTHD_CD      ,
DSTR_REM_AMT     , 
TRAN_TYP_CD      ,  
VOID_REF_DSTR_ID ,
CLNT_ADJ_REF_ID  , 
CMNT_LN1_TXT     ,  
CMNT_LN2_TXT     ,
LAST_UPDT_PGM_NM ,
LAST_UPDT_USER_NB,
LAST_UPDT_TS     ,
INSRT_TS        ,  
PRCS_NB         ,   
AP_CO_ID        ,    
FINEV_POST_TS   
    FROM rps.ksrb250_distr
     WHERE RBAT_BILL_PRD_NM = '$QPARM';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`                                                   >> $LOG_FILE
print " *** end of sql display."                                     >> $LOG_FILE

fi

#
# extract to file
#
if [[ $RETCODE == 0 ]]; then
   db2 -tvf $DCSQL                                                   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!!aborting script - error exporting table rps.ksrb250_distr "               >> $LOG_FILE
   fi
fi


#
# chmod it so db2 load can see it
#
if [[ $RETCODE == 0 ]]; then
   chmod 777 $DCDATA                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - cant chmod " $DCDATA
      print "aborting script - cant chmod " $DCDATA                  >> $LOG_FILE
   fi
fi


#
# load db2
#
if [[ $RETCODE == 0 ]]; then
   print " Starting db2 load " `date`
   print " Starting db2 load " `date`                                >> $LOG_FILE
   db2 "import from $DCDATA of del modified by coldel| insert into rps.KSRB250_DISTR_$YEAR "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading KSRB250_DISTR_$YEAR with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi


################################################################
# 7) Archive F_INV_LNAMT_SUM data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT PICO_ID     ,  
CONTRACT_ID        , 
NDC_ID             ,
REBATE_ID          ,     
INV_QTR            ,    
REVENUE_TYPE_CD    ,   
BILL_ORIG_AMT      ,  
BILL_ADJ_PQS_AMT   , 
BILL_NET_AMT       ,
PD_AMT             , 
NET_AMT 
    FROM rps.F_INV_LNAMT_SUM
     WHERE INV_QTR = '$QPARM';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`                                                   >> $LOG_FILE
print " *** end of sql display."                                     >> $LOG_FILE

fi

#
# extract to file
#
if [[ $RETCODE == 0 ]]; then
   db2 -tvf $DCSQL                                                   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!!aborting script - error exporting table rps.ksrb250_distr "               >> $LOG_FILE
   fi
fi


#
# chmod it so db2 load can see it
#
if [[ $RETCODE == 0 ]]; then
   chmod 777 $DCDATA                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - cant chmod " $DCDATA
      print "aborting script - cant chmod " $DCDATA                  >> $LOG_FILE
   fi
fi


#
# load db2
#
if [[ $RETCODE == 0 ]]; then
   print " Starting db2 load " `date`
   print " Starting db2 load " `date`                                >> $LOG_FILE
   db2 "import from $DCDATA of del modified by coldel| insert into rps.t_inv_lnamt_sum_$YEAR "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_inv_lnamt_sum_$YEAR with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi

################################################################
# 8) Archive TREBATE_ID_QTR data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT REBATE_ID  ,
INV_QTR           ,            
MSTR_CLIENT_NAM   ,           
REBATE_ID_NAME    ,          
MODEL_TYPE_DESC   ,         
COMPANY           ,        
VENDOR            ,       
PAY_TIMING        ,      
PAY_SCHEDULE      ,     
PAY_METHOD_DESC   ,    
SAP_PAY_TYPE_DESC ,   
CREDIT_HOLD       ,  
MODEL_EFF_DT      , 
MODEL_TERM_DT    ,  
MODEL_EFF_YYYYMM   ,           
MODEL_TERM_YYYYMM  ,          
MODEL_EFF_QTR      ,         
MODEL_TERM_QTR     ,        
FAF_NBR            ,       
QL_CLIENT_NBR      ,      
PSI_REBATE_ID      ,     
CLIENT_TYPE_DESC   ,    
PROCESSOR_DESC     ,    
PROCESSOR_SORT     ,  
CLIENT_TYPE_SORT   , 
SAP_PAY_TYPE_SORT  ,           
PAY_METHOD_SORT    ,          
MODEL_TYPE_SORT    ,         
PSI_MASTER_ID      ,        
REBATE_INV_EFF_DT  ,       
REBATE_INV_TERM_DT       
    FROM rps.L_rebate_id_qtr
     WHERE INV_QTR = '$QPARM';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`                                                   >> $LOG_FILE
print " *** end of sql display."                                     >> $LOG_FILE

fi

#
# extract to file
#
if [[ $RETCODE == 0 ]]; then
   db2 -tvf $DCSQL                                                   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!!aborting script - error exporting table rps.L_rebate_id_qtr "               >> $LOG_FILE
   fi
fi


#
# chmod it so db2 load can see it
#
if [[ $RETCODE == 0 ]]; then
   chmod 777 $DCDATA                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - cant chmod " $DCDATA
      print "aborting script - cant chmod " $DCDATA                  >> $LOG_FILE
   fi
fi


#
# load db2
#
if [[ $RETCODE == 0 ]]; then
   print " Starting db2 load " `date`
   print " Starting db2 load " `date`                                >> $LOG_FILE
   db2 "import from $DCDATA of del modified by coldel| insert into rps.t_rebate_id_qtr_$YEAR "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_rebate_id_qtr_$YEAR with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi

################################################################
# 9) Purge table KSRB103_INV_LNAMT
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB103 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb103.$QPARM of del select * from rps.ksrb103_inv_lnamt where RBAT_BILL_YR_DT='$YEAR' and RBAT_BILL_QTR_DT='$QTR'"

   sqml --YEAR $YEAR --QPID $QTR $XML_PATH/dm_purge_ksrb103.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB103 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi


################################################################
# 10) Purge table KSRB222_FESUMP
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB222 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb222.$QPARM of del select * from rps.ksrb222_fesump where RBAT_BILL_PRD_NM='$QPARM' "

   sqml --QPARM $QPARM  $XML_PATH/dm_purge_ksrb222.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB222 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi



################################################################
# 11) Purge table KSRB223_FESUMC
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB223 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb223.$QPARM of del select * from rps.ksrb223_fesumc where RBAT_BILL_PRD_NM='$QPARM' "

   sqml --QPARM $QPARM  $XML_PATH/dm_purge_ksrb223.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB223 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi



################################################################
# 12) Purge table KSRB250_DISTR
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB250 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb250.$QPARM of del select * from rps.ksrb250_distr where RBAT_BILL_PRD_NM='$QPARM' "

   sqml --QPARM $QPARM  $XML_PATH/dm_purge_ksrb250.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB250 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi




################################################################
# 13) Purge table KSRB300
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB300 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb300.$QPARM of del select * from rps.tapc_lcm_summary where INV_CCYY='$YEAR' and INV_QTR='$QTR' "

   sqml --YEAR $YEAR --QPID $QTR $XML_PATH/dm_purge_ksrb300.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB300 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi



################################################################
# 14) disconnect from udb
################################################################
db2 -stvx connect reset                                                >> $LOG_FILE 
db2 -stvx quit                                                         >> $LOG_FILE 




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

 rm -f $DBMSG_FILE* 
 rm -f $DCDATA

print "return_code =" $RETCODE
exit $RETCODE
