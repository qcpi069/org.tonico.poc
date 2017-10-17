#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR1000_KS_9110J_RPS_archive.ksh
# Title         : RPS Archive
# Description   : This script will run before the RPS purge job.
#		  For the quarter which is to be purged out of 
#		  Payments transactional tables, this job makes a local
#                 copy of the quarter in datamart.
#
#                 the following tables will be impacted:
#                       rps.ksrb103_inv_lnamt
#			rps.ksrb222_fesump
#			rps.ksrb223_fesumc
#			rps.ksrb250_distr
#			rps.tapc_lcm_summary
#
#                       $MF_SCHEMA.ksrb106_pmt
#                       $MF_SCHEMA.ksrb108_pmt_actdtl
#                       $MF_SCHEMA.ksrb110_pmt_ln
#                       $MF_SCHEMA.ksrb111_pmt_tran
#                       $MF_SCHEMA.ksrb112_rbp
#                       $MF_SCHEMA.ksrb210_clt_adj
#                       rps.L_Rac_QTR
#		  The purged quarter summary data will be copied to 
#		  history tables:
#			rps.t_inv_lnamt_sum_hist
#			rps.t_sl_client_pico_sum_hist
#			rps.ksrb223_hist
#			rps.t_sl_client_sum_hist
#			rps.ksrb250_hist
#			rps.t_claims_hist
#
#                       rps.ksrb106_hist
#                       rps.ksrb108_hist
#                       rps.ksrb110_hist
#                       rps.ksrb111_hist
#                       rps.ksrb112_hist
#                       rps.ksrb210_hist
#
#			rps.t_rebate_id_qtr_hist
#			rps.t_rac_qtr_hist
#
#		  This script will be kicked off on MVS side.
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
# 04-03-08   qcpi03o     Initial Creation.
# 11-05-11   qcpi03o     Cash Recon change - added table ksrb243
#                            fix L_rebate_id_qtr, L_rac_qtr
# 18/08/2012 qcpi0rb     Rebate Atena phase 2 changes to include AP_CO_CD 
#                            in the archive of KSRB210_HIST
# 07-31-14   qcpy987     Include AP_VEND_ID in the archive of KSRB210_HIST
# 08-10-17   qcpy987     ITPR022390 Add Coalition reporting columns to
#                            T_REBATE_ID_QTR_HIST 
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSOR1000_KS_9110J_RPS_archive.ksh
JOB=RPS_KSOR1000_KS_9110J_RPS_archive
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0
DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log
DCDATA=$TMP_PATH/ks9100.tmp
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

QPARM=$YEAR"Q"$QTR
QTR="Q"$QTR
print ' qparm is ' $QPARM	>> $LOG_FILE
print ' year is ' $YEAR		>> $LOG_FILE
print ' quarter is ' $QTR	>> $LOG_FILE

else
   export RETCODE=12
   print "aborting script - required parameter not supplied " 
   print "aborting script - required parameter not supplied "     >> $LOG_FILE  
fi

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
# 2) Archive KSRB103_Inv_lnamt summary data for the purged quarter
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
print `cat $DCSQL`      
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
   db2 "import from $DCDATA of del modified by coldel| insert into rps.t_inv_lnamt_sum_hist "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_inv_lnamt_sum_$YEAR with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi

################################################################
# 3) Archive KSRB222 summary data for the purged quarter
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
print `cat $DCSQL`     
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
	echo "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.t_sl_client_pico_sum_hist nonrecoverable"   >> $LOG_FILE

   db2 "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.t_sl_client_pico_sum_hist nonrecoverable"   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_sl_client_pico_sum_$YEAR with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
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
print `cat $DCSQL`      
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
   db2 "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.ksrb223_hist nonrecoverable"   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading ksrb223_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
      print " WARNING - LOAD TERMINATE ACTION IS REQUIRED!!! "           >> $LOG_FILE
   fi
fi

################################################################
# 5) Archive KSRB223 summary data for the purged quarter
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
print `cat $DCSQL`      
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
   db2 "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.t_sl_client_sum_hist nonrecoverable"   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_sl_client_sum_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
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
   db2 "import from $DCDATA of del modified by coldel| insert into rps.KSRB250_DISTR_hist "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading KSRB250_DISTR_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi


################################################################
# 7) Archive KSRB300 data for the purged quarter
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
print `cat $DCSQL`          
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
   db2 "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.t_claims_hist nonrecoverable"   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_claims_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
      print " WARNING - LOAD TERMINATE ACTION IS REQUIRED!!! "           >> $LOG_FILE
   fi
fi

################################################################
# 8) Archive KSRB106_PMT data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT RBAT_PMT_NB     ,  
PICO_ID_NB             ,  
CTRC_ID_NB             ,   
RBAT_BILL_YR_DT        ,
RBAT_BILL_QTR_DT       , 
RBAT_NEXT_TRAN_NB      ,  
PMT_ORIG_AMT           ,   
PMT_TOL_AMT            ,    
PMT_RFND_AMT           ,     
PMT_XFER_AMT           ,      
NET_AMT                , 
PMT_ALOC_AMT           ,  
PMT_UALOC_AMT          ,   
PMT_APRV_AMT           ,    
PMT_PEND_AMT           ,     
PMT_XFER_PEND_AMT      ,      
PMT_RFND_PEND_AMT      ,
RBAT_PMT_DT            , 
INSRT_TS               ,  
LAST_UPDT_USER_NB      ,   
LAST_UPDT_TS           
    FROM $MF_SCHEMA.KSRB106_PMT
     WHERE RBAT_BILL_YR_DT = '$YEAR' and RBAT_BILL_QTR_DT='$QTR';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`       
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
      print "!!!aborting script - error exporting table KSRB106_PMT "               >> $LOG_FILE
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
   db2 "import from $DCDATA of del modified by coldel| insert into rps.ksrb106_hist "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading ksrb106_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi

################################################################
# 9) Archive KSRB108_PMT_ACTDTL data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT 
RBAT_BILL_YR_DT||RBAT_BILL_QTR_DT,
a.RBAT_PMT_NB            ,    
a.RBAT_PMT_TRAN_NB       ,     
a.RBAT_REV_TYPE_CD       ,      
a.MKSR_FILE_NME          ,       
a.NDC_NB                 ,  
a.CPA_RPT_CLNT_NB        ,   
a.NET_AMT                ,    
a.INSRT_TS               ,     
a.LAST_UPDT_USER_NB      ,      
a.LAST_UPDT_TS           ,       
a.LAST_UPDT_PGM_NM        
    FROM $MF_SCHEMA.KSRB108_PMT_ACTDTL a, $MF_SCHEMA.KSRB106_PMT b
     WHERE A.RBAT_PMT_NB=B.RBAT_PMT_NB and
	RBAT_BILL_YR_DT = '$YEAR' and RBAT_BILL_QTR_DT='$QTR';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`            
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
      print "!!!aborting script - error exporting table KSRB108_PMT_ACTDTL "               >> $LOG_FILE
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
   db2 "import from $DCDATA of del modified by coldel| insert into rps.ksrb108_hist "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading ksrb108_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi

################################################################
# 10) Archive KSRB110_PMT_LN data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT 
RBAT_BILL_YR_DT||RBAT_BILL_QTR_DT,
a.RBAT_PMT_NB            ,    
a.RBAT_REV_TYPE_CD       ,     
a.MKSR_FILE_NME       ,      
a.NDC_NB                 ,  
a.CPA_RPT_CLNT_NB        ,   
a.NET_AMT                ,    
a.INSRT_TS               ,     
a.LAST_UPDT_USER_NB      ,      
a.LAST_UPDT_TS           ,       
a.LAST_UPDT_PGM_NM        

    FROM $MF_SCHEMA.KSRB110_PMT_LN a, $MF_SCHEMA.KSRB106_PMT b
     WHERE A.RBAT_PMT_NB=B.RBAT_PMT_NB and
	RBAT_BILL_YR_DT = '$YEAR' and RBAT_BILL_QTR_DT='$QTR';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`      
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
      print "!!!aborting script - error exporting table KSRB110_PMT_LN "               >> $LOG_FILE
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
   db2 "import from $DCDATA of del modified by coldel| insert into rps.ksrb110_hist "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading ksrb110_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi

################################################################
# 11) Archive KSRB111_PMT_TRAN data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT 
RBAT_BILL_YR_DT||RBAT_BILL_QTR_DT,
a.RBAT_PMT_NB             , 
a.RBAT_PMT_TRAN_NB        ,  
a.RBAT_PMT_TRAN_CD        ,
a.REF_PMT_NB              , 
a.REF_PMT_TRAN_NB         ,  
a.REF_INV_TRAN_NB         ,   
a.RBAT_PMT_STAT_CD        ,    
a.RBAT_PMT_TRAN_DT        ,     
a.NET_AMT                 , 
a.RBAT_WRITE_OFF_CD       ,  
a.INSRT_TS                ,   
a.LAST_UPDT_USER_NB       ,    
a.LAST_UPDT_TS            , 
a.LAST_UPDT_PGM_NM          

    FROM $MF_SCHEMA.KSRB111_PMT_TRAN a, $MF_SCHEMA.KSRB106_PMT b
     WHERE A.RBAT_PMT_NB=B.RBAT_PMT_NB and
	RBAT_BILL_YR_DT = '$YEAR' and RBAT_BILL_QTR_DT='$QTR';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`         
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
      print "!!!aborting script - error exporting table KSRB111_PMT_TRAN "               >> $LOG_FILE
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
   db2 "import from $DCDATA of del modified by coldel| insert into rps.ksrb111_hist "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading ksrb111_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi

################################################################
# 12) Archive KSRB112_RBP data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT 
RBAT_AFIL_CD                , 
RBAT_BILL_YR_DT             ,
RBAT_BILL_QTR_DT            ,
BILL_ORIG_AMT               , 
BILL_ADJ_AMT                ,  
BILL_NET_AMT                , 
PD_AMT                      ,
NET_AMT                     ,  
FEE_AMT                     , 
BILL_PCS_ORIG_AMT           ,
BILL_OTHR_ORIG_AMT          ,  
BILL_PCS_ADJ_AMT            , 
BILL_RAC_ADJ_AMT            ,
BILL_OTHR_ADJ_AMT           ,  
BILL_PCS_NET_AMT            , 
BILL_RAC_NET_AMT            ,
BILL_OTHR_NET_AMT           ,  
PD_PCS_AMT                  , 
PD_RAC_AMT                  ,
PD_OTHR_AMT                 ,  
ADV_ORIG_AMT                , 
ADV_RCVR_AMT                ,
ADV_NET_AMT                 ,  
RBLL_PCS_ORIG_AMT           , 
RBLL_RAC_ORIG_AMT           ,
RBLL_OTHR_ORIG_AMT          ,  
RBLL_PCS_ADJ_AMT            , 
RBLL_RAC_ADJ_AMT            ,
RBLL_OTHR_ADJ_AMT           ,  
RBLL_PCS_NET_AMT            , 
RBLL_RAC_NET_AMT            ,
RBLL_OTHR_NET_AMT           ,  
RND_PD_PCS_AMT              , 
RND_PD_RAC_AMT              ,
RND_PD_OTHR_AMT             ,  
RBLL_ORIG_AMT               , 
RND_RBLL_ORIG_AMT           ,
RBLL_ADJ_AMT                ,  
RND_RBLL_ADJ_AMT            , 
RBLL_NET_AMT                ,
RND_RBLL_NET_AMT            ,  
RND_PD_AMT                  , 
RND_NET_AMT                 ,
RSPL_BILL_ORIG_AMT          ,  
RSPL_BILL_ADJ_AMT           , 
RSPL_BILL_NET_AMT           ,
RSPL_PD_AMT                 ,  
RND_RND_PD_AMT              , 
BILL_PCS_SPLT_PCT           ,
BILL_RAC_SPLT_PCT           ,  
BILL_OTHR_SPLT_PCT          , 
PD_PCS_SPLT_PCT             ,
PD_RAC_SPLT_PCT             ,
PD_OTHR_SPLT_PCT            ,  
RBAT_NEXT_TRAN_NB           , 
INSRT_TS                    ,
LAST_UPDT_USER_NB           ,  
LAST_UPDT_TS                , 
BILL_RAC_ORIG_AMT           ,
RAC_SUBM_CLM_CNT            ,  
RBAT_CLM_CNT                , 
RBAT_ID                     ,
BILL_ACS_PCT                ,  
BILL_ADMN_ORIG_AMT          , 
BILL_ADMN_CO_AMT            ,
BILL_ADMN_RAC_AMT           ,  
BILL_ADMN_OTHR_AMT          , 
BILL_AOS_PCT                ,
BILL_ARS_PCT                ,  
PD_ACS_PCT                  , 
PD_ADMN_AMT                 ,
PD_ADMN_CO_AMT              ,  
PD_ADMN_OTHR_AMT            , 
PD_ADMN_RAC_AMT             ,
PD_AOS_PCT                  ,  
PD_ARS_PCT                  , 
RBLL_ACN_AMT                ,
RBLL_ADMN_CO_AMT            ,  
RBLL_ADMN_OTHR_AMT          , 
RBLL_ADMN_RAC_AMT           ,
RBLL_AON_AMT                ,  
RBLL_ARN_AMT                , 
RND_PAC_AMT                 ,  
RND_PAO_AMT                 , 
RND_PAR_AMT                 ,  
RBAT_BRND_CLM_CNT           , 
SUBM_BRND_CLM_CNT            
,BILL_ADMN_ADJ_AMT
,BILL_CO_ADMN_ADJ_AMT
,BILL_RAC_ADMN_ADJ_AMT

    FROM $MF_SCHEMA.KSRB112_RBP
     WHERE 
	RBAT_BILL_YR_DT = '$YEAR' and RBAT_BILL_QTR_DT='$QTR';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`              
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
      print "!!!aborting script - error exporting table KSRB112_RBP "               >> $LOG_FILE
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
   db2 "import from $DCDATA of del modified by coldel| insert into rps.ksrb112_hist "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading ksrb112_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi

################################################################
# 13) Archive KSRB210_CLT_ADJ data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT 
CLNT_ADJ_ID            ,       
BE_TYP_CD              ,      
BE_ID                  ,     
RBAT_BILL_PRD_NM       ,    
RBAT_AFIL_CD           ,   
OBJ_STAT_CD            ,  
ADJ_AMT                ,       
PMT_RLS_DT             ,      
CMNT_LN1_TXT           ,     
CMNT_LN2_TXT           ,    
CMNT_LN3_TXT           ,   
TRAN_TYP_CD            ,  
LAST_UPDT_PGM_NM       ,     
LAST_UPDT_USER_NB      ,    
LAST_UPDT_TS           ,   
INSRT_TS               ,  
PRCS_NB                ,
AP_CO_CD               ,
AP_VEND_ID  

    FROM $MF_SCHEMA.KSRB210_CLT_ADJ
     WHERE RBAT_BILL_PRD_NM = '$QPARM';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`      
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
      print "!!!aborting script - error exporting table KSRB210_CLT_ADJ "               >> $LOG_FILE
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
   db2 "import from $DCDATA of del modified by coldel| insert into rps.ksrb210_hist "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading ksrb210_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi

################################################################
# 14) Archive KSRB243 data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then 
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT TRAN_ID,
	    PRCS_NB,
            DB2_PART_NB,
            RBAT_BILL_PRD_NM,
            TRAN_TYP_CD,
            PICO_ID_NB,
            CTRC_ID_NB,
            NDC_NB,
            RBAT_ID,
            CG_NB,
            RAC_NB,
            RECN_GID,
            ACCS_RBAT_TOT_AMT,
            MKSR_RBAT_TOT_AMT,
            ADMN_FEE_TOT_AMT,
            INSRT_USER_ID,
            INSRT_TS,
            UPDT_USER_ID,
            UPDT_TS
    FROM rps.ksrb243_recn_summ
     WHERE RBAT_BILL_PRD_NM = '$QPARM'
;
ZZEOF


print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`     
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
      print "!!!aborting script - error exporting table rps.ksrb243_recn_summ "               >> $LOG_FILE
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
	echo "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.ksrb243_hist nonrecoverable"   >> $LOG_FILE

   db2 "load from $DCDATA of del modified by coldel| messages $DBMSG_FILE  insert into rps.ksrb243_hist nonrecoverable"   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading ksrb243_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
      print " WARNING - LOAD TERMINATE ACTION IS REQUIRED!!! "           >> $LOG_FILE
   fi
fi


################################################################
# 15) Archive TREBATE_ID_QTR data for the purged quarter
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
rtrim(VENDOR)      ,       
PAY_TIMING        ,      
PAY_SCHEDULE      ,     
PAY_METHOD_DESC   ,    
SAP_PAY_TYPE_DESC ,   
rtrim(CREDIT_HOLD)       ,  
MODEL_EFF_DT      , 
MODEL_TERM_DT    ,  
MODEL_EFF_YYYYMM   ,           
MODEL_TERM_YYYYMM  ,          
MODEL_EFF_QTR      ,         
MODEL_TERM_QTR     ,        
FAF_NBR            ,       
0       ,      
0      ,     
CLIENT_TYPE_DESC   ,    
'n/a'     ,    
0     ,  
0   , 
SAP_PAY_TYPE_SORT  ,           
PAY_METHOD_SORT    ,          
MODEL_TYPE_SORT    ,         
0       ,        
REBATE_INV_EFF_DT  ,       
REBATE_INV_TERM_DT ,      
ANN_RECN_IN,
RECN_METHOD_CD,
HOLD_COL_RECN_IN,
RECN_FREQ_CD,
RECN_TM_CD,
RECN_PAY_AFTR_CD,
ALT_COAL_RPT_IN,
RECN_EXCP_IN
    FROM rps.L_rebate_id_qtr
     WHERE INV_QTR = '$QPARM';
ZZEOF


print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`       
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
   db2 "import from $DCDATA of del modified by coldel| insert into rps.t_rebate_id_qtr_hist "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_rebate_id_qtr_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi

################################################################
# 16) Archive L_RAC_QTR data for the purged quarter
################################################################

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE 
SELECT 
RAC_ID               ,    
INV_QTR              ,     
coalesce(RAC_TYPE_DESC,'NA')        ,      
0            ,       
REBATE_ID            ,        
'n/a'       ,         
REBATE_TYPE_DESC     , 
coalesce(RAC_EFF_DT,'01/01/2007')           ,  
RAC_TERM_DT          ,   
coalesce(RAC_EFF_MONTH,'200701')        ,    
RAC_TERM_MONTH       ,     
RAC_EFF_QTR          ,      
RAC_TERM_QTR                 
    FROM rps.L_rac_qtr
     WHERE INV_QTR = '$QPARM';
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE
print `cat $DCSQL`       
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
      print "!!!aborting script - error exporting table rps.L_rac_qtr "               >> $LOG_FILE
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
   db2 "import from $DCDATA of del modified by coldel| insert into rps.t_rac_qtr_hist "   >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error loading t_rac_hist with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE
   fi
fi



################################################################
# zz) disconnect from udb
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
 rm -f $DCSQL

print "return_code =" $RETCODE
exit $RETCODE


