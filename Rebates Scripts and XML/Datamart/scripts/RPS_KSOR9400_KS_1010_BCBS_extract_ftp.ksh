#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_1010_BCBS_extract_ftp.ksh
# Title         : BCBS AR Med D Rebate files extract and ftp
# Description   : This script will extract BCBS files and ftp to business.
#                 the following tables will be used for extract:
#                       rps.BCBS_REPORT
#           rps.BCBS_control
#         Up to 17 quarters of rebated claims will be appended to 
#         drug level and member level files for each Rebate ID.
#
#         This script will be kicked off after
#                 RPS_KSOR9400_KS_1000_BCBS_report.ksh.
# 
# Abends        : 
#                                 
# Parameters    : none
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 07-29-09   qcpi733     Added GDX APC status update; removed export command
#                        from RETCODE assignments.
# 03-20-08   qcpi03o     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=$(basename "$0")
JOB=$(echo $SCRIPT|awk -F. '{print $1}')
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0

RBATE_CNT=$TMP_PATH/BCBS.rebate
PERIOD_CNT=$TMP_PATH/BCBS.period

MEMBER_FILE=$TMP_PATH/BCBS.MemberLevel.
DRUG_FILE=$TMP_PATH/BCBS.DrugLevel.

FILE_TRL=`date +"%Y%m%d"`

MEMBER_FILE_WK=$TMP_PATH/BCBS.MemberLevel.tmp
DRUG_FILE_WK=$TMP_PATH/BCBS.DrugLevel.tmp
DCSQL=$TMP_PATH/BCBS.extract.sql

FTP_BUS_IP=azshisp00
FTP_PATH="rps_uploads\BCBSAR Rebate Files"
USER='ftpnt'
PASSWD='simple2'

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 360 STRT                          >> $LOG_FILE

################################################################
# 1) connect to udb
################################################################
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                         >> $LOG_FILE 
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - cant connect to udb " 
      print "!!! terminating script - cant connect to udb "                    >> $LOG_FILE  
   fi
fi

################################################################
# 2) read Rebate ID/inv_qtr from control table
################################################################

if [[ $RETCODE == 0 ]]; then
        db2 -px "select distinct INV_QTR from rps.bcbs_control where inv_qtr>'2007Q2'" > $PERIOD_CNT
RETCODE=$?
fi

rm $RBATE_CNT
FILE_LOOP=$TMP_PATH/BSBC_file_loop
for F_SEQ in 1 2 
do
    REBATE_L="('"
        db2 -px "select distinct REBATE_ID from rps.bcbs_control where file_seq=$F_SEQ" > $PERIOD_CNT.$F_SEQ
    while read RLIST; do
        REBATE_L=$REBATE_L$RLIST\',\'
    done <$PERIOD_CNT.$F_SEQ
    REBATE_L=$REBATE_L"')"
    echo $REBATE_L   >> $RBATE_CNT
   rm $PERIOD_CNT.$F_SEQ
done

################################################################
# 3) extract files for each file_seq 
################################################################

rm $MEMBER_FILE*
rm $DRUG_FILE*

while read SRBATE; do

RBATE=`echo $SRBATE|cut -c 3-10 `

MEMBER_FILE_NM=$MEMBER_FILE$RBATE.$FILE_TRL
DRUG_FILE_NM=$DRUG_FILE$RBATE.$FILE_TRL

rm $MEMBER_FILE_NM
rm $DRUG_FILE_NM

   while read QPARM; do

if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $MEMBER_FILE_WK of del 
SELECT INV_QTR,
            EXTNL_LVL_ID1,
            EXTNL_LVL_ID2,
            REBATE_ID,
            MBR_ID,
            CLAIM_GID,
            substr(char(FILL_DT,USA),1,2)||'-'||substr(char(FILL_DT,USA),7,4),
            INVOICE_AMT+ADJ_AMT,
            COLLECT_AMT,
            substr(to_char(INVOICED_DT,'YYYY-MM-DD HH24:MI:SS'),6,2)||'-'||
                substr(to_char(INVOICED_DT,'YYYY-MM-DD HH24:MI:SS'),1,4),
            substr(to_char(REBATE_PAID_DT,'YYYY-MM-DD HH24:MI:SS'),6,2)||'-'||
                substr(to_char(REBATE_PAID_DT,'YYYY-MM-DD HH24:MI:SS'),1,4)

    FROM rps.BCBS_report
     WHERE INV_QTR = '$QPARM' and REBATE_ID in $SRBATE
    order by EXTNL_LVL_ID1,EXTNL_LVL_ID2;
ZZEOF

print " *** sql being used is: "                                               >> $LOG_FILE
print `cat $DCSQL`                                                             >> $LOG_FILE
print " *** end of sql display."                                               >> $LOG_FILE

fi

#
# extract to file
#
if [[ $RETCODE == 0 ]]; then
   db2 -tvf $DCSQL                                                             >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!!aborting script - error exporting from BCBS_report "           >> $LOG_FILE
   fi
fi

cat $MEMBER_FILE_WK>>$MEMBER_FILE_NM


if [[ $RETCODE == 0 ]]; then
#
# create export sql file
#
cat > $DCSQL << ZZEOF
export to $DRUG_FILE_WK of del 
SELECT INV_QTR,
            EXTNL_LVL_ID1,
            EXTNL_LVL_ID2,
            REBATE_ID,
        substr(replace( replace(DRUG_NAME,',',''),'"',''),1,30),
            NDC,
            substr(char(FILL_DT,USA),1,2)||'-'||substr(char(FILL_DT,USA),7,4),
            PLAN_CD,
            INVOICE_AMT+ADJ_AMT,
            COLLECT_AMT,
            substr(to_char(INVOICED_DT,'YYYY-MM-DD HH24:MI:SS'),6,2)||'-'||
                substr(to_char(INVOICED_DT,'YYYY-MM-DD HH24:MI:SS'),1,4),
            substr(to_char(REBATE_PAID_DT,'YYYY-MM-DD HH24:MI:SS'),6,2)||'-'||
                substr(to_char(REBATE_PAID_DT,'YYYY-MM-DD HH24:MI:SS'),1,4)
    FROM rps.BCBS_report
     WHERE INV_QTR = '$QPARM' and REBATE_ID in $SRBATE
    order by EXTNL_LVL_ID1,EXTNL_LVL_ID2;
ZZEOF

print " *** sql being used is: "                                               >> $LOG_FILE
print `cat $DCSQL`                                                             >> $LOG_FILE
print " *** end of sql display."                                               >> $LOG_FILE

fi

#
# extract to file
#
if [[ $RETCODE == 0 ]]; then
   db2 -tvf $DCSQL                                                             >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!!aborting script - error exporting from BCBS_report "           >> $LOG_FILE
   fi
fi

cat $DRUG_FILE_WK>>$DRUG_FILE_NM
   done <$PERIOD_CNT

done <$RBATE_CNT

################################################################
# 4) for each rbate_id, ftp to business driver
################################################################
if [[ $RETCODE == 0 ]]; then
   print " doing ftp to business driver ........................"              >> $LOG_FILE

FILE_LIST=$TMP_PATH/BCBS_file.list
ls $TMP_PATH/BCBS.MemberLevel.000* >$FILE_LIST
ls $TMP_PATH/BCBS.DrugLevel.000*   >>$FILE_LIST


while read FTP_FILE; do
    FTP_FILEF=$(echo $FTP_FILE|awk -F/ '{print $4}')

   ftp -n $FTP_BUS_IP <<END_SCRIPT
quote USER $USER
quote PASS $PASSWD
cd "rps_uploads\BCBSAR Rebate Files"
asc
put $FTP_FILE $FTP_FILEF
quit
END_SCRIPT
 
   RETCODE=$?
   if [[ $RETCODE != 0 ]] ; then
      print  ' !! ftp returned code ' $RETCODE
      print `date` ' !! ftp returned code ' $RETCODE ' terminating script '    >> $LOG_FILE
      RETCODE=12
   fi
done <$FILE_LIST

fi

################################################################
# 5) for each rbate_id, ftp to secure transport
################################################################
if [[ $RETCODE == 0 ]]; then
   print " doing ftp to secure transport ........................"             >> $LOG_FILE


while read FTP_FILE; do
        FTP_FILEF=$(echo $FTP_FILE|awk -F/ '{print $4}')

   ftp -n PRODFTP <<END_SCRIPT
quote USER ITRebates
quote PASS simple2
cd outbound
asc
put $FTP_FILE $FTP_FILEF
quit
END_SCRIPT

   RETCODE=$?
   if [[ $RETCODE != 0 ]] ; then
      print  ' !! ftp returned code ' $RETCODE
      print `date` ' !! ftp returned code ' $RETCODE ' terminating script '    >> $LOG_FILE
      RETCODE=12
   fi
done <$FILE_LIST

fi

###############################################################
# zz) disconnect from udb
################################################################
db2 -stvx connect reset                                                        >> $LOG_FILE 
db2 -stvx quit                                                                 >> $LOG_FILE 


#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                                     >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE

   #Call the APC status update
   . `dirname $0`/RPS_GDX_APC_Status_update.ksh 360 ERR                        >> $LOG_FILE

   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`                  >> $LOG_FILE 

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 360 END                           >> $LOG_FILE

#################################################################
# cleanup from successful run
#################################################################
rm $RBATE_CNT
rm $PERIOD_CNT

rm $MEMBER_FILE_WK
rm $DRUG_FILE_WK
rm $DCSQL

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
