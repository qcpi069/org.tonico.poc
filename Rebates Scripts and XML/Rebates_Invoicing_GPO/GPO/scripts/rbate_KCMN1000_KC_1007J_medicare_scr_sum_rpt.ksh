#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_KCMN1000_KC_1007J_medicare_scr_sum_rpt.ksh
# Description  = Create the post-gather claim summary report from the 
#		   s_claim_rbate_medicare table. 
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
# 05/19/04  is31701                 initial script creation
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
#==============================================================================
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh


#--re-route DEV and QA Error E-mails to nick tucker
if [[ $REGION = "prod" ]];   then 
  if [[ $QA_REGION = "true" ]];   then                                       
    #--Running in the QA region                                               
    export ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'                  
  else                                                                       
    #--Running in Prod region                                                 
    export ALTER_EMAIL_ADDRESS=''                                            
  fi                                                                         
else                                                                         
  #--Running in Development region                                            
  export ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'                    
fi                                                                           


export EXEC_EMAIL=$SCRIPT_PATH"/rbate_email_base.ksh"
export JOB="KC_1007J"
export SCHEDULE="KCMN1000"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_medicare_scr_sum_rpt"
export SCRIPT_NAME=$SCRIPT_PATH"/"$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export LOG_ARCH=$FILE_BASE".log"
export SQL_FILE=$FILE_BASE".sql"
export SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
export DAT_FILE=$FILE_BASE".dat"
export LOG_SQL_FILE=$OUTPUT_PATH/$FILE_BASE".sqllog"
export USER_PSWRD=`cat $SCRIPT_PATH/ora_user.fil`
export FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports

export DATE_CNTRL_FILE="rbate_KCMN1000_KC_1000J_medicare_date_control_file.dat"

#--Delete the output log and sql file from previous execution if it exists.
rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$LOG_SQL_FILE

print 'getting ready to read record from control file' >> $OUTPUT_PATH/$LOG_FILE

export FIRST_READ=1
while read REC_BEG_DATE REC_END_DATE REC_CYCLE_GID; do
  if [[ $FIRST_READ != 1 ]]; then
    print 'Finishing control file read' >> $OUTPUT_PATH/$LOG_FILE
  else
    export FIRST_READ=0
    print 'read record from control file'  >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_BEG_DATE ' $REC_BEG_DATE    >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_END_DATE ' $REC_END_DATE    >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_CYCLE_GID ' $REC_CYCLE_GID  >> $OUTPUT_PATH/$LOG_FILE
    export BEGIN_DATE=$REC_BEG_DATE
    export END_DATE=$REC_END_DATE
    export CYCLE_GID=$REC_CYCLE_GID
  fi
done < $INPUT_PATH/$DATE_CNTRL_FILE

print 'Done reading record from control file' >> $OUTPUT_PATH/$LOG_FILE

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE bs=100k &

#--build the sql file for SQLPLUS

cat > $INPUT_PATH/$SQL_FILE << EOF

set LINESIZE 200
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
spool $OUTPUT_PATH/$SQL_PIPE_FILE;

alter session enable parallel dml; 

SELECT distinct  
    scra1v.feed_id
   ,','
   ,scra1v.extnl_src_code
   ,','
   ,scra1v.extnl_lvl_id1  
   ,','
   ,scra1v.total_count
   ,','
   ,scra2v.excpt_id   
   ,','  
   ,NVL(scra2v.excpt_id_count,0)
   ,','
 FROM (select /*+ full(scra1) parallel(scra1,12) */
             scra1.feed_id
            ,scra1.extnl_src_code
            ,nvl(scra1.extnl_lvl_id1,'_NVL_') extnl_lvl_id1
            ,count(*) as total_count
        FROM dma_rbate2.s_claim_rbate_medicare scra1
       WHERE scra1.cycle_gid = $CYCLE_GID
       group by scra1.feed_id
               ,scra1.extnl_src_code
               ,scra1.extnl_lvl_id1   
     ) scra1v
    ,(select /*+ full(scra2) parallel(scra2,12) */
             scra2.feed_id
            ,scra2.extnl_src_code
            ,nvl(scra2.extnl_lvl_id1,'_NVL_') extnl_lvl_id1
            ,scra2.excpt_id 
            ,count(*) as excpt_id_count
        FROM dma_rbate2.s_claim_rbate_medicare scra2
       WHERE scra2.cycle_gid = $CYCLE_GID         
            and scra2.excpt_id is not NULL
       group by scra2.feed_id
               ,scra2.extnl_src_code
               ,scra2.extnl_lvl_id1
               ,scra2.excpt_id   
     ) scra2v
WHERE scra1v.feed_id = scra2v.feed_id(+)
  and scra1v.extnl_src_code = scra2v.extnl_src_code(+)
  and scra1v.extnl_lvl_id1 = scra2v.extnl_lvl_id1(+)
ORDER BY scra1v.feed_id
        ,scra1v.extnl_src_code
        ,scra1v.extnl_lvl_id1
        ,scra2v.excpt_id;

quit;
EOF

print 'Done building sql - getting ready to execute' >> $OUTPUT_PATH/$LOG_FILE

$ORACLE_HOME/bin/sqlplus -s $USER_PSWRD @$INPUT_PATH/$SQL_FILE

ORA_RETCODE=$?

#cat $LOG_SQL_FILE >> $OUTPUT_PATH/$LOG_FILE

print 'Done executing sql - getting ready to ftp' >> $OUTPUT_PATH/$LOG_FILE
#--Process the Return Code

if [[ $ORA_RETCODE = 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTPing files ' >> $OUTPUT_PATH/$LOG_FILE
   export FTP_NT_IP=AZSHISP00
   export FTP_FILE=$FILE_BASE"_"$CYCLE_GID".txt"
   rm -f $INPUT_PATH/$FTP_CMDS
   print 'cd /'$REBATES_DIR                                          >> $INPUT_PATH/$FTP_CMDS
   print 'put ' $OUTPUT_PATH/$DAT_FILE $FTP_FILE ' (replace' >> $INPUT_PATH/$FTP_CMDS
   print 'quit'                                                      >> $INPUT_PATH/$FTP_CMDS
   ftp -i  $FTP_NT_IP < $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   FTP_RETCODE=$?
   if [[ $FTP_RETCODE = 0 ]]; then
      print ' ' >> $OUTPUT_PATH/$LOG_FILE
      print `date` 'FTP  of ' $OUTPUT_PATH/$DAT_FILE ' to ' $FTP_FILE ' complete '           >> $OUTPUT_PATH/$LOG_FILE
      RETCODE=$FTP_RETCODE
   else
      RETCODE=$FTP_RETCODE
   fi    
else
   RETCODE=$ORA_RETCODE
fi

if [[ $RETCODE != 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure Creating Medicare SCR Sum Rpt ' 	     >> $OUTPUT_PATH/$LOG_FILE
   print 'Oracle RETURN CODE is : ' $ORA_RETCODE             >> $OUTPUT_PATH/$LOG_FILE
   print 'FTP RETURN CODE is    : ' $FTP_RETCODE             >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
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

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

