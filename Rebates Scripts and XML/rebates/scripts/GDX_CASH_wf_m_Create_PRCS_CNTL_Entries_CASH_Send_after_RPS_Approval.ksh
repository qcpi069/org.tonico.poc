#!/bin/ksh
#set -x 
#-------------------------------------------------------------------------#
#
# Script        : GDX_Run_CASH_wf_m_Create_PRCS_CNTL_Entries_CASH_Send_after_RPS_Approval.ksh   
# Title         : 
#
# Description   : Searches Cash Recon for RPS Approval Response files that are ready for process.   
#
# Maestro Job   : GD_3270  
#
# Parameters    : None
#
# Output        : Log file as $LOG_DIR/$LOG_FILE, 
#                
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 04-07-10   qcpi13c     Initial Creation
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_RCI_Environment.ksh
  . /home/user/udbcae/sqllib/db2profile


#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
   RETCODE=$1
   ERROR=$2
   EMAIL_SUBJECT=$SCRIPTNAME" Abended In "$REGION" "`date`

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   {
        print " "
        print $ERROR                                              
        print " "                                                
        print " !!! Aborting !!!" 
        print " "
        print "return_code = " $RETCODE
        print " "
        print " ------ Ending script " $SCRIPT `date`        
   }    >> $LOG_FILE

   mailx -s "$EMAIL_SUBJECT" $TO_MAIL                        < $LOG_FILE
   cp -f $LOG_FILE $LOG_FILE_ARCH 
   exit $RETCODE


}
#-------------------------------------------------------------------------#

# Variables
RETCODE=0
SCHEDULE="GDDY3000"
JOB="GD_3270"
FILE_BASE="GDX_Run_CASH_wf_m_Create_PRCS_CNTL_Entries_CASH_Send_after_RPS_Approval"
SCRIPTNAME=$FILE_BASE".ksh"

# LOG FILES
LOG_FILE_ARCH=$ARCH_LOG_DIR/$FILE_BASE".log."`date +"%Y%j%H%M"`
LOG_FILE="${LOG_DIR}/${FILE_BASE}.log"
ROW_CNT_FILE="${LOG_DIR}/${FILE_BASE}.dat"
INPUT_FILE_PREFIX=$INPUT_DIR/"pmt_txn_ack"
INPUT_FILE="pmt_txn_ack.dat"

# Cleanup from previous run
rm -f $LOG_FILE

function wait_for_incoming_stabilization {
	typeset check_interval=30
	typeset result=""
	typeset last_result=""
	while true; do
		result=`ls -l $INPUT_FILE_PREFIX.*.dat 2>/dev/null | sum`
		if [[ "$result" = "$last_result" ]]; then
			return
		fi
		echo `date +"[%H:%M:%S]"`" Waiting for file stabilization"
		sleep $check_interval
		last_result="$result"
	done
}

#-------------------------------------------------------------------------#
# Starting the script and log the starting time. 
#-------------------------------------------------------------------------#
   {
      print "Starting the script $SCRIPTNAME ......"                              
      print `date +"%D %r %Z"`
      print "********************************************"      
   }  >> $LOG_FILE


#-------------------------------------------------------------------------#
# Connect 
#-------------------------------------------------------------------------#
print " "  >> $LOG_FILE
sql="db2 -p connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"
db2 -p connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Error: couldn't connect to database " $SCRIPTNAME " ...          "            >> $LOG_FILE
   print "Return code is : <" $RETCODE ">"           >> $LOG_FILE
   exit_error $RETCODE
fi

#-------------------------------------------------------------------------#
# Search for available RPS Response files
#-------------------------------------------------------------------------#

#if [[ ! -f $INPUT_FILE ]]; then
for i in `ls $INPUT_FILE_PREFIX*.dat`
do
  echo "Reading $i ..."
  wait_for_incoming_stabilization
  INPUT_FILE=$i
  print "INPUT_FILE = $INPUT_FILE" >> $LOG_FILE
  break
done
#fi




if [[ -f $INPUT_FILE ]]; then
   SQL_STMNT="select count(*) from vrap.rcit_prcs_cntl pcnt where pcnt.prcs_cd = 21 and pcnt.prcs_stat_cd in (1,2,5,6,7) "
   print " "  >> $LOG_FILE
   print "We have New RPS Approval Response file. Now look to see if there are processes running or waiting "  >> $LOG_FILE
   print "SQL_STMNT is - $SQL_STMNT"  >> $LOG_FILE
   db2 -x $SQL_STMNT > $ROW_CNT_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print " "  >> $LOG_FILE
      print "ERROR: Select of row count from process control failed in " $SCRIPTNAME " ...          "            >> $LOG_FILE
      print "Return code is : <" $RETCODE ">"           >> $LOG_FILE
      exit_error $RETCODE
   fi
   read prcs_row_count < $ROW_CNT_FILE
   print " "  >> $LOG_FILE
   print "prcs_row_count = $prcs_row_count" >> $LOG_FILE

   if [[ $prcs_row_count -eq 0 ]]; then
      print " "  >> $LOG_FILE
      print "Rename $INPUT_FILE to $INPUT_FILE_PREFIX.dat ">>$LOG_FILE
      mv $INPUT_FILE $INPUT_FILE_PREFIX.dat
      print "We need to run the process. Submit the synchronous process"  >> $LOG_FILE      
    . $SCRIPTS_DIR/infa_pmcmd.ksh wf_m_Create_PRCS_CNTL_Entries_CASH_Send_after_RPS_Approval &
      RETCODE=$?
   else
      print " "  >> $LOG_FILE
      print "There are new RPS Approval response files "  >> $LOG_FILE 
      print "but the process controller is already prepared to handle them"  >> $LOG_FILE 
      print "or it is already running."  >> $LOG_FILE 
      print " "   >> $LOG_FILE
      print "********************************************"   >> $LOG_FILE
      print "Completing the script $SCRIPTNAME ..." `date +"%D %r %Z"` >> $LOG_FILE
      print "********************************************"   >> $LOG_FILE   
      RETCODE=$?
   fi
   if [[ $RETCODE != 0 ]]; then
      print " "  >> $LOG_FILE
      print "ERROR: Synchronous call " $SCRIPTNAME " ...          "            >> $LOG_FILE
      print "Return code is : <" $RETCODE ">"           >> $LOG_FILE
      exit_error $RETCODE
   else
      print " "  >> $LOG_FILE
      print "The Synchronous call was successfully performed. Process controller has been readied."  >> $LOG_FILE 
      print " "   >> $LOG_FILE
      print "********************************************"   >> $LOG_FILE
      print "Completing the script $SCRIPTNAME ..." `date +"%D %r %Z"` >> $LOG_FILE
      print "********************************************"   >> $LOG_FILE   
      RETCODE=$?
   fi
else
   print " "  >> $LOG_FILE
   print "There were no new RPS Approval Response files"  >> $LOG_FILE 
   print " "   >> $LOG_FILE
   print "********************************************"   >> $LOG_FILE
   print "Completing the script $SCRIPTNAME ..." `date +"%D %r %Z"` >> $LOG_FILE
   print "********************************************"   >> $LOG_FILE   
   RETCODE=$?
fi

cp -f $LOG_FILE $LOG_FILE_ARCH 

RETCODE=$?

exit $RETCODE

