#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_RIOR4500_GD_7800J_apc_file_create_xfer.ksh   
# Title         : APC File Creation and Transfer
#
# Description   : This script will pull the GPO Claim level feed from GDX
#                 and build a flat file.  It will also pull the GPO Report  
#                 detail feed from GDX and build a flat file.  Both files
#                 will then be FTP'd back to the GPO system for insertion
#                 into Oracle tables.
#                 Note: this script is executed from a schedule running
#                       on rebdom1.
# 
# Abends        : Should either extract produce zero records or if any 
#                 common routines set bad return codes this job will 
#                 abend.
#                 
# Maestro Job   : RIOR4500 GD_7800J
#
# Parameters    : Quarter (YYYY4Q) as optional parameter 
#
# Output        : Log file as $LOG_FILE
#                 Claim Feed as $APC_A_GDX_RBATE_INV_DATA
#                 Report Feed as $APC_A_GDX_REPORT_DATA
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 06-08-05   qcpi768     added min/max and group-by to excluded claims 
#                        extract to avoid duplicate claim ids.
# 05-20-05   qcpi768     re-add vclaims extract with limited NDC scope
#                        per design change
# 05-20-05   qcpi768     Remove vclaims extract per design change
# 05-19-05   qcpi768     Performance tune sql
# 03-03-05   qcpi768     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
#-------------------------------------------------------------------------#
# Call the Common used script functions to make functions available
#-------------------------------------------------------------------------#
. $SCRIPT_PATH/Common_GDX_Script_Functions.ksh
 
  
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS="james.tedeschi@caremark.com"
        SCHEMA_OWNER="VRAP"
	FTP_NT_IP=$GPO_HOST_TEST
        FTP_PATH=$GPO_PATH_TEST"/input/"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        SCHEMA_OWNER="VRAP"
	FTP_NT_IP=$GPO_HOST_PROD
	FTP_PATH=$GPO_PATH_PROD"/input/"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="james.tedeschi@caremark.com"
    SCHEMA_OWNER="VRAP"
    FTP_NT_IP=$GPO_HOST_TEST
    FTP_PATH=$GPO_PATH_TEST"/input/"
    print " running in dev"
fi


# examine/derive Quarter parameter  YYYY4Q
YEAR=""
QTR=""
QPARM=""
QPID=""
if [[ $# -eq 1 ]]; then
#   edit supplied parameter
    YEAR=`echo $1 |cut -c 1-4`
    QTR=`echo $1 |cut -c 6-6`
    if (( $YEAR > 1990 && $YEAR < 2050 )); then
      print ' using parameter YEAR of ' $YEAR
    else
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is YYYY4Q.  Terminating script '
      exit
    fi
    if (( $QTR > 0 && $QTR < 5 )); then
      print ' using parameter QUARTER of ' $QTR
    else
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is YYYY4Q. Terminating script '
      exit
    fi
else
#   when no parameter supplied, derive quarter as previous to current quarter
    YEAR=`date +"%Y"`
    MM=`date +"%m"`
    if (( $MM < 4 )); then 
       ((YEAR=$YEAR - 1))
       QTR=4  
       print ' derived Quarter is ' $YEAR $QTR 
    else
       case $MM in 
         04|05|06) export QTR=1 ;;
	 07|08|09) export QTR=2 ;;
	 10|11|12) export QTR=3 ;;
       esac 
    fi
fi
QPARM=$YEAR"4"$QTR
print ' qparm is ' $QPARM
QPID=Q0$QTR`echo $YEAR | cut -c 3-4`
print ' period ID qpid is ' $QPID
QBEGIN=""
QEND=""
case $QTR in 
         1) export QBEGIN="'1/1/"$YEAR"'" ;;
	 2) export QBEGIN="'4/1/"$YEAR"'" ;;
         3) export QBEGIN="'7/1/"$YEAR"'" ;;
         4) export QBEGIN="'10/1/"$YEAR"'" ;;
esac 
case $QTR in 
         1) export QEND="'3/31/"$YEAR"'" ;;
	 2) export QEND="'6/30/"$YEAR"'" ;;
         3) export QEND="'9/30/"$YEAR"'" ;;
         4) export QEND="'12/31/"$YEAR"'" ;;
esac 

RETCODE=0
SCHEDULE="RIOR4500"
JOB="GD_7800J"
FILE_BASE="GDX_"$SCHEDULE"_"$JOB"_apc_file_create_xfer"
SCRIPTNAME=$FILE_BASE".ksh"
ARCH_LOG_FILE=$FILE_BASE".log"
LOG_FILE=$LOG_PATH/$ARCH_LOG_FILE
UDB_SQL_FILE=$SQL_PATH/$FILE_BASE"_udb.sql"
UDB_OUTPUT_MSG_FILE=$SQL_PATH/$FILE_BASE"_udb_sql.msg"
UDB_EXPORT_MSG_FILE=$SQL_PATH/$FILE_BASE"_udb_exp.msg"
UDB_MSG_FILE=$SQL_PATH/$FILE_BASE"_udb.msg"
UDB_CONNECT_STRING="db2 -p connect to "$DATABASE" user "$CONNECT_ID" using "$CONNECT_PWD
SQL_PIPE_FILE=$SQL_PATH/$FILE_BASE"_pipe.lst"
APC_A_GDX_RBATE_INV_DATA=$OUTPUT_PATH/$JOB"_apc_claims_"$QPARM".dat".$TIME_STAMP
APC_A_GDX_REPORT_DATA=$OUTPUT_PATH/$JOB"_apc_report_"$QPARM".dat".$TIME_STAMP
APC_A_GDX_RBATE_INV_TRG="" 
APC_A_GDX_REPORT_TRG=""
RUN_MODE="PROD"
 
# report config extract
RPT_SEL="select $QPARM as CYCLE_GID, rqmt.RPT_ID, rqmt.RPT_TITLE, vndr.NDC5_NB as PICO_NO, pc.PYMT_CNTRCT_BUS_ID, pc.PYMT_CNTRCT_TX "
RPT_SEL=$RPT_SEL"from $SCHEMA_OWNER.TRPT_REQMT rqmt, $SCHEMA_OWNER.TVNDR vndr, $SCHEMA_OWNER.TCNTRCT cntr, "
RPT_SEL=$RPT_SEL"     $SCHEMA_OWNER.TPYMT_CNTRCT pc, $SCHEMA_OWNER.VRPT_CD rptcd  "
RPT_SEL=$RPT_SEL"where cntr.MODEL_TYP_CD = 'G'  "
RPT_SEL=$RPT_SEL" and  vndr.VNDR_ID  = cntr.VNDR_ID  "
RPT_SEL=$RPT_SEL" and  rqmt.CNTRCT_ID = cntr.CNTRCT_ID "
RPT_SEL=$RPT_SEL" and  rptcd.RPT_CD = rqmt.RPT_TYP_CD "
RPT_SEL=$RPT_SEL" and  rptcd.RPT_CD_NM LIKE 'R%' "
RPT_SEL=$RPT_SEL" and  pc.PYMT_CNTRCT_ID = rqmt.PYMT_CNTRCT_ID "
RPT_SEL=$RPT_SEL"order by rqmt.RPT_ID; "
   
# claim results extract
#CLM_SEL1="select $QPARM as CYCLE_GID, ext.CLAIM_ID as CLAIM_GID, ext.RPT_ID, 91 as MDA_EXCPT_ID, "
#CLM_SEL1=$CLM_SEL1"(ext.BASE_DISCNT_AMT + ext.CNTRCT_DISCNT_AMT) as RBATE_ACCESS, "
#CLM_SEL1=$CLM_SEL1" ext.PRFMC_DISCNT_AMT as RBATE_MRKT_SHR, ext.FORMLY_DISCNT_AMT as RBATE_ADMIN_FEE "
#CLM_SEL1=$CLM_SEL1"from $SCHEMA_OWNER.TDISCNT_EXT_CLAIM_GPO ext "
#CLM_SEL1=$CLM_SEL1"where ext.MODEL_TYP_CD = 'G' and ext.DISCNT_RUN_MODE = '$RUN_MODE' and ext.PERIOD_ID = '"$QPID"'  "

CLM_SEL1="select $QPARM as CYCLE_GID, ext.CLAIM_ID as CLAIM_GID, max(ext.RPT_ID) as RPT_ID, 91 as MDA_EXCPT_ID, "
CLM_SEL1=$CLM_SEL1" sum((ext.BASE_DISCNT_AMT + ext.CNTRCT_DISCNT_AMT)) as RBATE_ACCESS, "
CLM_SEL1=$CLM_SEL1" sum(ext.PRFMC_DISCNT_AMT) as RBATE_MRKT_SHR, sum(ext.FORMLY_DISCNT_AMT) as RBATE_ADMIN_FEE "
CLM_SEL1=$CLM_SEL1"from $SCHEMA_OWNER.TDISCNT_EXT_CLAIM_GPO ext "
CLM_SEL1=$CLM_SEL1"where ext.MODEL_TYP_CD = 'G' and ext.DISCNT_RUN_MODE = '$RUN_MODE' and ext.PERIOD_ID = '"$QPID"'  "
CLM_SEL1=$CLM_SEL1" group by CLAIM_ID "

   
# excluded claims extract
#CLM_SEL2="select $QPARM as CYCLE_GID, exc.CLAIM_ID as CLAIM_GID, exc.RPT_ID, exc.EXCL_GRP_CD as MDA_EXCPT_ID, "
CLM_SEL2="select $QPARM as CYCLE_GID, exc.CLAIM_ID as CLAIM_GID, max(exc.RPT_ID) as RPT_ID, min(exc.EXCL_GRP_CD) as MDA_EXCPT_ID, "
CLM_SEL2=$CLM_SEL2" 0 as RBATE_ACCESS, 0 as RBATE_MRKT_SHR, 0 as RBATE_ADMIN_FEE "
CLM_SEL2=$CLM_SEL2"from $SCHEMA_OWNER.TDISCNT_EXCL_CLAIM_GPO exc "
CLM_SEL2=$CLM_SEL2"where exc.DISCNT_RUN_MODE_CD = '$RUN_MODE' and exc.PERIOD_ID = '"$QPID"' "
# dont include an excluded claim if it was rebated
CLM_SEL2=$CLM_SEL2" and exc.CLAIM_ID NOT IN (select CLAIM_ID from $SCHEMA_OWNER.TDISCNT_EXT_CLAIM_GPO where MODEL_TYP_CD = 'G' and DISCNT_RUN_MODE = '$RUN_MODE' and PERIOD_ID = '"$QPID"' ) "
CLM_SEL2=$CLM_SEL2" group by CLAIM_ID "

# ignored claims extract
CLM_SEL3="select $QPARM as CYCLE_GID, exi.CLAIM_ID as CLAIM_GID, 0 as RPT_ID, 39 as MDA_EXCPT_ID, "
CLM_SEL3=$CLM_SEL3" 0 as RBATE_ACCESS, 0 as RBATE_MRKT_SHR, 0 as RBATE_ADMIN_FEE "
CLM_SEL3=$CLM_SEL3"from $SCHEMA_OWNER.VCLAIM_GPO exi  "
CLM_SEL3=$CLM_SEL3"where ( exi.INV_ELIG_DT between "$QBEGIN" and "$QEND")  "
CLM_SEL3=$CLM_SEL3"  and exi.DRUG_NDC_ID IN ( select n11.DRUG_NDC_ID "
CLM_SEL3=$CLM_SEL3"  from $SCHEMA_OWNER.tcntrct c, $SCHEMA_OWNER.trpt_reqmt r, $SCHEMA_OWNER.vrpt_cd cd12, $SCHEMA_OWNER.trpt_ndc11 n11 "
CLM_SEL3=$CLM_SEL3"  where c.cntrct_id = r.cntrct_id AND r.rpt_typ_cd   = cd12.rpt_cd AND cd12.rpt_cd_nm LIKE 'R%'  AND r.rpt_id  = n11.rpt_id AND c.model_typ_cd = 'G' ) "      
CLM_SEL3=$CLM_SEL3" and exi.CLAIM_ID NOT IN (  "
CLM_SEL3=$CLM_SEL3"  select  ext2.CLAIM_ID as CLAIM_GID  from $SCHEMA_OWNER.TDISCNT_EXT_CLAIM_GPO ext2 where ext2.MODEL_TYP_CD = 'G' and ext2.DISCNT_RUN_MODE = '$RUN_MODE' and ext2.PERIOD_ID = '"$QPID"' "
CLM_SEL3=$CLM_SEL3"  union  select  exc2.CLAIM_ID as CLAIM_GID from $SCHEMA_OWNER.TDISCNT_EXCL_CLAIM_GPO exc2 where exc2.DISCNT_RUN_MODE_CD ='$RUN_MODE' and exc2.PERIOD_ID = '"$QPID"' )"
 
CLM_SEL=$CLM_SEL1" union "$CLM_SEL2" union "$CLM_SEL3" ;" 


RETCODE=0
export CONT=0
 
rm -f $LOG_FILE
rm -f $UDB_SQL_FILE
rm -f $UDB_MSG_FILE
rm -f $UDB_OUTPUT_MSG_FILE
rm -f $UDB_EXPORT_MSG_FILE
rm -f $SQL_PIPE_FILE
rm -f $OUTPUT_PATH/$FILE_BASE*

print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
print `date` " Started executing " $SCRIPTNAME " "                                   >> $LOG_FILE
print "#-------------------------------------------------------------------------#"  >> $LOG_FILE

#-------------------------------------------------------------------------#
  print `date` "Starting the step to export CLAIM Results data"                >> $LOG_FILE
#-------------------------------------------------------------------------#
print " "                                                                      >> $LOG_FILE
print "* * * *"                                                                >> $LOG_FILE
print "* * * *"                                                                >> $LOG_FILE

cat > $UDB_SQL_FILE << 99EOFSQLTEXT99
export to $APC_A_GDX_RBATE_INV_DATA of del modified by coldel| messages $UDB_EXPORT_MSG_FILE $CLM_SEL
connect reset;
quit;
99EOFSQLTEXT99

print " "                                                                      >> $LOG_FILE
print "start showing udb sql file " >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
cat $UDB_SQL_FILE >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "end showing udb sql file " >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

$UDB_CONNECT_STRING                                                            >> $LOG_FILE
db2 -stvxf $UDB_SQL_FILE                                 >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

export RETCODE=$?

print " "                                                                      >> $LOG_FILE
if [[ $RETCODE != 0 ]]; then 
    print "Error exporting data from TDISCNT_EXT_CLAIM_GPO, Return Code = "$RETCODE >> $LOG_FILE
    if [[ -r $UDB_EXPORT_MSG_FILE ]] ; then
       print "Check Export error log: "$UDB_EXPORT_MSG_FILE                    >> $LOG_FILE
       print "Here are last 20 lines of that file - "                          >> $LOG_FILE
       print " "                                                               >> $LOG_FILE
       tail -20 $UDB_EXPORT_MSG_FILE                                           >> $LOG_FILE
    fi    
    print " "                                                                  >> $LOG_FILE
    print "Check Output error log: "$UDB_Output_MSG_FILE                       >> $LOG_FILE
    print "Here are last 20 lines of that file - "                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    tail -20 $UDB_OUTPUT_MSG_FILE                                              >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    print "Data output file is: "$APC_A_GDX_RBATE_INV_DATA                     >> $LOG_FILE
    CONT=1
else
    cat $UDB_EXPORT_MSG_FILE                                                   >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Return Code from UDB Export = "$RETCODE                             >> $LOG_FILE
    print "Successful export - continuing script."                             >> $LOG_FILE
fi

print `date`                                                                   >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

if [[ $CONT = 0 ]] ; then
   print " "                                                                   >> $LOG_FILE
#-------------------------------------------------------------------------#
   print `date` "Creating trigger file for CLAIM Results data "                >> $LOG_FILE
#-------------------------------------------------------------------------#
   print " "                                                                   >> $LOG_FILE
   FTP_DATA_FILE=$APC_A_GDX_RBATE_INV_DATA
   FTP_UD1=$QPARM
. $SCRIPT_PATH/Common_Ftp_Trigger.ksh
   export RETCODE=$?
   if [[ $RETCODE != 0 ]] ; then
      print  ' !! Common_Ftp_Trigger.ksh returned return code ' $RETCODE 
      print `date` ' !! Common_Ftp_Trigger.ksh returned return code ' $RETCODE >> $LOG_FILE
      CONT=1
   else
      APC_A_GDX_RBATE_INV_TRG=$FTP_TRG_FILE
   fi
else
    print " "                                                                  >> $LOG_FILE
    print `date` " skipping step to create trigger file for CLAIM Results due to previous errors " >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
fi



if [[ $CONT = 0 ]] ; then
   print " "                                                                   >> $LOG_FILE
   print " "                                                                   >> $LOG_FILE
   print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
   print `date` "Starting the step to export REPORT detail data"               >> $LOG_FILE
   print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
   print " "                                                                   >> $LOG_FILE
   print "* * * *"                                                                >> $LOG_FILE
   print "* * * *"                                                                >> $LOG_FILE
   print ' ' > $UDB_EXPORT_MSG_FILE 
   cat > $UDB_SQL_FILE << 99EOFSQLTEXT99
export to $APC_A_GDX_REPORT_DATA of del modified by coldel| messages $UDB_EXPORT_MSG_FILE $RPT_SEL 
connect reset;
quit;
99EOFSQLTEXT99

   print " "                                                                   >> $LOG_FILE
   print "start showing udb sql file " >> $LOG_FILE
   print " "                                                                   >> $LOG_FILE
   cat $UDB_SQL_FILE >> $LOG_FILE
   print " "                                                                   >> $LOG_FILE
   print "end showing udb sql file " >> $LOG_FILE
   print " "                                                                   >> $LOG_FILE

   $UDB_CONNECT_STRING                                                          >> $LOG_FILE
   db2 -stvxf $UDB_SQL_FILE                             >> $LOG_FILE > $UDB_OUTPUT_MSG_FILE

   export RETCODE=$?
   print " "                                                                   >> $LOG_FILE
   if [[ $RETCODE != 0 ]]; then 
       print "Error exporting data from TCNTRCT, Return Code = "$RETCODE       >> $LOG_FILE
       if [[ -r $UDB_EXPORT_MSG_FILE ]] ; then
          print "Check Export error log: "$UDB_EXPORT_MSG_FILE                 >> $LOG_FILE
          print "Here are last 20 lines of that file - "                       >> $LOG_FILE
          print " "                                                            >> $LOG_FILE
          tail -20 $UDB_EXPORT_MSG_FILE                                        >> $LOG_FILE
       fi
       print " "                                                               >> $LOG_FILE
       print "Check Output error log: "$UDB_OUTPUT_MSG_FILE                    >> $LOG_FILE
       print "Here are last 20 lines of that file - "                          >> $LOG_FILE
       print " "                                                               >> $LOG_FILE
       tail -20 $UDB_OUTPUT_MSG_FILE                                           >> $LOG_FILE
       print " "                                                               >> $LOG_FILE
       print "Data output file is: "$APC_A_GDX_REPORT_DATA                     >> $LOG_FILE
       CONT=1
   else
       cat $UDB_EXPORT_MSG_FILE                                                >> $LOG_FILE
       print " "                                                               >> $LOG_FILE
       print "Return Code from UDB Export = "$RETCODE                          >> $LOG_FILE
       print "Successful export - continuing script."                          >> $LOG_FILE
   fi

   print `date`                                                                >> $LOG_FILE
   print " "                                                                   >> $LOG_FILE
else
    print " "                                                                  >> $LOG_FILE
    print `date` " skipping step to export Report data due to previous errors" >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
fi


if [[ $CONT = 0 ]] ; then
   print " "                                                                   >> $LOG_FILE
#-------------------------------------------------------------------------#
   print `date` "Creating trigger file for REPORT Results data "               >> $LOG_FILE
#-------------------------------------------------------------------------#
   print " "                                                                   >> $LOG_FILE
   FTP_DATA_FILE=$APC_A_GDX_REPORT_DATA
   FTP_UD1=$QPARM
. $SCRIPT_PATH/Common_Ftp_Trigger.ksh
   export RETCODE=$?
   if [[ $RETCODE != 0 ]] ; then
      print  ' !! Common_Ftp_Trigger.ksh returned return code ' $RETCODE 
      print `date` ' !! Common_Ftp_Trigger.ksh returned return code ' $RETCODE >> $LOG_FILE
      CONT=1
   else
      APC_A_GDX_REPORT_TRG=$FTP_TRG_FILE
   fi
else
    print " "                                                                  >> $LOG_FILE
    print `date` " skipping step to create trigger file for exported Report data due to previous errors" >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
fi


if [[ $CONT = 0 ]] ; then
   print " "                                                                   >> $LOG_FILE
   print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
   print `date` "FTP-ing Results data over to GPO system "                     >> $LOG_FILE
   print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
   print " "                                                                   >> $LOG_FILE

   chmod 777 $APC_A_GDX_RBATE_INV_DATA 
   chmod 777 $APC_A_GDX_RBATE_INV_TRG 
   print " doing ftp now ........................"

   FTP_CMD_FILE=$TMP_PATH"/"$FILE_BASE"_ftpcmds.txt"
   rm -f $FTP_CMD_FILE
   cat > $FTP_CMD_FILE << 99EOFSQLTEXT99
binary
cd $FTP_PATH
put $APC_A_GDX_RBATE_INV_DATA    ${APC_A_GDX_RBATE_INV_DATA##*/}  
put $APC_A_GDX_REPORT_DATA       ${APC_A_GDX_REPORT_DATA##*/} 
put $APC_A_GDX_REPORT_TRG        ${APC_A_GDX_REPORT_TRG##*/} 
put $APC_A_GDX_RBATE_INV_TRG     ${APC_A_GDX_RBATE_INV_TRG##*/} 
quit
99EOFSQLTEXT99
  
   cat $FTP_CMD_FILE  >> $LOG_FILE

   ftp -i $FTP_NT_IP < $FTP_CMD_FILE                                           >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]] ; then
      print  ' !! ftp returned code ' $RETCODE 
      print `date` ' !! ftp returned code ' $RETCODE                           >> $LOG_FILE
      CONT=1
   fi
else
    print " "                                                                  >> $LOG_FILE
    print `date` " skipping step to FTP data files due to previous errors"     >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
fi


#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " "                                                                   
   print "===================== J O B  A B E N D E D ======================"   
   print "  Error Executing " $SCRIPTNAME                                      
   print "  Look in "$LOG_FILE                                                 
   print " "                                                                   >> $LOG_FILE
   print "===================== J O B  A B E N D E D ======================"   >> $LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                      >> $LOG_FILE
   print "  Look in "$LOG_FILE                                                 >> $LOG_FILE
   print "================================================================="   >> $LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters"            >> $LOG_FILE
   print "JOBNAME is " $JOBNAME                                                >> $LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME                                          >> $LOG_FILE
   print "LOGFILE is " $LOGFILE                                                >> $LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4                                          >> $LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5                                          >> $LOG_FILE
   print "****** end of email parameters ******"                               >> $LOG_FILE
   
   . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh
   cp -f $LOG_FILE $LOG_ARCH_PATH/$ARCH_LOG_FILE.$TIME_STAMP
   exit $RETCODE
fi

#rm -f $UDB_SQL_FILE
#rm -f $UDB_MSG_FILE
#rm -f $UDB_OUTPUT_MSG_FILE
#rm -f $UDB_EXPORT_MSG_FILE
#rm -f $SQL_PIPE_FILE

print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print `date` " Completed executing " $SCRIPTNAME " "                    >> $LOG_FILE
print " log going to " $LOG_ARCH_PATH/$ARCH_LOG_FILE.$TIME_STAMP
print "#-------------------------------------------------------------------------#"  >> $LOG_FILE


mv -f $LOG_FILE $LOG_ARCH_PATH/$ARCH_LOG_FILE.$TIME_STAMP

exit $RETCODE
