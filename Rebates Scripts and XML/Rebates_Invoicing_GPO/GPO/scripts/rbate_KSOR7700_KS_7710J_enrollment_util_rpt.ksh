#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KSOR7700_KS_7710J_enrollment_util_rpt   
# Title         : Quarterly Estimated Enrollment Utilization Report
#
# Description   : This process creates the Quarterly Estimated Enrollment Utilization
#                 report in a delimited format.
# Maestro Job   : KC_2050J
#
# Parameters    : N/A
#         
# Input         : This script gets the cycle gid from t_rbate_cycle for the max
#                 quarterly cycle with a rebate cycle status of P.
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-21-2004  S.Swanson   Initial Creation.
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh


# for testing
#. /staging/apps/rebates/prod/scripts/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
      export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
      export ALTER_EMAIL_ADDRESS=''
else  
      export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
      export ALTER_EMAIL_ADDRESS='sheree.swanson@caremark.com,kurt.gries@caremark.com'
fi

 SCHEDULE="KSOR7700"
 JOB="KS_7710J"
 FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_enrollment_util_rpt"
 SCRIPTNAME=$FILE_BASE".ksh"
 LOG_FILE=$FILE_BASE".log"
 SQL_FILE=$FILE_BASE".sql"
 SQL_FILE_DATE_CNTRL=$FILE_BASE"_date_cntrl.sql"
 SQL_PIPE_FILE=$FILE_BASE"_Pipe.lst"
 DAT_FILE=$FILE_BASE".dat"
 DATE_CNTRL_FILE=$FILE_BASE"_date_control_file.dat"
 CTRL_FILE="rbate_enrollment_util_cycle.dat"
 FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
 FTP_NT_IP=AZSHISP00
 CYCLE_GID=""
 CYCLE_STATUS=""

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$DAT_FILE
rm -f $OUTPUT_PATH/DATE_CNTRL_FILE
rm -f $OUTPUT_PATH/SQL_FILE
rm -f $OUTPUT_PATH/$SQL_FILE_DATE_CNTRL
rm -f $OUTPUT_PATH/$FTP_CMDS
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE

#Set return code to null

RETCODE=''

#-------------------------gET DATE STARTS HERE
#---------------------------------------------------------------
#Set paramters to use in PL/SQL call.
#Determines Current invoice quarter being processed.
#The month back starts at 0 (current month).  If a parm is set
#the month back is set to the value of the parm.
#
#This script calculates the starting and ending date of the quarter
#report to be created.
#-----------------------------------------------------------------

#--------------------------------------------------------------------
#initialize month back to 0 or to parm value
#If there is no parm CYCLE_STATUS is set to P=process.  Otherwise it
#is set to C=Complete.
#The parm will only be used when recreating a previous quarter report.
#initialize QTR_CNTR to 1
#--------------------------------------------------------------------

if [ $# -lt 1 ]
then 
  print " "                                                                     >> $OUTPUT_PATH/$LOG_FILE
  print "MONTHS_BACK parameter not supplied. Use normal initialization."        >> $OUTPUT_PATH/$LOG_FILE
  let MONTHS_BACK=0
  CYCLE_STATUS="P"
else
  print " "                                                                     >> $OUTPUT_PATH/$LOG_FILE
  print "MONTHS_BACK parameter supplied."                                       >> $OUTPUT_PATH/$LOG_FILE
  let MONTHS_BACK=$1
  CYCLE_STATUS="C"
  print "Value is : " $MONTHS_BACK                                              >> $OUTPUT_PATH/$LOG_FILE
fi

#------------------------------------------------------
#Read Oracle to get the cycle-gid and beginning and end dates
#related to the current quarter being processed.\Oracle userid/password
#specific for DMARBAT2 ora.user used for rbate invoicing
#used to build date file only.
#------------------------------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

cat > $INPUT_PATH/$SQL_FILE_DATE_CNTRL << EOF
set LINESIZE 500
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP off
set verify off
whenever sqlerror exit 1
SPOOL $OUTPUT_PATH/$DATE_CNTRL_FILE
alter session enable parallel dml; 

Select to_char(add_months(SYSDATE, - $MONTHS_BACK ),'MM')||'/01/'||to_char(add_months(SYSDATE, - $MONTHS_BACK ),'YYYY')
      ,' '
      ,to_char(last_day(add_months(SYSDATE, - $MONTHS_BACK )),'MM/DD/YYYY')
      ,' '
      ,rbate_CYCLE_GID
      ,' '
      ,decode(to_char(substr(rbate_CYCLE_GID,6,1)),1,'Q1',2,'Q2',3,'Q3',4,'Q4')  --quarter
      ,' '
      ,to_char(substr(rbate_CYCLE_GID,1,4))  --year
      ,' '
      ,to_char(last_day(add_months(SYSDATE, - $MONTHS_BACK )),'YYYYMM')
      ,' '
      ,to_char(CYCLE_START_DATE,'MM/DD/YYYY')
      ,' '
      ,to_char(CYCLE_END_DATE,'MM/DD/YYYY')
      ,' '
      ,to_char(add_months(cycle_start_date, - $MONTHS_BACK), 'MM/DD/YYYY') as PREV_CYCLE_START_DATE
      ,' '
      ,to_char(CYCLE_START_DATE,'MM') as MONTH_1  --first month of quarter
      ,' '
      ,to_char(add_months(CYCLE_START_DATE, + 1),'MM') as MONTH_2  --second month of quarter
      ,' '
      ,to_char(CYCLE_END_DATE,'MM') as MONTH_3  --third month of quarter
      ,' '
  from dma_rbate2.t_rbate_cycle
  where add_months(SYSDATE, - $MONTHS_BACK ) between CYCLE_START_DATE and CYCLE_END_DATE
   and substrb(rbate_CYCLE_GID,5,1) = '4'
   and rbate_cycle_type_id = '2'
   and rbate_cycle_status = '$CYCLE_STATUS'
;
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE_DATE_CNTRL

export RETCODE=$?

if [[ $RETCODE != 0 ]]; then 
   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "****  SQL  failed to retrieve cycle gid  ****  "                      >> $OUTPUT_PATH/$LOG_FILE
   print "Error Message will be created"                                        >> $OUTPUT_PATH/$LOG_FILE
   print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
else
   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "*************************************************  "                  >> $OUTPUT_PATH/$LOG_FILE
   print "****  SQL successfully retrieved cycle gid   ****  "                  >> $OUTPUT_PATH/$LOG_FILE
   print "*************************************************  "                  >> $OUTPUT_PATH/$LOG_FILE
   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
fi


if [[ $RETCODE = 0 ]]; then 

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script if applicable
#-------------------------------------------------------------------------#
  export FIRST_READ=1
  while read rec_BEG_DATE rec_END_DATE rec_CYCLE_GID rec_QTR rec_YR YRMON rec_CYCSTRT rec_CYCEND rec_CYCPREV rec_MTH1 rec_MTH2 rec_MTH3; do
    if [[ $FIRST_READ != 1 ]]; then
      print 'FINISHING control file read'                                       >> $OUTPUT_PATH/$LOG_FILE
    else
      export FIRST_READ=0
      print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
      print "TODAYS DATE " `date`                                               >> $OUTPUT_PATH/$LOG_FILE
      print "DAILY Client to Rac  EXTRACT "                                     >> $OUTPUT_PATH/$LOG_FILE
      print "QUARTER CONTROL NUMBER " $QTR_CTR                                  >> $OUTPUT_PATH/$LOG_FILE
      print ' '                                                                 >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
#Read the returned date control values one at a time and perform the extract
#for that Quarter
#-------------------------------------------------------------------------#

      print 'read record from control file'                                     >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_BEG_DATE ' $rec_BEG_DATE                                       >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_END_DATE ' $rec_END_DATE                                       >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_CYCLE_GID ' $rec_CYCLE_GID                                     >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_QTR ' $rec_QTR                                                 >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_YR ' $rec_YR                                                   >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_CYCSTRT ' $rec_CYCSTRT                                         >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_CYCEND ' $rec_CYCEND                                           >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_CYCPREV ' $rec_CYCPREV                                         >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_MTH1 ' $rec_MTH1                                               >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_MTH2 ' $rec_MTH2                                               >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_MTH3 ' $rec_MTH3                                               >> $OUTPUT_PATH/$LOG_FILE
      print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
      print "=================================================="                >> $OUTPUT_PATH/$LOG_FILE
      print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
      
      export BEGIN_DATE=$rec_BEG_DATE
      export END_DATE=$rec_END_DATE
      export CYCLE_GID=$rec_CYCLE_GID
      export QTR=$rec_QTR
      export YR=$rec_YR
      export YYYYMM=$YRMON
      export CYCSTRT=$rec_CYCSTRT
      export CYCEND=$rec_CYCEND
      export CYCPREV=$rec_CYCPREV
      export MTH1=$rec_MTH1
      export MTH2=$rec_MTH2
      export MTH3=$rec_MTH3
    fi
  done < $OUTPUT_PATH/$DATE_CNTRL_FILE


  export RETCODE=$?
   
  if [[ $RETCODE != 0 ]]; then
      print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
      print "****  Read failed to retrieve cycle gid  ****  "                   >> $OUTPUT_PATH/$LOG_FILE
      print "Error Message will be created"                                     >> $OUTPUT_PATH/$LOG_FILE
      print `date`                                                              >> $OUTPUT_PATH/$LOG_FILE
      print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
      break $RETCODE
  else
      if [[ -z $CYCLE_GID ]]; then
         print " "                                                              >> $OUTPUT_PATH/$LOG_FILE
         print "*************************************************  "            >> $OUTPUT_PATH/$LOG_FILE
         print "*********       E  R  R  O  R         ***********  "            >> $OUTPUT_PATH/$LOG_FILE
         print "*************************************************  "            >> $OUTPUT_PATH/$LOG_FILE
         print "****         CYCLE_GID is NULL               ****  "            >> $OUTPUT_PATH/$LOG_FILE
         print "**** The Date Cntrl SQL must have returned   ****  "            >> $OUTPUT_PATH/$LOG_FILE
         print "****    no rows.                             ****  "            >> $OUTPUT_PATH/$LOG_FILE
         print "****" `date`                                                    >> $OUTPUT_PATH/$LOG_FILE
         print "*************************************************  "            >> $OUTPUT_PATH/$LOG_FILE
         print "*************************************************  "            >> $OUTPUT_PATH/$LOG_FILE
         print "*************************************************  "            >> $OUTPUT_PATH/$LOG_FILE
         print " "                                                              >> $OUTPUT_PATH/$LOG_FILE
         let RETCODE=999
         break $RETCODE
      else   
         print " "                                                              >> $OUTPUT_PATH/$LOG_FILE
         print "*************************************************  "            >> $OUTPUT_PATH/$LOG_FILE
         print "****  Read successfully retrieved cycle gid  ****  "            >> $OUTPUT_PATH/$LOG_FILE
         print "*************************************************  "            >> $OUTPUT_PATH/$LOG_FILE
         print " "                                                              >> $OUTPUT_PATH/$LOG_FILE
         print "CYCLE GID is " $CYCLE_GID                                       >> $OUTPUT_PATH/$LOG_FILE
         print `date`                                                           >> $OUTPUT_PATH/$LOG_FILE
         print " "                                                              >> $OUTPUT_PATH/$LOG_FILE
      fi   
  fi   


#----------------------------------START QUERY HERE-----------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------
#This query creates the quarterly enrollment utilization report.
#The report is FTP'd to the lan server for business reveiw.
#-------------------------------------------------------------------------
print `date` 'Beginning select of quarterly enrollment utilization report '     >> $OUTPUT_PATH/$LOG_FILE

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
DAT_FILE_NBR=$DAT_FILE.$CYCLE_GID
print 'dat_fil_nbr ' $DAT_FILE_NBR                                              >> $OUTPUT_PATH/$LOG_FILE
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE_NBR bs=100k &

cat > $INPUT_PATH/$SQL_FILE << EOF99SQL
set LINESIZE 492
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP off
set verify off
whenever sqlerror exit 1
set trimspool on
alter session enable parallel dml; 

spool $OUTPUT_PATH/$SQL_PIPE_FILE;

SELECT DISTINCT 
   a.report_group_nbr
  ,'|' 
  ,a.ri_eff_dt 
  ,'|' 
  ,a.ri_term_dt
  ,'|' 
  ,a.report_group_name 
  ,'|' 
  ,ROUND(NVL((total1.lives1 * basic_pct.pct),0),0) as month1_basic
  ,'|' 
  ,ROUND(NVL((total2.lives2 * basic_pct.pct),0),0) as month2_basic
  ,'|' 
  ,ROUND(NVL((total3.lives3 * basic_pct.pct),0),0) as month3_basic
  ,'|' 
  ,ROUND(NVL((total1.lives1 * perf_pct.pct),0),0) as month1_perf
  ,'|' 
  ,ROUND(NVL((total2.lives2 * perf_pct.pct),0),0) as month2_perf
  ,'|' 
  ,ROUND(NVL((total3.lives3 * perf_pct.pct),0),0) as month3_perf
  ,'|' 
  ,ROUND(NVL((total1.lives1 * perfinc_pct.pct),0),0) as month1_perfinc
  ,'|' 
  ,ROUND(NVL((total2.lives2 * perfinc_pct.pct),0),0) as month2_perfinc
  ,'|' 
  ,ROUND(NVL((total3.lives3 * perfinc_pct.pct),0),0) as month3_perfinc
  ,'|' 
  ,ROUND(NVL((total1.lives1 * perfplus_pct.pct),0),0) as month1_perfplus
  ,'|' 
  ,ROUND(NVL((total2.lives2 * perfplus_pct.pct),0),0) as month2_perfplus
  ,'|' 
  ,ROUND(NVL((total3.lives3 * perfplus_pct.pct),0),0) as month3_perfplus
  ,'|' 
  ,ROUND(NVL((total1.lives1 * closed_pct.pct),0),0) as month1_closed
  ,'|' 
  ,ROUND(NVL((total2.lives2 * closed_pct.pct),0),0) as month2_closed
  ,'|' 
  ,ROUND(NVL((total3.lives3 * closed_pct.pct),0),0) as month3_closed
  ,'|' 
  ,(ROUND(NVL(total1.lives1,0),0)) as month1_tot
  ,'|' 
  ,(ROUND(NVL(total2.lives2,0),0)) as month2_tot
  ,'|' 
  ,(ROUND(NVL(total3.lives3,0),0)) as month3_tot
  ,'|' 
  , ROUND(((ROUND(NVL(total1.lives1,0),0) + ROUND(NVL(total2.lives2,0),0) + ROUND(NVL(total3.lives3,0),0)) / 3),0)as total_avg
  ,'|' 
  ,ad.addr_line_1
  ,'|' 
  ,ad.addr_line_2
  ,'|' 
  ,ad.state
  ,'|' 
  ,ad.city
  ,'|' 
  ,substr(ad.zip_cd,1,5) as zip_cd
  ,'|' 
  ,substr(ad.zip_cd,6,4) as zip_four
  ,'|' 
  ,a.processor
  ,'|' 
  ,a.client_type
FROM 
  (SELECT *
    FROM  rbate_reg.enrollment_reporting 
    WHERE (TRUNC(ri_term_dt) 
      BETWEEN to_date('$CYCSTRT','mm/dd/yyyy') 
      AND to_date('$CYCEND','mm/dd/yyyy' )) or 
      (ri_term_dt is null
       and year = '$YR'
       and Quarter = '$QTR'))a, 
  (SELECT b.rac, address_id, a.contact_id, a.type_cd, addr_line_1,
           addr_line_2, state, city, zip_cd
    FROM rbate_reg.address a,
         rbate_reg.rac_contact_assoc b
    WHERE RTRIM(a.type_cd) = '2'  
      AND RTRIM(b.type_cd) = '8' 
      AND a.contact_id = b.contact_id) ad,
  (SELECT REPORT_GROUP_NBR, SUM(LIVES_CNT)AS LIVES1,
          MONTH,QUARTER,YEAR
   FROM RBATE_REG.ENROLLMENT_REPORTING
   WHERE YEAR = '$YR' 
     AND QUARTER= '$QTR' 
     AND Month = '$MTH1' 
   GROUP BY REPORT_GROUP_NBR, MONTH,QUARTER,YEAR)total1,
  (SELECT REPORT_GROUP_NBR, SUM(LIVES_CNT)AS LIVES2,
          MONTH,QUARTER,YEAR
   FROM RBATE_REG.ENROLLMENT_REPORTING
   WHERE YEAR = '$YR' 
     AND QUARTER= '$QTR' 
     AND Month = '$MTH2' 
   GROUP BY REPORT_GROUP_NBR, MONTH,QUARTER,YEAR)total2,
  (SELECT REPORT_GROUP_NBR, SUM(LIVES_CNT)AS LIVES3,
          MONTH,QUARTER,YEAR
   FROM RBATE_REG.ENROLLMENT_REPORTING
   WHERE YEAR = '$YR' 
     AND QUARTER= '$QTR' 
     AND Month = '$MTH3' 
   GROUP BY REPORT_GROUP_NBR, MONTH,QUARTER,YEAR)total3,
  (SELECT rbate_id, NVL(lcm_clm_pct,0)as pct,TOT_CLM_CNT
   FROM rbate_reg.final_lcm_util
   WHERE lcm_type = '2'
     AND year = '$YR' 
     AND quarter = '$QTR')basic_pct, 
  (SELECT rbate_id, NVL(lcm_clm_pct,0)as pct
   FROM rbate_reg.final_lcm_util
   WHERE lcm_type = '3'
     AND year = '$YR'
     AND quarter = '$QTR')perf_pct,
  (SELECT rbate_id, NVL(lcm_clm_pct,0)as pct
   FROM rbate_reg.final_lcm_util
   WHERE lcm_type = '4'
      AND year = '$YR'
      AND quarter = '$QTR')perfinc_pct, 
  (SELECT rbate_id, NVL(lcm_clm_pct,0)as pct
   FROM rbate_reg.final_lcm_util
   WHERE lcm_type = '4E'
     AND year = '$YR' 
     AND quarter = '$QTR')perfplus_pct,  
  (SELECT rbate_id, NVL(lcm_clm_pct,0)as pct
   FROM rbate_reg.final_lcm_util
   WHERE lcm_type = '5'
      AND year = '$YR' 
      AND quarter = '$QTR')closed_pct  
  WHERE A.report_group_nbr = basic_pct.rbate_id (+)
    AND A.report_group_nbr = perf_pct.rbate_id (+)
    AND A.report_group_nbr = perfinc_pct.rbate_id (+)
    AND A.report_group_nbr = perfplus_pct.rbate_id (+)
    AND A.report_group_nbr = closed_pct.rbate_id (+)
    AND a.REPORT_GROUP_NBR = total1.REPORT_GROUP_NBR(+)
    AND a.report_group_nbr = total2.report_group_nbr(+)
    AND a.report_group_nbr = total3.report_group_nbr(+)
    AND a.rac = ad.rac(+)
  ORDER BY a.report_group_name;
  
  quit;


EOF99SQL
       
  $ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE
#-------------------------------------------------------------------------#
# Check Return code status for SQL execution                 
#-------------------------------------------------------------------------#
   if [[ $RETCODE != 0 ]]; then
      print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
      print "****  SQL  failed  ****  " $CYCLE_GID                              >> $OUTPUT_PATH/$LOG_FILE
      print "Error Message will be created"                                     >> $OUTPUT_PATH/$LOG_FILE
      print `date`                                                              >> $OUTPUT_PATH/$LOG_FILE
      print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
      break $RETCODE
   else
      print 'Creating FTP command for PUT ' $OUTPUT_PATH/$FILE_OUT ' to ' $FTP_NT_IP >> $OUTPUT_PATH/$LOG_FILE
      print 'cd /'$REBATES_DIR                                                  >> $OUTPUT_PATH/$FTP_CMDS
      print 'put ' $OUTPUT_PATH/$DAT_FILE_NBR $DAT_FILE_NBR ' (replace'         >> $OUTPUT_PATH/$FTP_CMDS
   fi
    

#-------------------------------------------------------------------------#
# FTP the report to an NT server                  
#-------------------------------------------------------------------------#
   if [[ $RETCODE = 0 ]]; then 
       print "quit"                                                             >> $OUTPUT_PATH/$FTP_CMDS
       print " "                                                                >> $OUTPUT_PATH/$LOG_FILE
       print "....Executing FTP  ...."                                          >> $OUTPUT_PATH/$LOG_FILE
       print `date`                                                             >> $OUTPUT_PATH/$LOG_FILE
       ftp -i $FTP_NT_IP < $OUTPUT_PATH/$FTP_CMDS                             >> $OUTPUT_PATH/$LOG_FILE
  
       export RETCODE=$?
  
       print ".... FTP complete   ...."                                         >> $OUTPUT_PATH/$LOG_FILE
       print `date`                                                             >> $OUTPUT_PATH/$LOG_FILE

   fi
fi

if [[ $RETCODE != 0 ]]; then
   print "                                                                 "    >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================"    >> $OUTPUT_PATH/$LOG_FILE
   print "  An error has occurred.  For FTP errors see " $OUTPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   print "  All other errors Look in " $OUTPUT_PATH/$LOG_FILE                   >> $OUTPUT_PATH/$LOG_FILE
   print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
      
   # Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export SCRIPTNAME=$OUTPUT_PATH/$SCRIPTNAME
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters"             >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOBNAME                                                 >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME                                           >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE                                                 >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4                                           >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5                                           >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******"                                >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh

   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

#-------------------------------------------------------------------------#
# Copy the log file over and end the job                  
#-------------------------------------------------------------------------#

print " "                                                                       >> $OUTPUT_PATH/$LOG_FILE
print "....Completed executing " $SCRIPT_PATH/$SCRIPTNAME " ...."               >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

