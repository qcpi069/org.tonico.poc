#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIOR4500_RI_4500J_special_update_of_TQR_call.ksh   
# Description   : This script updates data in tmp_qtr_results 
#                 
# Maestro Job   : RIOR4500 RI_4500J
#
# Parameters    : None.
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 06-30-05   is31701     Initial Creation. 
#
#
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#

SQL_FILE_SPECIAL=$INPUT_PATH/"rbate_RIOR4500_RI_4500J_special_update_of_TQR_call.sql"
SQL_LOG_FILE_SPECIAL=$OUTPUT_PATH/"rbate_RIOR4500_RI_4500J_special_update_of_TQR_call.log"

rm -f $SQL_FILE_SPECIAL
rm -f $SQL_LOG_FILE_SPECIAL

QTR_STRT_DT=$1
QTR_END_DT=$2

print " " 									>> $LOG_FILE
print "Running the update SQL for TMP_QTR_RESULTS for $QTR_STRT_DT thru $QTR_END_DT" >> $LOG_FILE
print " " 									>> $LOG_FILE

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

cat > $SQL_FILE_SPECIAL << EOF

whenever sqlerror exit 1
SPOOL $SQL_LOG_FILE_SPECIAL
set timing on
alter session enable parallel dml; 


--create the temporary table for the update. Notice that it is index organized - this means that it is actually just an index, and that it is its own primary key.
--I precreate the table so that it can persist after your update is finished

create table dma_rbate2_app.t_ruc_update (claim_gid number, clt_plan_grp_id varchar2(100), primary key (claim_gid) )
organization index
nologging
pctfree 0
initrans 2
tablespace silveruser01
--tablespace maplets01
;

--insert the data into the temp table
--this ran in about 5 minutes for me, but returned no data

insert /*+ append */ into dma_rbate2_app.t_ruc_update (claim_gid, clt_plan_grp_id)
select 
	   	   /*+ 
	   	   ordered 
	   	   full(scrruc) 
		   full(tqr) 
		   parallel(scrruc,16) 
		   parallel(tqr,16) 
		   use_hash(tqr) 
		   pq_distribute(scrruc,hash,hash) 
		   */ 
scrruc.claim_gid, to_char(scrruc.clt_plan_grp_id) clt_plan_grp_id
from dma_rbate2.tmp_qtr_results tqr, dma_rbate2.s_claim_rbate_ruc scrruc 
where tqr.claim_gid = scrruc.claim_gid
and scrruc.batch_date between to_date ('$QTR_STRT_DT','mm-dd-yyyy')
and to_date ('$QTR_END_DT','mm-dd-yyyy')
and tqr.extnl_src_code = 'QLC' 
and tqr.extnl_lvl_id2 is null;


--commit the temp data

commit;

--do the update
--notice that you will see an "index fast full scan" step on this process - that is on the IOT

update 
	(select 
		/*+ ordered 
		full(scrruc) 
		parallel(scrruc,12) 
		full(tqr) 
		parallel(tqr,12) 
		use_hash(tqr)
		pq_distribute(tqr,hash,hash) 
		*/
	tqr.extnl_lvl_id2 C1,  scrruc.clt_plan_grp_id C2
	from dma_rbate2_app.t_ruc_update scrruc, 
	dma_rbate2.tmp_qtr_results tqr
	where scrruc.claim_gid = tqr.claim_gid)
set c1 = c2;

                                   
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE_SPECIAL

RETCODE=$?

cat $SQL_LOG_FILE_SPECIAL							>> $LOG_FILE
    
if [[ $RETCODE = 0 ]]; then 
   print " "							       		>> $LOG_FILE
   print "Update of tmp_qtr_results_sum completed successfully "   		>> $LOG_FILE    
   return 0 
else
   print " "							       		>> $LOG_FILE	
   print "Error when updating tmp_qtr_results_sum"   	         	 	>> $LOG_FILE
   print "Script will retun and abend now " 					>> $LOG_FILE
   return $RETCODE	
fi 	


