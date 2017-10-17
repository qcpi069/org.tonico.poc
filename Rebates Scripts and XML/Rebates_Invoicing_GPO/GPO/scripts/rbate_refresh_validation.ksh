#!/bin/ksh
#==============================================================================
#
# File Name    = rbate_refresh_validation.ksh
# Description  = Execute the SQL to populate the refresh_validator table
#                after cycle_refresh is complete.
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION 
#
#==============================================================================
#  11/04/02  is23301                 initial script creation
#==============================================================================
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#  Delete the previous runs output log.
rm $OUTPUT_PATH/rbate_refresh_validation.log

TABLE_NAME='refresh_validator'
PKGEXEC='dma_rbate2.pk_cycle_util.truncate_table'\(\'$TABLE_NAME\'\);

cd $INPUT_PATH
rm rbate_refresh_validation.sql

cat > rbate_refresh_validation.sql << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL ../output/rbate_refresh_validation.log
SET TIMING ON

exec $PKGEXEC;

insert into dma_rbate2.refresh_validator 
       select /*+ parallel(a,24) full(a) parallel(b,24) full(b) */
              a.feed_id
             ,a.batch_gid
             ,a.frmly_gid
             ,a.extnl_src_code 
             ,a.extnl_lvl_id1
             ,a.extnl_lvl_id2
             ,a.extnl_lvl_id3
             ,(case when a.dspnd_date < to_date('10-01-2002','MM-dd-yyyy')
                    then 'DROP' else 'ELIG' end) date_ind
             ,b.rbate_id
             ,b.lcm_code
             ,b.excpt_id
             ,count(*) clm_cnt
       from dma_rbate2.s_claim_rbate a, dma_rbate2.s_claim_rbate_cycle b
       where a.batch_date between
                          to_date('01-01-2003','MM-dd-yyyy') and
                          to_date('03-31-2003','MM-dd-yyyy')
         and b.cycle_gid(+)=200341
         and a.claim_gid=b.claim_gid(+)
       group by a.feed_id
               ,a.batch_gid
               ,a.frmly_gid
               ,a.extnl_src_code
               ,a.extnl_lvl_id1
               ,a.extnl_lvl_id2
               ,a.extnl_lvl_id3
               ,(case when a.dspnd_date < to_date('10-01-2002','MM-dd-yyyy')
                      then 'DROP' else 'ELIG' end)
               ,b.rbate_id
               ,b.lcm_code
               ,b.excpt_id;
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/rbate_refresh_validation.sql

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing rbate_refresh_validation.sql                        "
   echo "  Look in "$OUTPUT_PATH/rbate_refresh_validation.log
   echo "================================================================="
   
# Send the Email notification 
   export JOBNAME="KCOR2000 / KC_2010J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_refresh_validation.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_refresh_validation.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_refresh_validation.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_refresh_validation.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_refresh_validation.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_refresh_validation.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_refresh_validation.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_refresh_validation.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_refresh_validation.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   exit $RC
else
   cp $OUTPUT_PATH/rbate_refresh_validation.log    $LOG_ARCH_PATH/rbate_refresh_validation.log.`date +"%Y%j%H%M"`
fi
   
echo .... Completed executing rbate_refresh_validation.ksh .....



