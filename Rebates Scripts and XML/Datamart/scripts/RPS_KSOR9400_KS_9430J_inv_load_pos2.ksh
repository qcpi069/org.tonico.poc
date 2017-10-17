#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_9430J_inv_load_pos2.ksh
# Title         : Invoice Load - RTMD RAC Reassignment Part2
# Description   : This script will use an RTMD extract received from the mainframe 
#                 populated with RACs to update the POS claim details for a quarter.
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
# 04-19-06   is89501     Initial Creation.
# 02-25-10   qcpi03o     export the return code after the successful FTP
#                           to release hold on MVS job
# 06-22-15   z112009	 ITPR011275 - FTP Remediation - MVS will place the 
#			 data file in Unix. FTP to MVS part is removed.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSOR9400_KS_9430J_inv_load_pos2.ksh
JOB=ks9430j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0

DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log
DCSQL=
OUT_DATA_CNT=0
IN_DATA_CNT=0
TCNT1=0
TCNT2=0
JAVAPGM1=jt004rac.class

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



DATAFILE=$INPUT_PATH"/"$JOB"_posrerac.in"
SENTFILE=$INPUT_PATH"/ks9420j_posrerac.out"


################################################################
# verify that the file was received from the mainframe
################################################################
if [[ $RETCODE == 0 ]]; then    
   if [[ ! -r $DATAFILE ]] ; then
      print "aborting script - required file " $DATAFILE " is not present " 
      print "aborting script - required file " $DATAFILE " is not present "    >> $LOG_FILE  
      export RETCODE=12
   fi
fi


################################################################
# check that the sent and returned file counts match
################################################################
if [[ $RETCODE == 0 ]]; then    
   OUT_DATA_CNT=$(wc -l < $SENTFILE)
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $SENTFILE  
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $SENTFILE  >> $LOG_FILE
   fi
fi
if [[ $RETCODE == 0 ]]; then    
   IN_DATA_CNT=$(wc -l < $DATAFILE)
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $DATAFILE 
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $DATAFILE  >> $LOG_FILE
   fi
fi
if [[ $RETCODE == 0 ]]; then    
   if  [[ $IN_DATA_CNT == $OUT_DATA_CNT ]]; then
      print " file counts "  $IN_DATA_CNT " and " $OUT_DATA_CNT " match okay "
      print " file counts "  $IN_DATA_CNT " and " $OUT_DATA_CNT " match okay " >> $LOG_FILE

#### export return code to release hold on MVS job
print "return_code =" $RETCODE

   else
      print " file counts "  $IN_DATA_CNT " and " $OUT_DATA_CNT " do not match!!! terminating script!"
      print " file counts "  $IN_DATA_CNT " and " $OUT_DATA_CNT " do not match!!! terminating script! " >> $LOG_FILE
      export RETCODE=12
   fi
fi


################################################################
# connect to udb
################################################################
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - cant connect to udb " 
      print "!!! terminating script - cant connect to udb "            >> $LOG_FILE  
   fi
fi


# wip - out because it blows the logspace
####################################################################
#  blank out the old RACs and XREFs to make sure they get reassigned
####################################################################
#if [[ $RETCODE == 0 ]]; then    
#      print `date`" clearing old RAC and XREfs for RTMD quarter "$QPARM
#      print `date`" clearing old RAC and XREfs for RTMD quarter "$QPARM  >> $LOG_FILE
#      db2 -stvx "update rps.vpos_claims set RAC = ' ', XR0007_CG_NB =' ' where period_id = '"$QPARM"' "  >> $LOG_FILE 
#      export RETCODE=$?
#      if [[ $RETCODE != 0 ]]; then     
#	print `date`" db2 error clearing old RAC and XREfs for RTMD quarter - retcode: "$RETCODE
#	print `date`" db2 error clearing old RAC and XREfs for RTMD quarter - retcode: "$RETCODE   >> $LOG_FILE
#      else
#      	print `date`" db2 clearing of old RAC and XREfs for RTMD quarter  was successful "
#	print `date`" db2 clearing of old RAC and XREfs for RTMD quarter  was successful "  >> $LOG_FILE
#      fi
#fi 
# wip - out because previous setep blows the logspace
####################################################################
#  check the count of blank racs and xrefs equals the file count
####################################################################
#if [[ $RETCODE == 77 ]]; then    
#      print `date`" selecting count of blank RAC and XREfs for RTMD quarter "$QPARM
#      print `date`" selecting count of blank RAC and XREfs for RTMD quarter "$QPARM  >> $LOG_FILE
#      export TCNT1=`db2 -x "select count(*) from rps.vpos_claims where period_id = '"$QPARM"' and RAC = ' ' and XR0007_CG_NB =' ' " ` 
#      export RETCODE=$?
#      if [[ $RETCODE != 0 ]]; then     
#	print `date`" db2 error selecting count of blank RACs and XREfs for RTMD quarter - retcode: "$RETCODE
#	print `date`" db2 error selecting count of blank RACs and XREfs for RTMD quarter - retcode: "$RETCODE   >> $LOG_FILE
#      else
#      	print `date`" db2 select count of blank RAC and XREfs for RTMD quarter  was  " $TCNT1
#	print `date`" db2 select count of blank RAC and XREfs for RTMD quarter  was  " $TCNT1  >> $LOG_FILE
#      fi
#fi 
#if [[ $RETCODE == 77 ]]; then    
#   if  [[ $IN_DATA_CNT == $TCNT1 ]]; then
#      print " blank test counts "  $IN_DATA_CNT " and " $TCNT1 " match okay "
#      print " blank test counts "  $IN_DATA_CNT " and " $TCNT1 " match okay " >> $LOG_FILE
#   else
#      print " blank test counts "  $IN_DATA_CNT " and " $TCNT1 " do not match!!! terminating script!"
#      print " blank test counts "  $IN_DATA_CNT " and " $TCNT1 " do not match!!! terminating script! " >> $LOG_FILE
#      export RETCODE=12
#   fi
#fi


####################################################################
#  update rtmd using the received file
####################################################################
if [[ $RETCODE == 0 ]]; then    
   print `date`" running Java program "
   print `date`" running Java program "  >> $LOG_FILE
   java $JAVA_XPATH/$JAVAPGM1 $DATAFILE $QPARM $DATABASE $CONNECT_PWD   >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** ' $JAVAPGM1 ' returned ' $RETCODE ' processing ' $DATAFILE  
     print `date` ' *** ' $JAVAPGM1 ' returned ' $RETCODE ' processing ' $DATAFILE  >> $LOG_FILE
   else
     print `date` ' *** ' $JAVAPGM1 ' processed rac file okay ' 
     print `date` ' *** ' $JAVAPGM1 ' processed rac file okay '   >> $LOG_FILE
   fi
fi


####################################################################
#  check the count of non-blank racs and xrefs equals the file count
####################################################################
if [[ $RETCODE == 0 ]]; then    
      print `date`" selecting count of non blank RAC and XREfs for RTMD quarter "$QPARM
      print `date`" selecting count of non blank RAC and XREfs for RTMD quarter "$QPARM  >> $LOG_FILE
      export TCNT2=`db2 -x "select count(*) from rps.vpos_claims where period_id = '"$QPARM"' and RAC <> ' ' and XR0007_CG_NB <> ' ' " ` 
      export RETCODE=$?
      if [[ $RETCODE != 0 ]]; then     
	print `date`" db2 error selecting count of non blank RACs and XREfs for RTMD quarter - retcode: "$RETCODE
	print `date`" db2 error selecting count of non blank RACs and XREfs for RTMD quarter - retcode: "$RETCODE   >> $LOG_FILE
      else
      	print `date`" db2 select count of non blank RAC and XREfs for RTMD quarter  was  " $TCNT2
	print `date`" db2 select count of non blank RAC and XREfs for RTMD quarter  was  " $TCNT2  >> $LOG_FILE
      fi
fi 
if [[ $RETCODE == 0 ]]; then    
   if  (( $IN_DATA_CNT == $TCNT2 )); then
      print " non blank test counts "  $IN_DATA_CNT " and " $TCNT2 " match okay "
      print " non blank test counts "  $IN_DATA_CNT " and " $TCNT2 " match okay " >> $LOG_FILE
   else
      print " non blank test counts "  $IN_DATA_CNT " and " $TCNT2 " do not match!!! terminating script!"
      print " non blank test counts "  $IN_DATA_CNT " and " $TCNT2 " do not match!!! terminating script! " >> $LOG_FILE
      export RETCODE=12
   fi
fi


####################################################################
#  delete the A3 tran codes from local FESUMC
####################################################################
if [[ $RETCODE == 0 ]]; then    
      print `date`" deleting local A3 txs for RTMD quarter "$QPARM
      print `date`" deleting local A3 txs for RTMD quarter "$QPARM  >> $LOG_FILE
      db2 -stvx "delete from rps.ksrb223_fesumc where rbat_bill_prd_nm = '"$QPARM"' and tran_typ_cd = 'A3' "  >> $LOG_FILE 
      export RETCODE=$?
      if [[ $RETCODE == 1 ]]; then     
        export RETCODE=0
	print `date`" Warning: No A3 txs for RTMD quarter were found to delete  "
	print `date`" Warning: No A3 txs for RTMD quarter were found to delete  "   >> $LOG_FILE
      else
         if [[ $RETCODE != 0 ]]; then     
	   print `date`" db2 error deleting local A3 txs for RTMD quarter - retcode: "$RETCODE
	   print `date`" db2 error deleting local A3 txs for RTMD quarter - retcode: "$RETCODE   >> $LOG_FILE
         else
      	   print `date`" db2 delete of local A3 txs for RTMD quarter was successful  " 
	   print `date`" db2 delete of local A3 txs for RTMD quarter was successful  "  >> $LOG_FILE
         fi
      fi
fi 

# note: RPS_KSDY7000_KS_7700J_daily_posting.ksh needs to run after this to sync up FESUMC
#       otherwise the sync-up code needs to be copied to here.


################################################################
# disconnect from udb
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
print "return_code =" $RETCODE

mv $DATAFILE   $INPUT_ARCH_PATH/$JOB"_posrerac.in".$TIME_STAMP
mv $SENTFILE   $INPUT_ARCH_PATH/"ks9420j_posrerac.out".$TIME_STAMP

mv $LOG_FILE   $LOG_ARCH_PATH/ 

rm -f $DATAFILE
rm -f $DBMSG_FILE* 

print "return_code =" $RETCODE
exit $RETCODE

