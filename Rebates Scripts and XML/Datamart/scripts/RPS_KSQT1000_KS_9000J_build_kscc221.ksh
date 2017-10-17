#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSQT1000_KS_9000J_build_kscc221.ksh
# Title         : expand client Hierarchy associate down to detail level
#                    for the current APC quarter
# Description   : This script will build client hierarchy assoc at detail level
#                       using the following CR tables as source
#			client_reg.CRT_EXTL_HRCY
#			client_reg.CRT_CLNT_EXTL_HRCY_ASSC
#			client_reg.crt_prd
#			
#	           Result saved in datamart local table
#			client_reg.crt_clnt_hrcy_qtr_dtl			
#
#                  After build the datamart local table
#                  The current quarter data will be inserted into Payments table
#		        dbap1.kscc221_clnt_hrcy_qtr_dtl
#			added field partition number -
#			source from Payments table KSRB101.DB2_PART_NB 
#
#
#		  This script will be kicked off by MVS job 
# 
# Abends        : 
#                                 
# Parameters    : Period Id (required), eg  2009Q1
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09-24-09   qcpi03o     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSQT1000_KS_9000J_build_kscc221.ksh
JOB=ks9000j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0


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
# 2) connect to udb
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
# 3) insert clnt hrcy assc detail for the current quarter
################################################################
if [[ $RETCODE == 0 ]]; then
   print "insert $QPARM into datamart local table "`date`              
   print "insert $QPARM into datamart local table "`date`                               >> $LOG_FILE

	db2 -px "delete from client_reg.crt_clnt_hrcy_qtr_dtl where PRD_CYQ_Q_CD='$QPARM' " 	  >> $LOG_FILE

# send Payments return code to release the hold
print "return_code =" $RETCODE


   if [[ $RETCODE == 0 ]]; then 
   	PRD_FILEP=$TMP_PATH/ks9000j.prd
	db2 -px "select PRD_ID from client_reg.crt_prd where PRD_CYQ_Q_CD='$QPARM' and PRD_ID like 'M%' " >$PRD_FILEP
	RETCODE=$?
   fi

   if [[ $RETCODE == 0 ]]; then 
	   while read PRDID; do
   		print "building $PRDID into datamart table client_reg.crt_clnt_hrcy_qtr_dtl "`date`              
   		print "building $PRDID into datamart table client_reg.crt_clnt_hrcy_qtr_dtl "`date`       >> $LOG_FILE

   		sqml --PRDID $PRDID $XML_PATH/dm_refresh_build_kscc221.xml				  >> $LOG_FILE
   		RETCODE=$?
  	 done <$PRD_FILEP
   fi

   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - error insert into crt_clnt_hrcy_qtr_dtl " 
      print "!!! terminating script - error insert into crt_clnt_hrcy_qtr_dtl "        >> $LOG_FILE  
   fi
fi


################################################################
# 5) send the current quarter data to Payments kscc221
################################################################

if [[ $RETCODE == 0 ]]; then

   PART_NB=`db2 -x "select DB2_PART_NB from $MF_SCHEMA.KSRB101_QTR_CNTL where RBAT_BILL_YR_DT||RBAT_BILL_QTR_DT='$QPARM'"`


   print "insert into Payments table kscc221 for $QPARM in partition $PART_NB "`date`              
   print "insert into Payments table kscc221 for $QPARM in partition $PART_NB "`date`    >> $LOG_FILE
    sqml --PART_NB $PART_NB --QPARM $QPARM $XML_PATH/mf_refresh_kscc221.xml		>> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - error insert into kscc221 " 
      print "!!! terminating script - error insert into kscc221 "        >> $LOG_FILE  
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

print "return_code =" $RETCODE
exit $RETCODE
