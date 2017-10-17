#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSDY7000_KS_7200J_mf_refresh_client.ksh
# Title         : Refresh Mainframe Payment System Client table KSCC202
#
# Description   : This script will refresh the mainframe payment system   
#                 client table ( KSCC202 ) from Oracle Silver client reg.
# 
# Abends        : If select count does not match insert results then set bad 
#                 return code.
#                 
#
# Parameters    : None 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 12-01-05   qcpi768     Initial Creation.
# 06-22-15   z112009	 ITPR011275 - FTP Remediation. Sends the trigger file 
#			 to webtransport on completion of process, inturn which 
#			 will be sent to FEDB
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPTNAME=$(basename "$0")
SCRIPT=$(basename $0 | sed -e 's/.ksh$//')
JOB=ks7200j

LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

DAT_FILE=fedbtrig.dat

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`						> $LOG_FILE

#################################################################
# check status of source database before proceeding
#################################################################
sqml $XML_PATH/dm_refresh_chkstat.xml							>> $LOG_FILE
export RETCODE=$?
print "sqml retcode from dm_refresh_chkstat was " $RETCODE
print "sqml retcode from dm_refresh_chkstat was " $RETCODE				>> $LOG_FILE
if [[ $RETCODE != 0 ]]; then 
   print " !!!!!!!!!!!!!!!!!!!!!!!!! "							>> $LOG_FILE
   print " CLIENT REG DATABASE IS UNAVAILABLE OR INACCESSIBLE "				>> $LOG_FILE
   print " !!!!!!!!!!!!!!!!!!!!!!!!! "							>> $LOG_FILE
   tail sqml.log									>> $LOG_FILE
fi

#################################################################
# refresh KSCC202
#################################################################
if [[ $RETCODE == 0 ]]; then 
   sqml $XML_PATH/mf_refresh_kscc202.xml						>> $LOG_FILE
   export RETCODE=$?
   print "sqml retcode from mf_refresh_kscc202.xml was " $RETCODE
   print "sqml retcode from mf_refresh_kscc202.xml was " $RETCODE			>> $LOG_FILE
fi


#################################################################
# Sftp a trigger file to webtransport. EDI sends the trigger to FEDB knows the refresh process is done
# PCS.P.FEEXD020.POSRBATE.REFRESH.TRIG
#################################################################
if [[ $RETCODE == 0 ]]; then  

   print ' KSCC202 client refresh is completed '`date`  > $TMP_PATH/$DAT_FILE
   print `date +"%D %r %Z"` 'SFTP starting '                                            >> $LOG_FILE

Common_SFTP_Process.ksh -p $SCRIPTNAME		          	       	
RETCODE=$?
if [[ $RETCODE == 0 ]]; then

	print "Completed the SFTP"							>> $LOG_FILE
	print `date +"%D %r %Z"`							>> $LOG_FILE
  else 
	print "Error SFTP the trigger file to webtransport" $RETCODE			>> $LOG_FILE
	exit $RETCODE
  fi
fi

 
#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "						>> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`				>> $LOG_FILE 

#################################################################
# cleanup from successful run
#################################################################
mv $LOG_FILE       $LOG_ARCH_PATH/ 

rm -f $TMP_PATH/$DAT_FILE

print "return_code =" $RETCODE
exit $RETCODE
