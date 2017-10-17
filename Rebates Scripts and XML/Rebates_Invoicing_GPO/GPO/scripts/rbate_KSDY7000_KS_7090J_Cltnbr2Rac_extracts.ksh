#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KSDY7000_KS_7090J_CltNbr2Rac_extracts.ksh   
# Title         : .
#
# Description   : Extract for rebate registration Client Nbr to Rac extract 
#                 to the MVS
#                 
#                 
# Maestro Job   : KSDY7000 KS_7090J
#
# Parameters    : N/A - 
#                
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Project   Description
# ---------  ----------  -------------------------------------------------#
# 03-08-2004  S.Swanson            Initial Creation.
# 05/14/2004  S.Swanson            Walkthrough changes
# 03/11/2004  S.Swanson  6001583   Modify Query to assign SRX Rac and 
#                                  BlueRx RAC
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
# 07-21-2006  is51701    6005056   increase iterations to 12 to
#                                  handle  999 back bill limit.
# 10/26/2007  is51701    prj001079 increase iterations to 16 add
#                                  new retail/mail specialty
# 04/10/2008  is51701    35129     Add new RAC type for 90 Day prescript
#                                  at Retail
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh


if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration
     export ALTER_EMAIL_ADDRESS=''
     export MVS_DSN="PCS.P"
   if [[$QA_REGION ="true"]]; then
     export MVS_DSN="test.x"
     export ALTER_EMAIL_ADDRESS='' 
   fi
else
     export ALTER_EMAIL_ADDRESS=''  
     export REBATES_DIR=rebates_integration
     export MVS_DSN="test.d"
fi

 RETCODE=0
 SCHEDULE="KSDY7000"
 JOB="KS_7090J"
 FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_CltNbr2Rac_extrct"
 FILE_NAME=$JOB".PCS.P.KSZ4008"
 SCRIPTNAME=$FILE_BASE".ksh"
 LOG_FILE=$FILE_BASE".log"
 SQL_FILE=$FILE_BASE".sql"
 SQL_FILE_DATE_CNTRL=$FILE_BASE"_date_cntrl.sql"
 SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
 DAT_FILE=$FILE_NAME".dat"
 DATE_CNTRL_FILE=$FILE_BASE"_date_control_file.dat"
 FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
 FTP_NT_IP=204.99.4.30
 TARGET_FILE=$MVS_DSN".ksz4008j.ksz4ccrx"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$DAT_FILE
rm -f $OUTPUT_PATH/$DATE_CNTRL_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $INPUT_PATH/$SQL_FILE_DATE_CNTRL
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS




#---------------------------------------------------------------
#Set paramters to use in PL/SQL call.
#
#The month back starts at 0 (current month) and is increased by
#3 for each iteration.  We will pull back 16 quarters for this
#process.
#This script calculates the starting and ending date of each quarter.
#-----------------------------------------------------------------

#-----------------------------------------
#initialize month back to 0 or to parm
#initialize QTR_CNTR to 1
#-----------------------------------------

if [ $# -lt 1 ]
then 
  print " " >> $OUTPUT_PATH/$LOG_FILE
  print "MONTHS_BACK parameter not supplied. Use normal initialization." >> $OUTPUT_PATH/$LOG_FILE
  let MONTHS_BACK=0
else
  let MONTHS_BACK=$1
fi


let QTR_CTR=1

export QTR_CTR

#------------------------------------------------------
#Read Oracle to get the cycle-gid and beginning and end dates
#related to the last 5 quarters.\Oracle userid/password
#specific for DMARBAT2 ora.user used for rbate invoicing
#used to build date file only. changed to 12 interations 7/21/06
#changed iterations to 16 10/26/07 prj001079
#changed to 17 iterations 04/10/08
#------------------------------------------------------

while (($QTR_CTR <= 16));do

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

cat > $INPUT_PATH/$SQL_FILE_DATE_CNTRL << EOF
set LINESIZE 80
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
  from dma_rbate2.t_rbate_cycle
  where add_months(SYSDATE, - $MONTHS_BACK ) between CYCLE_START_DATE and CYCLE_END_DATE
   and substrb(rbate_CYCLE_GID,5,1) = '4'
;
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE_DATE_CNTRL

export RETCODE=$?


#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script if applicable
#-------------------------------------------------------------------------#
  export FIRST_READ=1
  while read rec_BEG_DATE rec_END_DATE rec_CYCLE_GID rec_QTR rec_YR YRMON rec_CYCSTRT rec_CYCEND; do
    if [[ $FIRST_READ != 1 ]]; then
      print 'FINISHING control file read' >> $OUTPUT_PATH/$LOG_FILE
    else
      export FIRST_READ=0
      print " " >> $OUTPUT_PATH/$LOG_FILE
      print "TODAYS DATE " `date` >> $OUTPUT_PATH/$LOG_FILE
      print "DAILY Client to Rac  EXTRACT " >> $OUTPUT_PATH/$LOG_FILE
      print "QUARTER CONTROL NUMBER " $QTR_CTR >> $OUTPUT_PATH/$LOG_FILE
      print ' ' >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
#Read the returned date control values one at a time and perform the extract
#for that Quarter
#-------------------------------------------------------------------------#

      print 'read record from control file' >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_BEG_DATE ' $rec_BEG_DATE >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_END_DATE ' $rec_END_DATE >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_CYCLE_GID ' $rec_CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_QTR ' $rec_QTR >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_YR ' $rec_YR >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_CYCSTRT ' $rec_CYCSTRT >> $OUTPUT_PATH/$LOG_FILE
      print 'rec_CYCEND ' $rec_CYCEND >> $OUTPUT_PATH/$LOG_FILE
      export BEGIN_DATE=$rec_BEG_DATE
      export END_DATE=$rec_END_DATE
      export CYCLE_GID=$rec_CYCLE_GID
      export QTR=$rec_QTR
      export YR=$rec_YR
      export YYYYMM=$YRMON
      export CYCSTRT=$rec_CYCSTRT
      export CYCEND=$rec_CYCEND
  fi
done < $OUTPUT_PATH/$DATE_CNTRL_FILE

#---------------------------------------------------------
#set MONTHS_BACK to another quarter back. (3, 6, 9, 12)
# Change Oracle userid/password to specific for 
#rbate_reg database.
# ora.user used for rbate invoicing
#---------------------------------------------------------
  let MONTHS_BACK=MONTHS_BACK+3
  
  db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# RAC DAILY EXTRACT
# Set up the Pipe file, then build and EXEC the new SQL.               
# Each quarter extract is built into a separate file then concatenated
# together prior to FTP to the MVS.
#-------------------------------------------------------------------------#
print `date` 'Beginning select of Client Nbr to RAC Extract ' >> $OUTPUT_PATH/$LOG_FILE

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
DAT_FILE_NBR=$DAT_FILE"_"$QTR_CTR
print 'dat_file_nbr ' $DAT_FILE_NBR >> $OUTPUT_PATH/$LOG_FILE
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE_NBR bs=100k &

cat > $INPUT_PATH/$SQL_FILE << EOF
set LINESIZE 800
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

SELECT
    lpad(rtrim(x.report_group_nbr),8,'0')
    ||'$YR'
    ||'$QTR'
    ||rpad(rtrim(x.rac),5,' ') --"retail"
    ||rpad(rtrim(mview.rac),5,' ')  --mail
    ||NVL(rpad(rtrim(srx.rac),5,' '),rpad(rtrim(x.rac),5,' ')) --specialty
    ||NVL(rpad(rtrim(blrx.rac),5,' '),rpad(rtrim(x.rac),5,' ')) --blue rx
    ||lpad(rtrim(x.client_nbr),8,'0')   
    ||NVL(rpad(rtrim(srxrtl.rac),5,' '),rpad(rtrim(x.rac),5,' ')) --specialty  srxrtl PRJ001079
    ||NVL(rpad(rtrim(srxml.rac),5,' '),rpad(rtrim(mview.rac),5,' ')) --specialty  srxml PRJ001079
    ||NVL(rpad(rtrim(d90.rac),5,' '),rpad(rtrim(x.rac),5,' ')) --90 day at retail 35129
FROM
        (select r.rac, c.report_group_nbr, c.client_nbr
         from
             RBATE_REG.rac r
            ,RBATE_REG.rac_client_assoc a
            ,RBATE_REG.client c
            ,RBATE_REG.rac_dspn_fcly_assoc d
            ,RBATE_REG.rebate_invoice I
         WHERE r.rac = d.rac
         AND   TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN d.rec_eff_dt AND d.rec_term_dt --@last_day_of_qtr
         AND  (d.dspn_fcly_type_cd = 'R' or dspn_fcly_type_cd = 'A')
         AND   r.rac = a.rac
         AND   TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN a.rec_eff_dt AND a.rec_term_dt  --@last_day_of_qtr
         AND   c.pcs_system_id = I.pcs_system_id            
         AND  (
               (Rebate_inv_term_dt BETWEEN TO_DATE('$CYCSTRT','MM/DD/YYYY') and TO_DATE('$CYCEND','MM/DD/YYYY')
               ) --BETWEEN @first_day_of_qtr and @last_day_of_qtr
                or rebate_inv_term_dt >= TO_DATE('$CYCEND','MM/DD/YYYY') --@last_day_of_qtr 
                or rebate_inv_term_dt IS NULL
              )             
         AND  c.client_nbr = a.client_nbr
        ) x
       ,(SELECT y.rac ,c1.client_nbr
         FROM
            RBATE_REG.rac y,
            RBATE_REG.rac_client_assoc a,
            RBATE_REG.client c1,
            RBATE_REG.rac_dspn_fcly_assoc d,
            RBATE_REG.rebate_invoice I
         WHERE  y.rac = d.rac
         AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN d.rec_eff_dt AND d.rec_term_dt   --@last_day_of_qtr
         AND   (d.dspn_fcly_type_cd = 'M' or d.dspn_fcly_type_cd = 'A')
         AND    y.rac = a.rac
         AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN a.rec_eff_dt AND a.rec_term_dt   --@last_day_of_qtr
         AND    c1.pcs_system_id = I.pcs_system_id          
         AND   (
                (Rebate_inv_term_dt BETWEEN TO_DATE('$CYCSTRT','MM/DD/YYYY') and TO_DATE('$CYCEND','MM/DD/YYYY')
                ) --BETWEEN @first_day_of_qtr and @last_day_of_qtr 
                or rebate_inv_term_dt >= TO_DATE('$CYCEND','MM/DD/YYYY') --@last_day_of_qtr 
                or rebate_inv_term_dt IS NULL
               )                
         AND   c1.client_nbr = a.client_nbr
        ) mview
        ,(SELECT distinct y.rac ,c1.client_nbr
                FROM
                   RBATE_REG.rac y,
                   RBATE_REG.rac_client_assoc a,
                   RBATE_REG.client c1,
                   RBATE_REG.rac_dspn_fcly_assoc d,
                   RBATE_REG.rebate_invoice I
                WHERE  y.rac = d.rac
                AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN d.rec_eff_dt AND d.rec_term_dt   --@last_day_of_qtr
                AND   (d.dspn_fcly_type_cd = 'S')
                AND    y.rac = a.rac
                AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN a.rec_eff_dt AND a.rec_term_dt   --@last_day_of_qtr
                AND    c1.pcs_system_id = I.pcs_system_id          
                AND   (
                       (Rebate_inv_term_dt BETWEEN TO_DATE('$CYCSTRT','MM/DD/YYYY') and TO_DATE('$CYCEND','MM/DD/YYYY')
                       ) --BETWEEN @first_day_of_qtr and @last_day_of_qtr 
                       or rebate_inv_term_dt >= TO_DATE('$CYCEND','MM/DD/YYYY') --@last_day_of_qtr 
                       or rebate_inv_term_dt IS NULL
                      )                
                AND   c1.client_nbr = a.client_nbr
        ) srx
       ,(SELECT distinct y.rac ,c1.client_nbr
                       FROM
                          RBATE_REG.rac y,
                          RBATE_REG.rac_client_assoc a,
                          RBATE_REG.client c1,
                          RBATE_REG.rac_dspn_fcly_assoc d,
                          RBATE_REG.rebate_invoice I
                       WHERE  y.rac = d.rac
                       AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN d.rec_eff_dt AND d.rec_term_dt   --@last_day_of_qtr
                       AND   (d.dspn_fcly_type_cd = 'B')
                       AND    y.rac = a.rac
                       AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN a.rec_eff_dt AND a.rec_term_dt   --@last_day_of_qtr
                       AND    c1.pcs_system_id = I.pcs_system_id          
                       AND   (
                              (Rebate_inv_term_dt BETWEEN TO_DATE('$CYCSTRT','MM/DD/YYYY') and TO_DATE('$CYCEND','MM/DD/YYYY')
                              ) --BETWEEN @first_day_of_qtr and @last_day_of_qtr 
                              or rebate_inv_term_dt >= TO_DATE('$CYCEND','MM/DD/YYYY') --@last_day_of_qtr 
                              or rebate_inv_term_dt IS NULL
                             )                
                       AND   c1.client_nbr = a.client_nbr
        ) blrx
       ,(SELECT distinct y.rac ,c1.client_nbr
                FROM
                   RBATE_REG.rac y,
                   RBATE_REG.rac_client_assoc a,
                   RBATE_REG.client c1,
                   RBATE_REG.rac_dspn_fcly_assoc d,
                   RBATE_REG.rebate_invoice I
                WHERE  y.rac = d.rac
                AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN d.rec_eff_dt AND d.rec_term_dt   --@last_day_of_qtr
                AND   (d.dspn_fcly_type_cd = 'SR' or d.dspn_fcly_type_cd = 'S')
                AND    y.rac = a.rac
                AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN a.rec_eff_dt AND a.rec_term_dt   --@last_day_of_qtr
                AND    c1.pcs_system_id = I.pcs_system_id          
                AND   (
                       (Rebate_inv_term_dt BETWEEN TO_DATE('$CYCSTRT','MM/DD/YYYY') and TO_DATE('$CYCEND','MM/DD/YYYY')
                       ) --BETWEEN @first_day_of_qtr and @last_day_of_qtr 
                       or rebate_inv_term_dt >= TO_DATE('$CYCEND','MM/DD/YYYY') --@last_day_of_qtr 
                       or rebate_inv_term_dt IS NULL
                      )                
                AND   c1.client_nbr = a.client_nbr
        ) srxrtl
        ,(SELECT distinct y.rac ,c1.client_nbr
                FROM
                   RBATE_REG.rac y,
                   RBATE_REG.rac_client_assoc a,
                   RBATE_REG.client c1,
                   RBATE_REG.rac_dspn_fcly_assoc d,
                   RBATE_REG.rebate_invoice I
                WHERE  y.rac = d.rac
                AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN d.rec_eff_dt AND d.rec_term_dt   --@last_day_of_qtr
                AND   (d.dspn_fcly_type_cd = 'SM' or d.dspn_fcly_type_cd = 'S')
                AND    y.rac = a.rac
                AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN a.rec_eff_dt AND a.rec_term_dt   --@last_day_of_qtr
                AND    c1.pcs_system_id = I.pcs_system_id          
                AND   (
                       (Rebate_inv_term_dt BETWEEN TO_DATE('$CYCSTRT','MM/DD/YYYY') and TO_DATE('$CYCEND','MM/DD/YYYY')
                       ) --BETWEEN @first_day_of_qtr and @last_day_of_qtr 
                       or rebate_inv_term_dt >= TO_DATE('$CYCEND','MM/DD/YYYY') --@last_day_of_qtr 
                       or rebate_inv_term_dt IS NULL
                      )                
                AND   c1.client_nbr = a.client_nbr
        ) srxml
        ,(SELECT distinct y.rac ,c1.client_nbr
                FROM
                   RBATE_REG.rac y,
                   RBATE_REG.rac_client_assoc a,
                   RBATE_REG.client c1,
                   RBATE_REG.rac_dspn_fcly_assoc d,
                   RBATE_REG.rebate_invoice I
                WHERE  y.rac = d.rac
                AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN d.rec_eff_dt AND d.rec_term_dt   --@last_day_of_qtr
                AND   (d.dspn_fcly_type_cd = 'DS')
                AND    y.rac = a.rac
                AND    TO_DATE('$CYCEND','MM/DD/YYYY') BETWEEN a.rec_eff_dt AND a.rec_term_dt   --@last_day_of_qtr
                AND    c1.pcs_system_id = I.pcs_system_id          
                AND   (
                       (Rebate_inv_term_dt BETWEEN TO_DATE('$CYCSTRT','MM/DD/YYYY') and TO_DATE('$CYCEND','MM/DD/YYYY')
                       ) --BETWEEN @first_day_of_qtr and @last_day_of_qtr 
                       or rebate_inv_term_dt >= TO_DATE('$CYCEND','MM/DD/YYYY') --@last_day_of_qtr 
                       or rebate_inv_term_dt IS NULL
                      )                
                AND   c1.client_nbr = a.client_nbr
        ) d90
  where x.client_nbr = mview.client_nbr
    and x.client_nbr = srx.client_nbr(+)
    and x.client_nbr = blrx.client_nbr(+)
    and x.client_nbr = srxrtl.client_nbr(+)      
    and x.client_nbr = srxml.client_nbr(+)
    and x.client_nbr = d90.client_nbr(+)
  order by 1;
                    
quit;
EOF


$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

export RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print 'SQL FAILURE SELECTING EXTRACT DATA LOOP NBR. ' $QTR_CTR >> $OUTPUT_PATH/$LOG_FILE
    let QTR_CTR=100
    
    print 'quarter counter ' $QTR_CTR >> $OUTPUT_PATH/$LOG_FILE
else
    let QTR_CTR=QTR_CTR+1
    
    cat $OUTPUT_PATH/$DAT_FILE_NBR >> $OUTPUT_PATH/$DAT_FILE
    
    if [[ $? = 0 ]];then
      rm -f $OUTPUT_PATH/$DAT_FILE_NBR
    else
      let QTR_CTR=200
      print 'CONCATENATION DAT_FILE_NBR to DAT_FILE FAILED.'
    fi
fi


done

if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed select of Client Nbr to RAC Extract ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTPing files ' >> $OUTPUT_PATH/$LOG_FILE
   #FTP to the MVS
   
   
   print 'put ' $OUTPUT_PATH/$DAT_FILE " '"$TARGET_FILE"' " ' (replace'     >> $INPUT_PATH/$FTP_CMDS
   print 'quit'                                                      >> $INPUT_PATH/$FTP_CMDS
   ftp -i  $FTP_NT_IP < $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTP complete ' >> $OUTPUT_PATH/$LOG_FILE
   cat $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
else


   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Extract ' >> $OUTPUT_PATH/$LOG_FILE
   
   print 'Client Nbr to RAC Extract RETURN CODE is : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE

   print " " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE       >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

rm -f $INPUT_PATH/$SQL_FILE_DATE_CNTRL
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

