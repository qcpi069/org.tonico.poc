#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_index_rebuild.ksh   
# Description   : This script executes procedure
#                 pk_cycle_util.rebuild_all_idx_parts which rebuilds the 
#                 secondary indicies on table s_claim_rbate_cycle. The 
#                 partition for s_claim_rbate_cycle is passed in through
#                 the trigger file. 
#                 
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 
# 01-03-2003  NTucker    Initial Creation.
#
#-------------------------------------------------------------------------#
#     
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

rm -f $OUTPUT_PATH/rbate_index_rebuild.log

export FILE_NAME=restore_scrc_idx_rebuilds.trigger
export DBMS_OUTPUT_DIR=/staging/rebate2/

#-------------------------------------------------------------------------#
# Check for existance of the trigger file. If it doesn't exist, exit
# else get the partition name from the file.
#-------------------------------------------------------------------------#

 if [[ ! -s $DBMS_OUTPUT_DIR$FILE_NAME ]];
 then
    print ' ' >> $OUTPUT_PATH/rbate_index_rebuild.log
    print 'trigger file doesnt exist or is empty.' >> $OUTPUT_PATH/rbate_index_rebuild.log
    print ' ' >> $OUTPUT_PATH/rbate_index_rebuild.log
    exit 
 fi 

export PARTITION=`cat $DBMS_OUTPUT_DIR$FILE_NAME`


#-------------------------------------------------------------------------#
# Set and display special env vars used for this script
#-------------------------------------------------------------------------#

export TABLE_NAME=S_CLAIM_RBATE_CYCLE
export PACKAGE_NAME=dma_rbate2.pk_cycle_util.rebuild_all_idx_parts


PKGEXEC=$PACKAGE_NAME\(\'$TABLE_NAME\'\,\'$PARTITION\'\);

print ' ' >> $OUTPUT_PATH/rbate_index_rebuild.log
print 'Exec stmt is '$PKGEXEC >> $OUTPUT_PATH/rbate_index_rebuild.log

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#-------------------------------------------------------------------------#

rm -f $INPUT_PATH/rbate_index_rebuild.sql
rm -f $OUTPUT_PATH/rbate_index_rebuild.sqllog

cat > $INPUT_PATH/rbate_index_rebuild.sql << EOF
set serveroutput on size 1000000
whenever sqlerror exit 1
SPOOL $OUTPUT_PATH/rbate_index_rebuild.sqllog
SET TIMING ON
exec $PKGEXEC;
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/rbate_index_rebuild.sql

export RETCODE=$?

cat $OUTPUT_PATH/rbate_index_rebuild.sqllog >> $OUTPUT_PATH/rbate_index_rebuild.log


#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/rbate_index_rebuild.log
   print "================= J O B  A B E N D E D ==================" >> $OUTPUT_PATH/rbate_index_rebuild.log
   print "  Error Executing rbate_index_rebuild.ksh                " >> $OUTPUT_PATH/rbate_index_rebuild.log
   print "  Look in "$OUTPUT_PATH/rbate_index_rebuild.log            >> $OUTPUT_PATH/rbate_index_rebuild.log
   print "=========================================================" >> $OUTPUT_PATH/rbate_index_rebuild.log
            
# Send the Email notification 
   export JOBNAME="RIHR2060 / RI_2060J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_index_rebuild.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_index_rebuild.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_index_rebuild.log
   print "JOBNAME is    " $JOBNAME                                  >> $OUTPUT_PATH/rbate_index_rebuild.log 
   print "SCRIPTNAME is " $SCRIPTNAME                               >> $OUTPUT_PATH/rbate_index_rebuild.log
   print "LOGFILE is    " $LOGFILE                                  >> $OUTPUT_PATH/rbate_index_rebuild.log
   print "EMAILPARM4 is " $EMAILPARM4                               >> $OUTPUT_PATH/rbate_index_rebuild.log
   print "EMAILPARM5 is " $EMAILPARM5                               >> $OUTPUT_PATH/rbate_index_rebuild.log
   print "****** end of email parameters ******"                    >> $OUTPUT_PATH/rbate_index_rebuild.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/rbate_index_rebuild.log $LOG_ARCH_PATH/rbate_index_rebuild.log.`date +"%Y%j%H%M"`
   exit 1
fi

#-------------------------------------------------------------------------#
# Remove the trigger file. We must wait for the cron job that makes the 
# file writeable before it can be deleted.                
#-------------------------------------------------------------------------#

export FILE_READ_ONLY=TRUE
 
while [[ $FILE_READ_ONLY = 'TRUE' ]]; do

  if [[ -w $DBMS_OUTPUT_DIR$FILE_NAME ]];
  then
     rm $DBMS_OUTPUT_DIR$FILE_NAME
     export FILE_READ_ONLY=FALSE
  else
     print "**************************************" >> $OUTPUT_PATH/rbate_index_rebuild.log 
     print "* Trigger file still in read only    *" >> $OUTPUT_PATH/rbate_index_rebuild.log 
     print "* going to sleep for 15 min          *" >> $OUTPUT_PATH/rbate_index_rebuild.log 
     print "*" `date`                               >> $OUTPUT_PATH/rbate_index_rebuild.log 
     print "**************************************" >> $OUTPUT_PATH/rbate_index_rebuild.log 
    
     sleep 900
  fi
    
done

print '....Completed executing rbate_index_rebuild.ksh ....'   >> $OUTPUT_PATH/rbate_index_rebuild.log
mv -f $OUTPUT_PATH/rbate_index_rebuild.log $LOG_ARCH_PATH/rbate_index_rebuild.log.`date +"%Y%j%H%M"`


exit $RETCODE

