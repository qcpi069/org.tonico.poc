#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCWK2300_KC_2300J_claims_extract_to_gdx.ksh
#
# Description   : Extract all paid and unmatched reversal Claims
#                 and send them over to GDX system.
#                
#
# Maestro Job   : KC_2300J
#
# Parameters    : None
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09/21/2005 Castillo    Initial script.
# 11/08/2005 Nandini	 Changes related to Medicare.

. "$(dirname $0)/rebates_env.ksh"

# This variable should contain all of the hosts to transfer the file to
# Each line in the variable has 2 tokens the remote host and directory.
FTP_CONFG=""

if [[ $REGION = 'prod' ]]; then
	if [[ $QA_REGION = 'false' ]]; then  
		ALTER_EMAIL_ADDRESS=''
		FTP_CONFIG="
			r07prd01	/GDX/$REGION/input
			r07prd02	/actuate7/DSC/gather_rpts
			AZSHISP00	/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
		"
    else
		ALTER_EMAIL_ADDRESS=''
		FTP_CONFIG="
			r07tst07	/GDX/test/input
			r07prd02	/actuate7/DSC/gather_rpts/qa
			AZSHISP00	/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
		"
    fi
else
	FTP_CONFIG="
		r07tst07	/GDX/test/input
		AZSHISP00	/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/dev
	"
    export ALTER_EMAIL_ADDRESS="nick.tucker@caremark.com"
fi

RETCODE=0
SCRIPTNAME=$(basename $0)
FILE_BASE=${SCRIPTNAME%.ksh}
LOG_FILE=$FILE_BASE'.log'
ARCH_LOG_FILE=$FILE_BASE'.log.'$(date +'%Y%j%H%M')
SQL_FILE=$FILE_BASE'.sql'
DAT_FILE=$FILE_BASE".dat"
DAT_FILE1=$FILE_BASE"_excpt.dat"
export CTRL_FILE="gdx_pre_gather_rpt_control_file_init.dat"


#----------------------------------
# What to do when exiting the script
#----------------------------------
function exit_script {
	typeset _RETCODE=$1
	typeset _ERRMSG="$2"
	if [[ -z $_RETCODE ]]; then
		_RETCODE=0
	fi
	if [[ $_RETCODE != 0 ]]; then
		print "                                                                 " >> $OUTPUT_PATH/$LOG_FILE
		print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
		if [[ -n "$_ERRMSG" ]]; then
				print "  Error Message: $_ERRMSG"                                 >> $OUTPUT_PATH/$LOG_FILE
		fi
		print "  Error Executing " $SCRIPT_PATH/$SCRIPTNAME                       >> $OUTPUT_PATH/$LOG_FILE
		print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
		print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
		cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
		exit $_RETCODE
	else
		print " "                                                                   >> $OUTPUT_PATH/$LOG_FILE
		print "....Completed executing " $SCRIPT_PATH/$SCRIPTNAME " ...."           >> $OUTPUT_PATH/$LOG_FILE
		print `date`                                                                >> $OUTPUT_PATH/$LOG_FILE
		print "===================================================================" >> $OUTPUT_PATH/$LOG_FILE
		mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
		exit $_RETCODE
	fi
}


#----------------------------------
# Main
#----------------------------------
rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$FILE_BASE.dat.*
rm -f $INPUT_PATH/$SQL_FILE

print ' '                             >> $OUTPUT_PATH/$LOG_FILE
print "$(date) starting $SCRIPTNAME"  >> $OUTPUT_PATH/$LOG_FILE

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

   CYCLE_GID=$M_CTRL_CYCLE_GID
   CYCLE_START_DATE=$M_CTRL_CYCLE_START_DATE
   CYCLE_END_DATE=$M_CTRL_CYCLE_END_DATE

   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "Control file record read from " $OUTPUT_PATH/$CTRL_FILE               >> $OUTPUT_PATH/$LOG_FILE
   print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "Values are:"                                                          >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_GID = " $CYCLE_GID                                              >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_START_DATE = " $CYCLE_START_DATE                                >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_END_DATE = " $CYCLE_END_DATE                                    >> $OUTPUT_PATH/$LOG_FILE



#----------------------------------
# Oracle userid/password
#----------------------------------
db_user_password=`cat $SCRIPT_PATH/ora_user.fil`


cat > $INPUT_PATH/$SQL_FILE <<- EOF
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
	SPOOL $OUTPUT_PATH/$DAT_FILE
	alter session enable parallel dml;
	
	SELECT
		TRANSLATE(rpt.CLT_NAME, ',', ' ')
		|| ','
		|| rpt.CLT_ID 
		|| ','
		|| rpt.EXTNL_SRC_CODE 
		|| ','
		|| rpt.MODEL_TYP_CD 
		|| ','
		|| rpt.COUNT 
		|| ','
		|| rpt.EFFECTIVE_DT 
		|| ','
		|| rpt.EXPIRATION_DT
		|| ','
		|| rpt.QL_CLT_ID
	FROM (
		SELECT /*+ ordered use_hash(tcm) use_hash(tri) parallel(tcm,8) full(tcm) parallel(tri,8) full(tri) */
			tri.RBATE_ID_NAM AS CLT_NAME
			,vcs.RBATE_ID AS CLT_ID
			,vcs.EXTNL_SRC_CODE
			,CASE
				WHEN tcm.MODEL_TYP_CD = 'D' THEN 'Discount'
				WHEN tcm.MODEL_TYP_CD = 'G' THEN 'GPO'
				WHEN tcm.MODEL_TYP_CD = 'X' THEN 'Medicare'
				ELSE 'Unknown'
			 END AS MODEL_TYP_CD
			,COUNT(vcs.RBATE_ID) AS COUNT
			,tcm.EFFECTIVE_DT
			,tcm.EXPIRATION_DT
			,tcm.QL_CLT_ID
		FROM
			DMA_RBATE2.T_RBATE_ID tri,
			DMA_RBATE2.T_CLT_MODEL tcm,
			DMA_RBATE2.V_COMBINED_SCRC vcs
		WHERE
			    vcs.RBATE_ID = tcm.CLT_ID
			AND vcs.DSPND_DATE BETWEEN tcm.EFFECTIVE_DT AND tcm.EXPIRATION_DT
			AND vcs.RBATE_ID = tri.RBATE_ID(+)
			AND vcs.claim_status_flag in (0,24,26)
			AND vcs.CYCLE_GID = $CYCLE_GID
		GROUP BY
			tri.RBATE_ID_NAM
			,vcs.RBATE_ID
			,vcs.EXTNL_SRC_CODE
			,CASE
				WHEN tcm.MODEL_TYP_CD = 'D' THEN 'Discount'
				WHEN tcm.MODEL_TYP_CD = 'G' THEN 'GPO'
				WHEN tcm.MODEL_TYP_CD = 'X' THEN 'Medicare'
				ELSE 'Unknown'
			 END
			,tcm.EFFECTIVE_DT
			,tcm.EXPIRATION_DT
			,tcm.QL_CLT_ID
		UNION ALL
		SELECT /*+ ordered use_hash(tcm) use_hash(tri) parallel(tcm,8) full(tcm) parallel(tri,8) full(tri) parallel(scrd,8) full(scrd) */
			tri.RBATE_ID_NAM AS CLT_NAME
			,scrd.CLT_ID AS CLT_ID
			,scrd.EXTNL_SRC_CD
			,CASE
				WHEN scrd.MODEL_TYP_CD = 'D' THEN 'Discount'
				WHEN scrd.MODEL_TYP_CD = 'G' THEN 'GPO'
				WHEN scrd.MODEL_TYP_CD = 'X' THEN 'Medicare'
				ELSE 'Unknown'
			 END AS MODEL_TYP_CD
			,COUNT(scrd.CLT_ID) AS COUNT
			,tcm.EFFECTIVE_DT
			,tcm.EXPIRATION_DT
			,scrd.QL_CLT_ID
		FROM
			 DMA_RBATE2.T_CLT_MODEL tcm
			,DMA_RBATE2.T_RBATE_ID tri
			,DMA_RBATE2.S_CLAIM_REFRESH_DSC scrd
		WHERE
			 scrd.RBATE_ID = tcm.CLT_ID
			 AND scrd.MODEL_TYP_CD = tcm.MODEL_TYP_CD
			 AND scrd.FILL_DT BETWEEN tcm.EFFECTIVE_DT AND tcm.EXPIRATION_DT
			 AND tcm.CLT_ID = tri.RBATE_ID(+)
		GROUP BY
			tri.RBATE_ID_NAM
			,scrd.CLT_ID
			,scrd.EXTNL_SRC_CD
			,CASE
				WHEN scrd.MODEL_TYP_CD = 'D' THEN 'Discount'
				WHEN scrd.MODEL_TYP_CD = 'G' THEN 'GPO'
				WHEN scrd.MODEL_TYP_CD = 'X' THEN 'Medicare'
				ELSE 'Unknown'
			 END
			,tcm.EFFECTIVE_DT
			,tcm.EXPIRATION_DT
			,scrd.QL_CLT_ID
		UNION ALL
		SELECT /*+ ordered use_hash(tcm) use_hash(tri) parallel(tcm,8) full(tcm) parallel(tri,8) full(tri) parallel(scrd,8) full(scrd) */
			tri.RBATE_ID_NAM AS CLT_NAME
			,scrd.CLT_ID AS CLT_ID
			,scrd.EXTNL_SRC_CD
			,CASE
				WHEN scrd.MODEL_TYP_CD = 'D' THEN 'Discount'
				WHEN scrd.MODEL_TYP_CD = 'G' THEN 'GPO'
				WHEN scrd.MODEL_TYP_CD = 'X' THEN 'Medicare'
				ELSE 'Unknown'
			 END AS MODEL_TYP_CD
			,COUNT(scrd.CLT_ID) AS COUNT
			,tcm.EFFECTIVE_DT
			,tcm.EXPIRATION_DT
			,scrd.QL_CLT_ID
		FROM
			 DMA_RBATE2.T_CLT_MODEL tcm
			,DMA_RBATE2.T_RBATE_ID tri
			,DMA_RBATE2.S_CLAIM_REFRESH_XMD scrd
		WHERE
			 scrd.RBATE_ID = tcm.CLT_ID
			 AND scrd.MODEL_TYP_CD = tcm.MODEL_TYP_CD
			 AND scrd.FILL_DT BETWEEN tcm.EFFECTIVE_DT AND tcm.EXPIRATION_DT
			 AND tcm.CLT_ID = tri.RBATE_ID(+)
		GROUP BY
			tri.RBATE_ID_NAM
			,scrd.CLT_ID
			,scrd.EXTNL_SRC_CD
			,CASE
				WHEN scrd.MODEL_TYP_CD = 'D' THEN 'Discount'
				WHEN scrd.MODEL_TYP_CD = 'G' THEN 'GPO'
				WHEN scrd.MODEL_TYP_CD = 'X' THEN 'Medicare'
				ELSE 'Unknown'
			 END
			,tcm.EFFECTIVE_DT
			,tcm.EXPIRATION_DT
			,scrd.QL_CLT_ID
	) rpt;

	quit;
EOF

cat $INPUT_PATH/$SQL_FILE >> $OUTPUT_PATH/$LOG_FILE
$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE >> $OUTPUT_PATH/$LOG_FILE
RETCODE=$?
if [[ $RETCODE != 0 ]] ; then
	print 'SQLPlus FAILED - error message is: ' >> $OUTPUT_PATH/$LOG_FILE
	print ' '                                   >> $OUTPUT_PATH/$LOG_FILE
	tail -20 $OUTPUT_PATH/$DAT_FILE             >> $OUTPUT_PATH/$LOG_FILE
	exit_script $RETCODE 'SQLPlus Error'
fi

#----------------------------------
# New Report Query
#----------------------------------

cat > $INPUT_PATH/$SQL_FILE <<- EOF
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
	SPOOL $OUTPUT_PATH/$DAT_FILE1
	alter session enable parallel dml;
	
	SELECT
		TRANSLATE(rpt.CLT_NAME, ',', ' ')
		|| ','
		|| rpt.CLT_ID 
		|| ','
		|| rpt.EXTNL_SRC_CD 
		|| ','
		|| rpt.MODEL_TYP_CD 
		|| ','
		|| rpt.COUNT 
		|| ','
		|| rpt.EFFECTIVE_DT 
		|| ','
		|| rpt.EXPIRATION_DT
		|| ','
		|| rpt.QL_CLT_ID
		|| ','
		|| rpt.EXCPT_ID
	FROM (
		SELECT /*+ ordered use_hash(tcm) use_hash(tri) parallel(tcm,8) parallel(tri,8) */
			tri.RBATE_ID_NAM AS CLT_NAME
			,scng.RBATE_ID AS CLT_ID
			,scng.EXTNL_SRC_CD
			,CASE
				WHEN scng.MODEL_TYP_CD = 'D' THEN 'Discount'
				WHEN scng.MODEL_TYP_CD = 'X' THEN 'Medicare'
				ELSE 'Unknown'
			 END AS MODEL_TYP_CD
			,COUNT(scng.RBATE_ID) AS COUNT
			,tcm.EFFECTIVE_DT
			,tcm.EXPIRATION_DT
			,scng.QL_CLT_ID
			,scng.EXCPT_ID			
		FROM
			DMA_RBATE2.T_RBATE_ID tri,
			DMA_RBATE2.T_CLT_MODEL tcm,
			DMA_RBATE2.S_CLAIM_NON_GPO_EXCPT scng
		WHERE
			scng.RBATE_ID = tcm.CLT_ID
			AND scng.MODEL_TYP_CD = tcm.MODEL_TYP_CD
			AND scng.RBATE_ID = tri.RBATE_ID(+)
			AND scng.MODEL_TYP_CD IN ('D','X')
			AND scng.CYCLE_GID = $CYCLE_GID
		GROUP BY
			tri.RBATE_ID_NAM
			,scng.RBATE_ID
			,scng.EXTNL_SRC_CD
			,CASE
				WHEN scng.MODEL_TYP_CD = 'D' THEN 'Discount'
				WHEN scng.MODEL_TYP_CD = 'X' THEN 'Medicare'
				ELSE 'Unknown'
			 END
			,tcm.EFFECTIVE_DT
			,tcm.EXPIRATION_DT
			,scng.QL_CLT_ID
			,scng.EXCPT_ID
	) rpt;
	quit;
EOF

cat $INPUT_PATH/$SQL_FILE >> $OUTPUT_PATH/$LOG_FILE
$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE >> $OUTPUT_PATH/$LOG_FILE
RETCODE=$?
if [[ $RETCODE != 0 ]] ; then
	print 'SQLPlus FAILED - error message is: ' >> $OUTPUT_PATH/$LOG_FILE
	print ' '                                   >> $OUTPUT_PATH/$LOG_FILE
	tail -20 $OUTPUT_PATH/$DAT_FILE             >> $OUTPUT_PATH/$LOG_FILE
	exit_script $RETCODE 'SQLPlus Error'
fi


done < $OUTPUT_PATH/$CTRL_FILE

# FTP the files
# Read non-empty lines from FTP_CONFIG
print "$FTP_CONFIG" | while read FTP_HOST FTP_DIR; do
	if [[ -z $FTP_HOST ]]; then
		continue
	fi
	print "Transfering $OUTPUT_PATH/$DAT_FILE to [$FTP_HOST] [$FTP_DIR]" >> $OUTPUT_PATH/$LOG_FILE
	print "Transfering $OUTPUT_PATH/$DAT_FILE1 to [$FTP_HOST] [$FTP_DIR]" >> $OUTPUT_PATH/$LOG_FILE
	
	# Build variable containing commands
	FTP_CMDS=$(
		if [[ -n $FTP_DIR ]]; then
			print "cd $FTP_DIR"
		fi
		print "put "$OUTPUT_PATH/$DAT_FILE" "$FILE_BASE"_"$CYCLE_GID".dat"
		print "put "$OUTPUT_PATH/$DAT_FILE1" "$FILE_BASE"_"$CYCLE_GID"_excpt.dat"
		print "bye"
	)
	
	# Perform the FTP
	print "Ftp commands:\n$FTP_CMDS\n" >> $OUTPUT_PATH/$LOG_FILE
	FTP_OUTPUT=$(print "$FTP_CMDS" | ftp -vi "$FTP_HOST")
	RETCODE=$?
	
	# Parse the output for 400 & 500 level FTP reply (error) codes
	ERROR_COUNT=$(print "$FTP_OUTPUT" | egrep -v 'bytes (sent|received)' | egrep -c '^\s*[45][0-9][0-9]')
	print "$FTP_OUTPUT" >> $OUTPUT_PATH/$LOG_FILE

	if [[ $RETCODE != 0 ]] ; then
		print 'FTP FAILED' >> $OUTPUT_PATH/$LOG_FILE
		exit_script $RETCODE 'FTP Error'
	fi
	
	if [[ $ERROR_COUNT -gt 0 ]]; then
		RETCODE=$ERROR_COUNT
		print 'FTP FAILED' >> $OUTPUT_PATH/$LOG_FILE
		exit_script $RETCODE 'FTP Error'
	fi
done

exit_script $RETCODE

