#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_missing_rbate_id.ksh  
# Title         : Detail report of claims with missing rebate id's
#
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 10-01-07    is45401    Added Jack Silvey's hint changes to the 1st SQL
# 08-03-07    is45401    Fixed queries against t_missing_Rbate_id_detail
#                        where the CYCLE_GID was not in WHERE clause.
# 05-23-06    is45401    Changed detail query to insert into table, then 
#                        extract from table in delimited file.  Added to 
#                        SQL to include DSC and XMD claims.  Added SQL 
#                        from the Missing Rebate ID summary report since 
#                        table now exists, use table data.
# 05-07-03    N. Tucker  Initial Creation. 
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
    export ALTER_EMAIL_ADDRESS=''
      FTP_CONFIG="
            r07prd02    /actuate7/DSC/gather_rpts
            AZSHISP00   /rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
        "
else  
    export ALTER_EMAIL_ADDRESS='randy.redus@caremark.com'
      FTP_CONFIG="
            r07prd02    /actuate7/DSC/gather_rpts/dev
            AZSHISP00   /rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/test
        "
fi

CTRL_FILE=$OUTPUT_PATH/"gdx_pre_gather_rpt_control_file_init.dat"

RETCODE=0
SCRIPTNAME=$SCRIPT_PATH/$(basename $0)
FILE_BASE=$(basename $0 | sed -e 's/\.ksh$//')
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
ARCH_LOG_FILE=$OUTPUT_PATH/archive/$FILE_BASE'.log.'$(date +'%Y%j%H%M')
SQL_FILE=$OUTPUT_PATH/$FILE_BASE".sql"
DETAIL_DAT_FILE=$OUTPUT_PATH/$FILE_BASE"_detail_"
SUMMARY_DAT_FILE=$OUTPUT_PATH/$FILE_BASE"_summary_"
MISS_MODEL_DAT_FILE=$OUTPUT_PATH/$FILE_BASE"_model_"
FTP_CMDS=$OUTPUT_PATH/$FILE_BASE"_ftpcommands.txt"
FTP_NT_IP=AZSHISP00

rm -f $LOG_FILE
rm -f $SQL_FILE
rm -f $FTP_CMDS

#----------------------------------
# What to do when exiting the script
#----------------------------------
function exit_script {
    typeset _RETCODE=$1
    typeset _ERRMSG="$2"
    if [[ -z $_RETCODE ]]; then
        _RETCODE=0
print " " >> $LOG_FILE
print "Inside the exit_script function - successful run occurring" >> $LOG_FILE
print " " >> $LOG_FILE
print " "
print "Inside the exit_script function - successful run occurring"
print " "
    fi 
    if [[ $_RETCODE != 0 ]]; then
print " "
print "Inside the exit_script function - abend occurring"
print " "
print " " >> $LOG_FILE
print "Inside the exit_script function - abend occurring" >> $LOG_FILE
print " " >> $LOG_FILE
        print "                                                              " >> $LOG_FILE
        print "===================== J O B  A B E N D E D ===================" >> $LOG_FILE
        if [[ -n "$_ERRMSG" ]]; then
                print "  Error Message: $_ERRMSG"                              >> $LOG_FILE
        fi
        print "  Error Executing " $SCRIPTNAME                                 >> $LOG_FILE
        print "  Look in "$LOG_FILE                                            >> $LOG_FILE
        print "==============================================================" >> $LOG_FILE
        
        # Send the Email notification
        export JOBNAME=$SCRIPTNAME
        export SCRIPTNAME=$SCRIPTNAME
        export LOGFILE=$LOG_FILE
        export EMAILPARM4="$_ERRMSG "
        export EMAILPARM5="  "

        print "Sending email notification with the following parameters"       >> $LOG_FILE
        print "JOBNAME is    " $JOBNAME                                        >> $LOG_FILE
        print "SCRIPTNAME is " $SCRIPTNAME                                     >> $LOG_FILE
        print "LOGFILE is    " $LOGFILE                                        >> $LOG_FILE
        print "EMAILPARM4 is " $EMAILPARM4                                     >> $LOG_FILE
        print "EMAILPARM5 is " $EMAILPARM5                                     >> $LOG_FILE
        print "****** end of email parameters ******"                          >> $LOG_FILE

        . $SCRIPT_PATH/rbate_email_base.ksh

        cp -f $LOG_FILE $ARCH_LOG_FILE
        exit $_RETCODE
    else
        print " "                                                              >> $LOG_FILE
        print "....Completed executing " $SCRIPTNAME " ...."                   >> $LOG_FILE
        print `date`                                                           >> $LOG_FILE
        print "==============================================================" >> $LOG_FILE
        mv -f $LOG_FILE $ARCH_LOG_FILE

        rm -f $PKGSPOOL
        rm -f $SQL_FILE
        rm -f $FTP_CMDS
        rm -f $DETAIL_DAT_FILE
        rm -f $SUMMARY_DAT_FILE
        rm -f $MISS_MODEL_DAT_FILE
        
        exit $_RETCODE
    fi
}

#-------------------------------------------------------------------------#
## Set vars from input parameters
#-------------------------------------------------------------------------#
print "==================================================================="    >> $LOG_FILE
print "Starting " $SCRIPTNAME                                                  >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE

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
if [[ ! -s $CTRL_FILE ]]; then
    exit_script $RETCODE '$CTRL_FILE is EMPTY'
fi

READ_VARS='
    M_CTRL_CYCLE_GID
    M_CTRL_CYCLE_START_DATE
    M_CTRL_CYCLE_END_DATE
    Q_CTRL_CYCLE_GID
    Q_CTRL_CYCLE_START_DATE
    Q_CTRL_CYCLE_END_DATE
    JUNK
'
while read $READ_VARS; do

   export QTRLY_CYCLE_GID=$Q_CTRL_CYCLE_GID
   export MTHLY_CYCLE_GID=$M_CTRL_CYCLE_GID
   export CYCLE_START_DATE=$M_CTRL_CYCLE_START_DATE
   export CYCLE_END_DATE=$M_CTRL_CYCLE_END_DATE

done < $CTRL_FILE

print " "                                                                   >> $LOG_FILE
print "Control file record read from " $CTRL_FILE                           >> $LOG_FILE
print `date`                                                                >> $LOG_FILE
print " "                                                                   >> $LOG_FILE
print "Values are:"                                                         >> $LOG_FILE
print "MTHLY_CYCLE_GID  = " $MTHLY_CYCLE_GID                                >> $LOG_FILE
print "QTRLY_CYCLE_GID  = " $QTRLY_CYCLE_GID                                >> $LOG_FILE
print "CYCLE_START_DATE = " $CYCLE_START_DATE                               >> $LOG_FILE
print "CYCLE_END_DATE   = " $CYCLE_END_DATE                                 >> $LOG_FILE

if [[ -z $MTHLY_CYCLE_GID || -z $QTRLY_CYCLE_GID ||  -z $CYCLE_START_DATE ||  -z $CYCLE_END_DATE ]]; then
    exit_script $RETCODE "One of the Cycle parms is null"
fi

# Add the MTHLY_CYCLE_GID to the data file names
DETAIL_DAT_FILE=$DETAIL_DAT_FILE"$MTHLY_CYCLE_GID.dat"
SUMMARY_DAT_FILE=$SUMMARY_DAT_FILE"$MTHLY_CYCLE_GID.dat"
MISS_MODEL_DAT_FILE=$MISS_MODEL_DAT_FILE"$MTHLY_CYCLE_GID.dat"
PARTITION_VAR="P_"$MTHLY_CYCLE_GID

print " "                                                                      >> $LOG_FILE
print "Partition to be Truncated is " $PARTITION_VAR                           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

PKGEXEC='dma_rbate2.pk_cycle_util.truncate_partition'\(\''DMA_RBATE2.T_MISSING_RBATE_ID_DETAIL'\'\,\'"$PARTITION_VAR"\'\,\'"REFRESH CYCLE $MTHLY_CYCLE_GID"\'\)';'
PKGEXEC2='dma_rbate2.pk_cycle_util.truncate_partition'\(\''DMA_RBATE2.T_MISSING_RBATE_ID_DETAIL_EXCL'\'\,\'"$PARTITION_VAR"\'\,\'"REFRESH CYCLE $MTHLY_CYCLE_GID"\'\)';'
PKGSPOOL=$OUTPUT_PATH/$FILE_BASE"_pkg_spool.dat"

rm -f $PKGSPOOL
rm -f $DETAIL_DAT_FILE
rm -f $SUMMARY_DAT_FILE
rm -f $MISS_MODEL_DAT_FILE

print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

# Changed this query to insert into table first, then extract
#   Detail data, then extract Summary data.

#NOTE!!  MUST HAVE BLANK LINE BETWEEN THE SQLPLUS SET STATEMENT AND THE whenever STATEMENT!!!!
cat > $SQL_FILE << EOF

alter session enable parallel dml
-- NEXT LINE MUST BE BLANK!!!  OTHERWISE ERRORS WILL NOT STOP THE SQL EXECUTION!!!

whenever sqlerror exit failure
set LINESIZE 200
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set HEADING OFF
set FEEDBACK OFF
set verify off

SPOOL $PKGSPOOL

exec $PKGEXEC
exec $PKGEXEC2

spool off

select 'Starting INSERT into TMRID table' as descr, '  - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;

set FEEDBACK ON

INSERT /*+ append parallel(tmrid,12) */ INTO dma_rbate2.t_missing_rbate_id_detail tmrid
 SELECT  /*+ ordered no_expand(scr) no_expand(scrc1) use_hash(scrc1) tuned_by_jack_silvey_10012007 */
          $MTHLY_CYCLE_GID, scr.feed_id, scr.extnl_src_code, scr.extnl_lvl_id1,
          scr.extnl_lvl_id2, scr.extnl_lvl_id3, COUNT (scr.claim_gid)
     FROM
  -- Get all claims from SCR Claims Gather table and UNION together
          (select /*+ hash_aj */ * from (SELECT /*+ parallel(alv,12) full(alv) */
              alv.claim_gid, alv.feed_id, alv.extnl_src_code,
              alv.extnl_lvl_id1, alv.extnl_lvl_id2, alv.extnl_lvl_id3,
              alv.excpt_id
         FROM dma_rbate2.s_claim_rbate_alv alv
        WHERE alv.batch_date BETWEEN TO_DATE ('$CYCLE_START_DATE',
                              'MMDDYYYY'
                             )
                     AND TO_DATE ('$CYCLE_END_DATE',
                              'MMDDYYYY')
           UNION ALL
           SELECT /*+ parallel(rxc,12) full(rxc) */
              rxc.claim_gid, rxc.feed_id, rxc.extnl_src_code,
              rxc.extnl_lvl_id1, rxc.extnl_lvl_id2, rxc.extnl_lvl_id3,
              rxc.excpt_id
         FROM dma_rbate2.s_claim_rbate_rxc rxc
        WHERE rxc.batch_date BETWEEN TO_DATE ('$CYCLE_START_DATE',
                              'MMDDYYYY'
                             )
                     AND TO_DATE ('$CYCLE_END_DATE',
                              'MMDDYYYY')
           UNION ALL
           SELECT /*+ parallel(ruc,12) full(ruc) */
              ruc.claim_gid, ruc.feed_id, ruc.extnl_src_code,
              ruc.extnl_lvl_id1, ruc.extnl_lvl_id2, ruc.extnl_lvl_id3,
              ruc.excpt_id
         FROM dma_rbate2.s_claim_rbate_ruc ruc
        WHERE ruc.batch_date BETWEEN TO_DATE ('$CYCLE_START_DATE',
                              'MMDDYYYY'
                             )
                     AND TO_DATE ('$CYCLE_END_DATE',
                              'MMDDYYYY'))) scr
  -- Get all claims that were assigned a Rebate ID
  ,
         (select /*+ hash_aj */ * from (
  -- get all GPO claims - T_RBATE is a reporting table for the users
           SELECT /*+ parallel(tr,12) full(tr) */
              tr.cycle_gid, tr.claim_gid
         FROM dma_rbate2.t_rbate tr
        WHERE tr.cycle_gid = $QTRLY_CYCLE_GID
           UNION ALL
  -- Get all claims going to DSC
           SELECT /*+ parallel(dsc,12) full(dsc) */
              $MTHLY_CYCLE_GID cycle_gid, dsc.claim_id claim_gid
         FROM dma_rbate2.s_claim_refresh_dsc dsc
           UNION ALL
  -- Get all claims going to XMD
           SELECT /*+ parallel(xmd,12) full(xmd) */
              $MTHLY_CYCLE_GID cycle_gid, xmd.claim_id claim_gid
         FROM dma_rbate2.s_claim_refresh_xmd xmd
           UNION ALL
  -- Get all claims going to DSC or XMD that received a Refresh exception
           SELECT /*+ parallel(excpt,12) full(excpt) */
              cycle_gid, excpt.claim_id claim_gid
         FROM dma_rbate2.s_claim_non_gpo_excpt excpt
        WHERE excpt.cycle_gid = $MTHLY_CYCLE_GID
           UNION ALL
  -- Now get all claims that were assigned a Rebate ID, but not a model, from the Refresh working table
           SELECT /*+ parallel(scrcr,12) full(scrcr) */
              scrcr.cycle_gid, scrcr.claim_gid
         FROM dma_rbate2.s_claim_rbate_cycle_refresh scrcr,
              (SELECT /*+ parallel(tr,12) full(tr) */
                  tr.cycle_gid, tr.claim_gid
             FROM dma_rbate2.t_rbate tr
            WHERE tr.cycle_gid = $QTRLY_CYCLE_GID
               UNION ALL
               SELECT /*+ parallel(dsc,12) full(dsc) */
                  $MTHLY_CYCLE_GID cycle_gid, dsc.claim_id claim_gid
             FROM dma_rbate2.s_claim_refresh_dsc dsc
               UNION ALL
               SELECT /*+ parallel(xmd,12) full(xmd) */
                  $MTHLY_CYCLE_GID cycle_gid, xmd.claim_id claim_gid
             FROM dma_rbate2.s_claim_refresh_xmd xmd
               UNION ALL
               SELECT /*+ parallel(excpt,12) full(excpt) */
                  cycle_gid, excpt.claim_id claim_gid
             FROM dma_rbate2.s_claim_non_gpo_excpt excpt
            WHERE excpt.cycle_gid = $MTHLY_CYCLE_GID) scrc
        WHERE (   scrc.cycle_gid IN ($QTRLY_CYCLE_GID, $MTHLY_CYCLE_GID)
               OR scrc.cycle_gid IS NULL
              )
          AND scrcr.cycle_gid = $MTHLY_CYCLE_GID
          AND scrcr.claim_gid = scrc.claim_gid(+)
          AND scrc.claim_gid IS NULL)) scrc1
    WHERE scr.excpt_id IS NULL
      AND (   scrc1.cycle_gid IN ($QTRLY_CYCLE_GID, $MTHLY_CYCLE_GID)
           OR scrc1.cycle_gid IS NULL
          )
      AND scr.extnl_src_code != 'NOREB'
      AND scr.claim_gid = scrc1.claim_gid(+)
      AND scrc1.claim_gid IS NULL
      AND (RTRIM (scr.extnl_src_code),
           NVL (RTRIM (scr.extnl_lvl_id1), '_NULL_'),
           NVL (RTRIM (scr.extnl_lvl_id2), '_NULL_'),
           NVL (RTRIM (scr.extnl_lvl_id3), '_NULL_')
          )
  ----This will get exclusions for levels 1, 2, and 3
          NOT IN (
         SELECT /*+ hash_aj full(t_missing_rbate_id_excl) */ RTRIM (extnl_src_code), RTRIM (extnl_lvl_id1),
            RTRIM (extnl_lvl_id2), RTRIM (extnl_lvl_id3)
           FROM dma_rbate2.t_missing_rbate_id_excl
          WHERE (RTRIM (extnl_lvl_id1) > ' ')
            AND (RTRIM (extnl_lvl_id2) > ' ')
            AND (RTRIM (extnl_lvl_id3) > ' ')
            AND extnl_src_code IS NOT NULL
            AND extnl_lvl_id1 IS NOT NULL
            AND extnl_lvl_id2 IS NOT NULL
            AND extnl_lvl_id3 IS NOT NULL)
      AND (RTRIM (scr.extnl_src_code),
           NVL (RTRIM (scr.extnl_lvl_id1), '_NULL_'),
           NVL (RTRIM (scr.extnl_lvl_id2), '_NULL_')
          )
  ----This will get exclusions for levels 1 and 2
          NOT IN (
         SELECT  /*+ hash_aj full(t_missing_rbate_id_excl) */ RTRIM (extnl_src_code), RTRIM (extnl_lvl_id1),
            RTRIM (extnl_lvl_id2)
           FROM dma_rbate2.t_missing_rbate_id_excl
          WHERE (RTRIM (extnl_lvl_id1) > ' ')
            AND (RTRIM (extnl_lvl_id2) > ' ')
            AND (RTRIM (extnl_lvl_id3) = ' ' OR extnl_lvl_id3 IS NULL)
            AND extnl_src_code IS NOT NULL
            AND extnl_lvl_id1 IS NOT NULL
            AND extnl_lvl_id2 IS NOT NULL)
      AND (RTRIM (scr.extnl_src_code),
           NVL (RTRIM (scr.extnl_lvl_id1), '_NULL_'),
           NVL (RTRIM (scr.extnl_lvl_id2), '_NULL_'),
           NVL (RTRIM (extnl_lvl_id3), '_NULL_')
          )
  ----This will get exclusions for levels 1 and 3
          NOT IN (
         SELECT  /*+ hash_aj full(t_missing_rbate_id_excl) */ RTRIM (extnl_src_code), RTRIM (extnl_lvl_id1),
            NVL (RTRIM (extnl_lvl_id2), '_NULL_'),
            RTRIM (extnl_lvl_id3)
           FROM dma_rbate2.t_missing_rbate_id_excl
          WHERE (RTRIM (extnl_lvl_id1) > ' ')
            AND (RTRIM (extnl_lvl_id2) = ' ' OR extnl_lvl_id2 IS NULL)
            AND (RTRIM (extnl_lvl_id3) > ' ')
            AND extnl_src_code IS NOT NULL
            AND extnl_lvl_id1 IS NOT NULL
            AND extnl_lvl_id3 IS NOT NULL)
      AND (RTRIM (scr.extnl_src_code),
           NVL (RTRIM (scr.extnl_lvl_id1), '_NULL_')
          )
  ----This will get exclusions for level 1
          NOT IN (
         SELECT  /*+ hash_aj full(t_missing_rbate_id_excl) */ RTRIM (extnl_src_code), RTRIM (extnl_lvl_id1)
           FROM dma_rbate2.t_missing_rbate_id_excl
          WHERE (RTRIM (extnl_lvl_id1) > ' ')
            AND (RTRIM (extnl_lvl_id2) = ' ' OR extnl_lvl_id2 IS NULL)
            AND (RTRIM (extnl_lvl_id3) = ' ' OR extnl_lvl_id3 IS NULL)
            AND extnl_src_code IS NOT NULL
            AND extnl_lvl_id1 IS NOT NULL)
and EXTNL_LVL_ID1 IS NOT NULL
  GROUP BY scr.feed_id,
          scr.extnl_src_code,
          scr.extnl_lvl_id1,
          scr.extnl_lvl_id2,
          scr.extnl_lvl_id3;
          
commit;

set TERMOUT ON
set FEEDBACK OFF

select 'Completed First INSERT into TMRID table' as descr, ' - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;
select ' ' from dual;
select 'Starting Second INSERT into TMRID_EXCL table' as descr, '  - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;

set FEEDBACK ON
set TERMOUT OFF


INSERT /*+ append parallel(tmrid,12) */ INTO dma_rbate2.t_missing_rbate_id_detail_excl tmrid
SELECT /*+ parallel(scr,12) parallel(scrc,12) full(scr) full(scrc) */
        $MTHLY_CYCLE_GID
       ,scr.feed_id
       ,scr.extnl_src_code
       ,scr.extnl_lvl_id1
       ,scr.extnl_lvl_id2 
       ,scr.extnl_lvl_id3
       ,count(scr.claim_gid)                               
FROM 
-- Get all claims from SCR Claims Gather table and UNION together
(SELECT /*+ parallel(alv,15) full(alv) */ 
        alv.claim_gid ,alv.feed_id ,alv.extnl_src_code ,alv.extnl_lvl_id1 ,alv.extnl_lvl_id2 ,alv.extnl_lvl_id3, alv.excpt_id
   FROM dma_rbate2.s_claim_rbate_alv alv
   WHERE alv.batch_date BETWEEN to_date('$CYCLE_START_DATE','MMDDYYYY') AND to_date('$CYCLE_END_DATE','MMDDYYYY')  
UNION ALL
 SELECT /*+ parallel(rxc,15) full(rxc) */ 
        rxc.claim_gid ,rxc.feed_id ,rxc.extnl_src_code ,rxc.extnl_lvl_id1 ,rxc.extnl_lvl_id2 ,rxc.extnl_lvl_id3, rxc.excpt_id
   FROM dma_rbate2.s_claim_rbate_rxc rxc
   WHERE rxc.batch_date BETWEEN to_date('$CYCLE_START_DATE','MMDDYYYY') AND to_date('$CYCLE_END_DATE','MMDDYYYY')  
UNION ALL
 SELECT /*+ parallel(rxc,15) full(rxc) */ 
        ruc.claim_gid ,ruc.feed_id ,ruc.extnl_src_code ,ruc.extnl_lvl_id1 ,ruc.extnl_lvl_id2 ,ruc.extnl_lvl_id3, ruc.excpt_id
  FROM dma_rbate2.s_claim_rbate_ruc ruc
  WHERE ruc.batch_date BETWEEN to_date('$CYCLE_START_DATE','MMDDYYYY') AND to_date('$CYCLE_END_DATE','MMDDYYYY')  ) scr
-- Get all claims that were assigned a Rebate ID
  ,(
-- get all GPO claims - T_RBATE is a reporting table for the users
    SELECT /*+ parallel(tr,15) full(tr) */ tr.cycle_gid, tr.claim_gid FROM dma_rbate2.t_rbate tr
        WHERE tr.cycle_gid = $QTRLY_CYCLE_GID
    UNION ALL
-- Get all claims going to DSC
    SELECT /*+ parallel(dsc,15) full(dsc) */ $MTHLY_CYCLE_GID cycle_gid, dsc.claim_id claim_gid FROM dma_rbate2.s_claim_refresh_dsc dsc
    UNION ALL
-- Get all claims going to XMD
    SELECT /*+ parallel(xmd,15) full(xmd) */ $MTHLY_CYCLE_GID cycle_gid, xmd.claim_id claim_gid FROM dma_rbate2.s_claim_refresh_xmd xmd
    UNION ALL
-- Get all claims going to DSC or XMD that received a Refresh exception
    SELECT /*+ parallel(excpt,15) full(excpt) */ cycle_gid, excpt.claim_id claim_gid FROM dma_rbate2.S_CLAIM_NON_GPO_EXCPT excpt
        WHERE excpt.cycle_gid = $MTHLY_CYCLE_GID
    UNION ALL 
-- Now get all claims that were assigned a Rebate ID, but not a model, from the Refresh working table
    SELECT  /*+ parallel(scrcr,15) full(scrcr) */ scrcr.cycle_gid, scrcr.claim_gid 
        FROM  dma_rbate2.s_claim_rbate_cycle_refresh scrcr
            ,(SELECT /*+ parallel(tr,15) full(tr) */ tr.cycle_gid, tr.claim_gid FROM dma_rbate2.t_rbate tr
                  WHERE tr.cycle_gid = $QTRLY_CYCLE_GID
              UNION ALL
              SELECT /*+ parallel(dsc,15) full(dsc) */ $MTHLY_CYCLE_GID cycle_gid, dsc.claim_id claim_gid FROM dma_rbate2.s_claim_refresh_dsc dsc
              UNION ALL
              SELECT /*+ parallel(xmd,15) full(xmd) */ $MTHLY_CYCLE_GID cycle_gid, xmd.claim_id claim_gid FROM dma_rbate2.s_claim_refresh_xmd xmd
              UNION ALL 
              SELECT /*+ parallel(excpt,15) full(excpt) */ cycle_gid, excpt.claim_id claim_gid FROM dma_rbate2.S_CLAIM_NON_GPO_EXCPT excpt
                  WHERE excpt.cycle_gid = $MTHLY_CYCLE_GID) scrc 
        WHERE (scrc.cycle_gid IN ($QTRLY_CYCLE_GID,$MTHLY_CYCLE_GID)
           OR scrc.cycle_gid IS NULL) 
        AND scrcr.cycle_gid = $MTHLY_CYCLE_GID
          AND scrcr.claim_gid = scrc.claim_gid(+)
          AND scrc.claim_gid IS NULL
   ) scrc 
WHERE scr.excpt_id IS NULL
  AND (scrc.cycle_gid IN ($QTRLY_CYCLE_GID,$MTHLY_CYCLE_GID)
   OR scrc.cycle_gid IS NULL) 
  AND scr.extnl_src_code != 'NOREB'     
  AND scr.claim_gid = scrc.claim_gid(+)
  AND scrc.claim_gid IS NULL
  AND(
      (rtrim(scr.extnl_src_code),NVL(RTRIM(scr.EXTNL_LVL_ID1),'_NULL_'),NVL(RTRIM(scr.EXTNL_LVL_ID2),'_NULL_'),NVL(RTRIM(scr.EXTNL_LVL_ID3),'_NULL_'))
----This will get exclusions for levels 1, 2, and 3
        IN (SELECT rtrim(extnl_src_code),RTRIM(EXTNL_LVL_ID1),RTRIM(EXTNL_LVL_ID2),RTRIM(EXTNL_LVL_ID3)
        FROM dma_rbate2.T_MISSING_RBATE_ID_EXCL 
               WHERE (RTRIM(EXTNL_LVL_ID1) > ' ')
                 AND (RTRIM(EXTNL_LVL_ID2) > ' ')
                 AND (RTRIM(EXTNL_LVL_ID3) > ' ')
                ) 
  OR (rtrim(scr.extnl_src_code),NVL(RTRIM(scr.EXTNL_LVL_ID1),'_NULL_'),NVL(RTRIM(scr.EXTNL_LVL_ID2),'_NULL_')) 
----This will get exclusions for levels 1 and 2 
        IN (SELECT rtrim(extnl_src_code),RTRIM(EXTNL_LVL_ID1),RTRIM(EXTNL_LVL_ID2)
        FROM dma_rbate2.T_MISSING_RBATE_ID_EXCL
               WHERE (RTRIM(EXTNL_LVL_ID1) > ' ')
                 AND (RTRIM(EXTNL_LVL_ID2) > ' ')
                 AND (RTRIM(EXTNL_LVL_ID3) = ' ' or EXTNL_LVL_ID3 IS NULL)
                ) 
  OR (rtrim(scr.extnl_src_code),NVL(RTRIM(scr.EXTNL_LVL_ID1),'_NULL_'),NVL(RTRIM(scr.EXTNL_LVL_ID2),'_NULL_'),NVL(RTRIM(EXTNL_LVL_ID3),'_NULL_')) 
----This will get exclusions for levels 1 and 3 
        IN (SELECT rtrim(extnl_src_code),RTRIM(EXTNL_LVL_ID1),NVL(RTRIM(EXTNL_LVL_ID2),'_NULL_'),RTRIM(EXTNL_LVL_ID3) 
        FROM dma_rbate2.T_MISSING_RBATE_ID_EXCL 
               WHERE (RTRIM(EXTNL_LVL_ID1) > ' ')
                 AND (RTRIM(EXTNL_LVL_ID2) = ' ' or EXTNL_LVL_ID2 IS NULL)
                 AND (RTRIM(EXTNL_LVL_ID3) > ' ')
               )  
  OR (rtrim(scr.extnl_src_code),NVL(RTRIM(scr.EXTNL_LVL_ID1),'_NULL_')) 
----This will get exclusions for level 1 
        IN (SELECT rtrim(extnl_src_code),RTRIM(EXTNL_LVL_ID1) 
          FROM dma_rbate2.T_MISSING_RBATE_ID_EXCL
                 WHERE (RTRIM(EXTNL_LVL_ID1) > ' ')
                   AND (RTRIM(EXTNL_LVL_ID2) = ' ' or EXTNL_LVL_ID2 IS NULL)
                   AND (RTRIM(EXTNL_LVL_ID3) = ' ' or EXTNL_LVL_ID3 IS NULL)
                )
   )             
and EXTNL_LVL_ID1 IS NOT NULL
GROUP BY
     scr.feed_id                        
    ,scr.extnl_src_code                 
    ,scr.extnl_lvl_id1        
    ,scr.extnl_lvl_id2                  
    ,scr.extnl_lvl_id3;      

commit;

set TERMOUT ON
set FEEDBACK OFF
EXEC is45401.pk_prcs.send_mail('Silver-Randy','randy.redus@caremark.com','randy.redus@caremark.com','Missing Rebate ID done','Change the script back to omit this email, and also remove EXTNL_LVL_ID1 IS NOT NULL');


select 'Completed Second INSERT into TMRID table' as descr, ' - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;
select ' ' from dual;
select 'Starting data extract from TMRID for detail data' as descr, '  - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;

set TERMOUT OFF

--Missing Rebate ID Detail SQL
SPOOL $DETAIL_DAT_FILE

SELECT /*+ parallel(scr,12) parallel(scrc,12) full(scr) full(scrc) */
        tmrid.feed_id
       ,','
       ,tmrid.extnl_src_code
       ,','
       ,tmrid.extnl_lvl_id1
       ,','
       ,tmrid.extnl_lvl_id2 
       ,','
       ,tmrid.extnl_lvl_id3
       ,','
       ,tmrid.claim_cnt                               
FROM dma_rbate2.t_missing_rbate_id_detail tmrid
where cycle_gid = $MTHLY_CYCLE_GID;

spool off
SET TERMOUT ON

select 'Completed data extract from TMRID for detail data' as descr, ' - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;
select ' ' from dual;
select 'Starting data extract from TMRID for Summary data' as descr, '  - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;

SET TERMOUT OFF
--Missing Rebate ID Summary SQL
SPOOL $SUMMARY_DAT_FILE

SELECT 
     tmrid.feed_id
    ,','
    ,tmrid.extnl_src_code
    ,','
    ,tmrid.extnl_lvl_id1
    ,','
    ,sum(tmrid.claim_cnt)
FROM
    dma_rbate2.t_missing_rbate_id_detail tmrid
where cycle_gid = $MTHLY_CYCLE_GID
GROUP BY
     tmrid.feed_id
    ,tmrid.extnl_src_code
    ,tmrid.extnl_lvl_id1;

spool off
SET TERMOUT ON
select 'Completed data extract from TMRID for Summary data' as descr, ' - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;
select ' ' from dual;
select 'Starting data extract for Missing Rbate ID Model data' as descr, '  - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;

SET TERMOUT OFF

--Missing Rebate ID Model SQL
SPOOL $MISS_MODEL_DAT_FILE
 
SELECT  /*+ parallel(scrcr,15) full(scrcr) */ 
        scrcr.rbate_id
       ,','
       ,scrcr.extnl_src_code
       ,','
       ,scrcr.dspnd_date
       ,',' 
       ,COUNT(scrcr.claim_gid)
   FROM  dma_rbate2.s_claim_rbate_cycle_refresh scrcr
        ,(SELECT /*+ parallel(tr,15) full(tr) */ tr.cycle_gid, tr.claim_gid FROM dma_rbate2.t_rbate tr
              WHERE tr.cycle_gid = $QTRLY_CYCLE_GID
          UNION ALL
          SELECT /*+ parallel(dsc,15) full(dsc) */ $MTHLY_CYCLE_GID cycle_gid, dsc.claim_id claim_gid FROM dma_rbate2.s_claim_refresh_dsc dsc
          UNION ALL
          SELECT /*+ parallel(xmd,15) full(xmd) */ $MTHLY_CYCLE_GID cycle_gid, xmd.claim_id claim_gid FROM dma_rbate2.s_claim_refresh_xmd xmd
          UNION ALL 
          SELECT /*+ parallel(excpt,15) full(excpt) */ cycle_gid, excpt.claim_id claim_gid FROM dma_rbate2.S_CLAIM_NON_GPO_EXCPT excpt
              WHERE excpt.cycle_gid = $MTHLY_CYCLE_GID) scrc 
WHERE (scrc.cycle_gid IN ($QTRLY_CYCLE_GID,$MTHLY_CYCLE_GID)
   OR scrc.cycle_gid IS NULL) 
AND scrcr.cycle_gid = $MTHLY_CYCLE_GID
  AND scrcr.claim_gid = scrc.claim_gid(+)
  AND scrc.claim_gid IS NULL
GROUP BY scrcr.rbate_id, scrcr.extnl_src_code, scrcr.dspnd_date;

spool off
SET TERMOUT ON
select 'Completed data extract for Missing Rbate ID Model data' as descr, ' - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;
commit;
quit; 
 
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE                       >> $LOG_FILE

RETCODE=$?

print " "                                                                      >> $LOG_FILE
print `date`" - SQLPlus complete "                                             >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return from sqlplus.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
    # Check to see which of the dat files have the SQL error.  -s means file exists and size > 0
    if [[ ! -s $DETAIL_DAT_FILE ]]; then 
        ERROR_LCTN="SQL Error was in the Package call or the INSERT"
        SPOOL_ERROR=$PKGSPOOL
    elif  [[ ! -s $SUMMARY_DAT_FILE ]]; then 
            ERROR_LCTN="SQL Error was in the Missing Rebate ID Detail SQL"
            SPOOL_ERROR=$DETAIL_DAT_FILE
        elif  [[ ! -s $MISS_MODEL_DAT_FILE ]]; then 
            ERROR_LCTN="SQL Error was in the Missing Rebate ID Summary SQL"
            SPOOL_ERROR=$SUMMARY_DAT_FILE
            else 
                ERROR_LCTN="SQL Error was in the Missing Rebate ID Model SQL"
                SPOOL_ERROR=$MISS_MODEL_DAT_FILE
    fi
    print "***********SQL ERROR   SQL ERROR   SQL ERROR   SQL ERROR**********" >> $LOG_FILE
    print "$ERROR_LCTN - "                                                     >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    cat -s $SPOOL_ERROR                                                        >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    exit_script $RETCODE 'SQL Error'
else
    # FTP the files
    # Read non-empty lines from FTP_CONFIG
    print "$FTP_CONFIG" | while read FTP_HOST FTP_DIR; do
        if [[ -z $FTP_HOST ]]; then
            continue
        fi
        print "Transfering $DETAIL_DAT_FILE to [$FTP_HOST] [$FTP_DIR]"         >> $LOG_FILE
        print "Transfering $SUMMARY_DAT_FILE to [$FTP_HOST] [$FTP_DIR]"        >> $LOG_FILE
        print "Transfering $MISS_MODEL_DAT_FILE to [$FTP_HOST] [$FTP_DIR]"     >> $LOG_FILE

        # Build variable containing commands
        FTP_CMDS=$(
            if [[ -n $FTP_DIR ]]; then
                print "cd $FTP_DIR"
            fi
            # The ${DETAIL_DAT_FILE##/*/} strips off the file directory from the file variable.
            print "put "$DETAIL_DAT_FILE  ${DETAIL_DAT_FILE##/*/} " (replace"  
            print "put "$SUMMARY_DAT_FILE ${SUMMARY_DAT_FILE##/*/} " (replace"  
            print "put "$MISS_MODEL_DAT_FILE ${MISS_MODEL_DAT_FILE##/*/} " (replace"  
            print "bye"
        )

        # Perform the FTP
        print "Ftp commands:\n$FTP_CMDS\n" >> $LOG_FILE
        FTP_OUTPUT=$(print "$FTP_CMDS" | ftp -vi "$FTP_HOST")
        RETCODE=$?

        # Parse the output for 400 & 500 level FTP reply (error) codes
        ERROR_COUNT=$(print "$FTP_OUTPUT" | egrep -v 'bytes (sent|received)' | egrep -c '^\s*[45][0-9][0-9]')
        print "$FTP_OUTPUT" >> $LOG_FILE

        if [[ $RETCODE != 0 ]] ; then
            print 'FTP FAILED'                                                 >> $LOG_FILE
            exit_script $RETCODE 'FTP Error'
        fi

        if [[ $ERROR_COUNT -gt 0 ]]; then
            RETCODE=$ERROR_COUNT
            print 'FTP FAILED'                                                 >> $LOG_FILE
            exit_script $RETCODE 'FTP Error'
        fi
    done

    print ".... FTP complete   ...."                                           >> $LOG_FILE
    print `date`                                                               >> $LOG_FILE
fi
#end return code check

#call exit_script function at top
exit_script $RETCODE
