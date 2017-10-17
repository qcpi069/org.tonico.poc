#!/bin/ksh
#set -x 
#-------------------------------------------------------------------------#
#
# Script        : GGDX_CASH_wf_m_Create_PRCS_CNTL_Entries_for_NewCopyVoid_Recon_Summaries.ksh   
# Title         : 
#
# Description   : Searches Cash Recon for New and CopyVoid Recons waiting to be submitted
#                 to the Cash Recon process controller.  If any are found then 
#                 it will submit the New recons and CopyVoids directly to the
#                 process controller before submitting the jobs for the Recon summaries
#                 and snapshots.
#
# Maestro Job   : RDDY1500 RD_1506J
#
# Parameters    : None
#
# Output        : Log file as $LOG_DIR/$LOG_FILE, 
#                
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 04-11-13   qcpi733     Initial Creation for ITPR0001971
# 07-15-13   qcpue98u    Heat # 08117913  Break-fix to correct infinite loop and process controller
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
SCHEDULE="TBD"
JOB="TBD"
FILE_BASE="GDX_CASH_wf_m_Create_PRCS_CNTL_Entries_for_NewCopyVoid_Recon_Summaries"
SCRIPTNAME=$FILE_BASE".ksh"

# LOG FILES
LOG_FILE_ARCH=$ARCH_LOG_DIR/$FILE_BASE".log."`date +"%Y%j%H%M"`
LOG_FILE="${LOG_DIR}/${FILE_BASE}.log"
ROW_CNT_FILE="${LOG_DIR}/${FILE_BASE}.dat"
PRCS_CNTL_ROW_CNT=${LOG_DIR}/${FILE_BASE}"_PRCS_CNTL_CNT.dat"

# Cleanup from previous run
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time. 
#-------------------------------------------------------------------------#
   {
      print "Starting the script $SCRIPTNAME ......"                              
      print `date +"%D %r %Z"`
      print "********************************************"      
   }                                                                           >> $LOG_FILE


#-------------------------------------------------------------------------#
# Connect 
#-------------------------------------------------------------------------#
print " "  >> $LOG_FILE
sql="db2 -p connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"
db2 -p connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Error: couldn't connect to database " $SCRIPTNAME " ...          "   >> $LOG_FILE
   print "Return code is : <" $RETCODE ">"                                     >> $LOG_FILE
   exit_error $RETCODE
fi

#-------------------------------------------------------------------------#
# Search for available new Recons
#-------------------------------------------------------------------------#

SQL_STMNT="Select (count(*)+9)/10 from vrap.rcnt_recn_hdr hdr where hdr.recn_stat_cd = 1 "

print " "                                                                      >> $LOG_FILE
print "Look for New Recons to load "                                           >> $LOG_FILE
print "SQL_STMNT is - $SQL_STMNT"                                              >> $LOG_FILE
db2 -x $SQL_STMNT > $ROW_CNT_FILE
RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print " "                                                                   >> $LOG_FILE
   print "ERROR: Select of row count from recon header failed in " $SCRIPTNAME " ...          "            >> $LOG_FILE
   print "Return code is : <" $RETCODE ">"                                     >> $LOG_FILE
   exit_error $RETCODE
fi

read nr_row_count < $ROW_CNT_FILE
print "nr_row_count=$nr_row_count"                                           >> $LOG_FILE

SQL_STMNT="Select count(1) from vrap.rcit_prcs_cntl pcnt where pcnt.prcs_cd = 15 and pcnt.prcs_stat_cd in (1,2,5,6,7) "

print " "                                                                      >> $LOG_FILE
print "Count From Process Controller for New Recons loading "                                           >> $LOG_FILE
print "SQL_STMNT is - $SQL_STMNT"                                              >> $LOG_FILE
db2 -x $SQL_STMNT > $PRCS_CNTL_ROW_CNT
RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print " "                                                                   >> $LOG_FILE
   print "ERROR: Select of row count from Process Controller failed in " $SCRIPTNAME " ...          "            >> $LOG_FILE
   print "Return code is : <" $RETCODE ">"                                     >> $LOG_FILE
   exit_error $RETCODE
fi

read pr_nr_row_count < $PRCS_CNTL_ROW_CNT				
print "pr_nr_row_count = $pr_nr_row_count"				     >> $LOG_FILE

    nr_row_count=`expr $nr_row_count - $pr_nr_row_count` 

if [[ $nr_row_count -gt 0 ]]; then

    while [ $nr_row_count -gt 0 ]
      do
        print " "                                                              >> $LOG_FILE
        print "Found recons to submit, need to submit this "$nr_row_count
        print "Submitting up to 10 new recons to the process controller."      >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        . $SCRIPTS_DIR/infa_pmcmd.ksh wf_m_Create_PRCS_CNTL_Entries_CASH_Claims_Detail_Load_NEW >> $LOG_FILE
        print "New recons submitted to process controller"                     >> $LOG_FILE
	
	nr_row_count=`expr $nr_row_count - 1` 
    
    done

    print " "                                                                  >> $LOG_FILE
    print "Done submitting New recons to the Cash Process Controller"          >> $LOG_FILE 
    print " "                                                                  >> $LOG_FILE
else
    print " "                                                                  >> $LOG_FILE
    print "There were no new Recons in the Recon header table"                 >> $LOG_FILE 
    print " "                                                                  >> $LOG_FILE
fi
####### end new recon header submission


####### start copy/void recon header submission
#-------------------------------------------------------------------------#
# Search for available CopyVoid Recons
#-------------------------------------------------------------------------#

rm -f $SQL_STMNT
rm -f $ROW_CNT_FILE
rm -f $PRCS_CNTL_ROW_CNT

SQL_STMNT="Select (count(*)+9)/10 from vrap.rcnt_recn_hdr hdr where hdr.recn_stat_cd = 15 "

print " "                                                                      >> $LOG_FILE
print "Look for CopyVoid Recons to load "                                      >> $LOG_FILE
print "SQL_STMNT is - $SQL_STMNT"                                              >> $LOG_FILE
db2 -x $SQL_STMNT > $ROW_CNT_FILE
RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print " "                                                                   >> $LOG_FILE
   print "ERROR: Select of row count from recon header failed "                >> $LOG_FILE
   print "Return code is : <" $RETCODE ">"                                     >> $LOG_FILE
   exit_error $RETCODE
fi


read cv_row_count < $ROW_CNT_FILE
print "cv_row_count = $cv_row_count"                                           >> $LOG_FILE

SQL_STMNT="select count(1) from vrap.rcit_prcs_cntl pcnt where pcnt.prcs_cd = 16 and pcnt.prcs_stat_cd in (1,2,5,6,7) "

print " "                                                                      >> $LOG_FILE
print "Count From Process Controller - CopyVoid Recons loading "               >> $LOG_FILE
print "SQL_STMNT is - $SQL_STMNT"                                              >> $LOG_FILE
db2 -x $SQL_STMNT > $PRCS_CNTL_ROW_CNT
RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print " "                                                                   >> $LOG_FILE
   print "ERROR: Select of row count from Process Controller failed "                >> $LOG_FILE
   print "Return code is : <" $RETCODE ">"                                     >> $LOG_FILE
   exit_error $RETCODE
fi


read pr_cv_row_count < $PRCS_CNTL_ROW_CNT
print "pr_cv_row_count = $pr_cv_row_count"                                           >> $LOG_FILE

    cv_row_count=`expr $cv_row_count - $pr_cv_row_count` 

if [[ $cv_row_count -gt 0 ]]; then

    while [ $cv_row_count -gt 0 ]
      do
        print " "                                                              >> $LOG_FILE
        print "Found recons to submit, need to submit this "$cv_row_count      >> $LOG_FILE
        print "Submitting up to 10 CopyVoid recons to the process controller." >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        . $SCRIPTS_DIR/infa_pmcmd.ksh wf_m_Create_PRCS_CNTL_Entries_CASH_Claims_Detail_Load_CopyVoid  >> $LOG_FILE
        print "New recons submitted to process controller"                     >> $LOG_FILE

	cv_row_count=`expr $cv_row_count - 1` 
    done

    print " "                                                                  >> $LOG_FILE
    print "Done submitting CopyVoid recons to the Cash Process Controller"     >> $LOG_FILE 
    print " "                                                                  >> $LOG_FILE

else
    print " "                                                                  >> $LOG_FILE
    print "There were no CopyVoid Recons in the Recon header table"            >> $LOG_FILE 
    print " "                                                                  >> $LOG_FILE
fi
rm -f $SQL_STMNT
rm -f $ROW_CNT_FILE
rm -f $PRCS_CNTL_ROW_CNT

####### end new recon header submission


## Submit the process for the Cash Recon summary and current snapshot process
. $SCRIPTS_DIR/infa_pmcmd.ksh wf_m_Create_PRCS_CNTL_Entries_CASH_Recon_Summary_and_Curr_Snap


print "********************************************"                           >> $LOG_FILE
print "Completing the script $SCRIPTNAME ..." `date +"%D %r %Z"`               >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE   

cp -f $LOG_FILE $LOG_FILE_ARCH 

RETCODE=$?

exit $RETCODE

