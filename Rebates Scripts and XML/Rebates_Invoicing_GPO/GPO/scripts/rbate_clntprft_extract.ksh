#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_clntprft_extract.ksh  
# Title         : 
#
#
#   Date     Name           Description
# ---------  ----------  -------------------------------------------------#
# 02-20-03    K. Kollipara  Initial Creation. 
# 06-30-03    Gopi P        Changed reference from  refresh validator table
#                           to t_rbate table.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

export LOG_FILE=rbate_clntprft_extract.log
export FTP_NT_IP=DMADOM4
export FILEOUT=CP_RBATELCM.txt
export TRGFILE=CP_RBATELCM.trg
export TMPFILE=tmp.txt
export SQLFILE=rbate_clntprft_extract.sql
export COMFILE=rbate_clntprft_extract_ftpcommands.txt
export PROVIDED=N
export SCHEMA=dma_rbate2

rm -f $OUTPUT_PATH/$LOG_FILE

print 'Starting rbate_clntprft_extract.ksh' > $OUTPUT_PATH/$LOG_FILE

if [[ $# -eq 1 ]]; then
    print '                   '      >> $OUTPUT_PATH/$LOG_FILE
    print 'Feed date provided '      >> $OUTPUT_PATH/$LOG_FILE
    MONTH=`echo $1 |cut -c 5-6`
    YEAR=`echo $1 |cut -c 1-4`
    PROVIDED=Y
    print '                   '      >> $OUTPUT_PATH/$LOG_FILE
    print 'Extract Year  is: '$YEAR  >> $OUTPUT_PATH/$LOG_FILE
    print '                   '      >> $OUTPUT_PATH/$LOG_FILE
    print 'Extract Month is: '$MONTH >> $OUTPUT_PATH/$LOG_FILE
    print '                   '      >> $OUTPUT_PATH/$LOG_FILE
else
    print '                       '    >> $OUTPUT_PATH/$LOG_FILE
    print 'Feed date not provided '    >> $OUTPUT_PATH/$LOG_FILE
    print 'Running with default date ' >> $OUTPUT_PATH/$LOG_FILE
    print '                       '    >> $OUTPUT_PATH/$LOG_FILE
fi

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

rm -f $INPUT_PATH/$SQLFILE
rm -f $OUTPUT_PATH/$COMFILE
rm -f $OUTPUT_PATH/$FILEOUT
rm -f $OUTPUT_PATH/$TMPFILE
rm -f $OUTPUT_PATH/$TRGFILE

if [[ $PROVIDED = 'N' ]]; then
SQL_STRING="select  rf.extnl_src_code, rf.extnl_lvl_id1, rf.lcm_code, rf.clm_qty \
            from \
               ( \
                 select a.extnl_src_code, a.extnl_lvl_id1, a.lcm_code, count(a.claim_gid) clm_qty , \
                        row_number() over (partition by extnl_src_code, extnl_lvl_id1 order by count(claim_gid) desc ) RN \
                 from  $SCHEMA.t_rbate a \
                 where a.lcm_code is not null \
                   and a.cycle_gid =  (select rbate_cycle_gid \
   	  			         from $SCHEMA.t_rbate_cycle \
				       where add_months(sysdate, -1) between cycle_start_date and cycle_end_date \
					 and rbate_cycle_type_id = 2 \
				      )	\
                 group by a.extnl_src_code, a.extnl_lvl_id1, a.lcm_code \
                 order by a.extnl_src_code, a.extnl_lvl_id1, a.lcm_code \
               ) rf \
            where RN=1 \
            order by rf.extnl_src_code, rf.extnl_lvl_id1;"
else
print 'Running the SQL with provided feed date'   >> $OUTPUT_PATH/$LOG_FILE
SQL_STRING="select  rf.extnl_src_code, rf.extnl_lvl_id1, rf.lcm_code, rf.clm_qty \
            from \
               ( \
                 select a.extnl_src_code, a.extnl_lvl_id1, a.lcm_code, count(a.claim_gid) clm_qty , \
                        row_number() over (partition by extnl_src_code, extnl_lvl_id1 order by count(claim_gid) desc ) RN \
                 from  $SCHEMA.t_rbate a \
                 where a.lcm_code is not null \
                   and a.cycle_gid =  (select rbate_cycle_gid \
   	  			         from $SCHEMA.t_rbate_cycle \
				        where to_date('$1', 'yyyymm') between cycle_start_date and cycle_end_date \
					  and rbate_cycle_type_id = 2 \
				      )	\
                 group by a.extnl_src_code, a.extnl_lvl_id1, a.lcm_code \
                 order by a.extnl_src_code, a.extnl_lvl_id1, a.lcm_code \
               ) rf \
            where RN=1 \
            order by rf.extnl_src_code, rf.extnl_lvl_id1;"
fi

cat > $INPUT_PATH/$SQLFILE << EOF
SET LINESIZE 87
SET TERMOUT OFF
SET PAGESIZE 0
SET NEWPAGE 0
SET SPACE 0
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET WRAP OFF
set verify off
whenever sqlerror exit 1
spool $OUTPUT_PATH/$TMPFILE
$SQL_STRING
quit; 
 
EOF

cd $SCRIPT_PATH

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQLFILE

export RETCODE=$?

#-------------------------------------------------------------------------#
# Check for good return from sqlplus.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   cat $OUTPUT_PATH/$TMPFILE >> $OUTPUT_PATH/$LOG_FILE 
   print "                                                                 " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing rbate_clntprft_extract.ksh                     " >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE

# Send the Email notification
   export JOBNAME=" RI_4700J/RIMN4700"
   export SCRIPTNAME=$SCRIPT_PATH"/rbate_clntprft_extract.ksh"
   export LOGFILE=$OUTPUT_PATH"/$LOG_FILE"
   export EMAILPARM4="  "
   export EMAILPARM5="  "

   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOBNAME        >> $OUTPUT_PATH/$LOG_FILE
   print "SCRIPTNAME is " $SCRIPTNAME  >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE        >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4  >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5  >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" >> $OUTPUT_PATH/$LOG_FILE
   . $SCRIPT_PATH/rbate_email_base.ksh

   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

print 'HEADER'  >  $OUTPUT_PATH/$FILEOUT
cat $OUTPUT_PATH/$TMPFILE >> $OUTPUT_PATH/$FILEOUT
print 'TRAILER' >> $OUTPUT_PATH/$FILEOUT

touch $OUTPUT_PATH/$TRGFILE
#-------------------------------------------------------------------------#
# FTP the report to an NT server                  
#-------------------------------------------------------------------------#
 
print 'FTPing ' $FILEOUT ' to ' $FTP_NT_IP              >> $OUTPUT_PATH/$LOG_FILE
print 'cd /staging/local/prod/clntprft/input/'          >> $OUTPUT_PATH/$COMFILE
print 'put ' $OUTPUT_PATH/$FILEOUT $FILEOUT ' (replace' >> $OUTPUT_PATH/$COMFILE
print 'put ' $OUTPUT_PATH/$TRGFILE $TRGFILE ' (replace' >> $OUTPUT_PATH/$COMFILE
print 'quit'                                            >> $OUTPUT_PATH/$COMFILE
ftp -i  $FTP_NT_IP < $OUTPUT_PATH/$COMFILE >> $OUTPUT_PATH/$LOG_FILE

if [[ $RETCODE != 0 ]]; then
   print "                                                                 " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error in FTP of " $FILEOUT                                       >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in " $OUTPUT_PATH/$LOG_FILE                                 >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE

   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

#-------------------------------------------------------------------------#
# Copy the log file over and end the job                  
#-------------------------------------------------------------------------#

print '....Completed executing rbate_clntprft_extract.ksh....'   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

