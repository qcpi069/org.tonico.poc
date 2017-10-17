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

SCRIPT=RPS_KSOR9400_KS_9450J_ftp_rebated.ksh
JOB=ks9450j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0
REBNM=rbate_RIOR4500_RI_4500J_APC_rbated_clm_extract
REBFILE=$REBNM.zip
REBDATA=$TMP_PATH/$REBNM.dat

FTP_PATH=/staging/apps/rebates/prod/output/apc
FTP_REB_IP=dmadom4

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

################################################################
# 3) get the rebated claim data file from Rebates
################################################################
if [[ $RETCODE == 0 ]]; then    
   print " doing ftp now ........................"
   FTP_CMD_FILE=$TMP_PATH"/"$JOB"_ftpcmds.txt"
   cat > $FTP_CMD_FILE << 99EOFSQLTEXT99
binary
cd $FTP_PATH
get $REBFILE    $TMP_PATH/$REBFILE   
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
# 5) unzip rebated claims
################################################################
if [[ $RETCODE == 0 ]]; then   
    gzip -d -c -v $TMP_PATH/$REBFILE > $REBDATA
    export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print `date` ' !! unzip/sort of '  $TMP_PATH/$REBFILE  ' returned code ' $RETCODE 
      print `date` ' !! unzip/sort of '  $TMP_PATH/$REBFILE  ' returned code ' $RETCODE ' terminating script '   >> $LOG_FILE
      export RETCODE=12
   fi
fi
#    delete the zip file to reclaim space
if [[ $RETCODE == 0 ]]; then    
    print `date` " unzip/sort of " $TMP_PATH/$REBFILE " finished okay "
    print `date` " unzip/sort of " $TMP_PATH/$REBFILE " finished okay " >> $LOG_FILE
    rm -f $TMP_PATH/$REBFILE 
fi

print " all zipping/sorting has been executed " `date`


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

rm -f $FTP_CMD_FILE

print "return_code =" $RETCODE
exit $RETCODE
