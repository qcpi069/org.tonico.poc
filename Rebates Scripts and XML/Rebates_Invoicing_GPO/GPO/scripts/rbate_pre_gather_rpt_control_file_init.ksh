#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_pre_gather_rpt_control_file_init.ksh.ksh  
# Title         : Create Pre-Gather reporting control file of CYCLE_GIDs
#                 in status A. 
#
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 04-25-03    K.Gries   Initial Creation. 
# 09-15-05    Castillo   Modifications for Rebates Integration Phase 2
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#


. `dirname $0`/rebates_env.ksh

SCRIPTNAME=$(basename $0)
FILE_BASE="${SCRIPTNAME%.ksh}"
LOG_FILE="${FILE_BASE}.log"
SQL_FILE="${FILE_BASE}.sql"
DAT_FILE="${FILE_BASE}.dat"
FTP_CMDS="${FILE_BASE}_ftpcommands.txt"

GDX_HOST=
GDX_REMOTE_DIR=
GDX_CONTROL_FILE_NAME="gdx_pre_gather_rpt_control_file_init.dat"
RBATE_CYCLE_MONTHLY_TYPE=1
RBATE_CYCLE_QUARTERLY_TYPE=2
RETCODE=0

# Use this alias to print out the filename and line number an error occurred on
alias print_err='print "[$SCRIPTNAME:$LINENO]"'

# Set variables based on region
if [[ "$REGION" = "prod" ]]; then
	if [[ "$QA_REGION" = "true" ]]; then
		GDX_HOST=r07tst07
		GDX_REMOTE_DIR=/GDX/test/input
	else
		GDX_HOST=r07prd01
		GDX_REMOTE_DIR=/GDX/prod/input
	fi
else
	GDX_HOST=r07tst07
	GDX_REMOTE_DIR=/GDX/test/input
fi

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$DAT_FILE
rm -f $OUTPUT_PATH/$GDX_CONTROL_FILE_NAME
rm -f $INPUT_PATH/$SQL_FILE

# Run commands from the script directory
cd $SCRIPT_PATH

print 'Starting ' $SCRIPT_PATH/$SCRIPTNAME  >> $OUTPUT_PATH/$LOG_FILE
print `date`                                >> $OUTPUT_PATH/$LOG_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------
db_user_password=`cat $SCRIPT_PATH/ora_user.fil`


#-------------------------------------------------------------------------#
# Create file with monthly cycle dates
#-------------------------------------------------------------------------#
if [[ $RETCODE = 0 ]]; then
	cat > $INPUT_PATH/$SQL_FILE <<- EOF
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
		spool $OUTPUT_PATH/$DAT_FILE
		
		SELECT
			rbate_cycle_gid
			|| ' '
			|| to_char(cycle_start_date,'MMDDYYYY')
			|| ' '
			|| to_char(cycle_end_date,'MMDDYYYY')
		FROM dma_rbate2.t_rbate_cycle a
		WHERE
			upper(rbate_cycle_status) = upper('A') AND
			rbate_cycle_type_id = $RBATE_CYCLE_MONTHLY_TYPE;

		quit;
	EOF
	
	$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE
	RETCODE=$?

	if [[ $RETCODE != 0 ]]; then
		print_err "Error executing SQLPlus ($RETCODE)" >> $OUTPUT_PATH/$LOG_FILE
	fi

	print 'SQLPlus complete' >> $OUTPUT_PATH/$LOG_FILE
	print `date` >> $OUTPUT_PATH/$LOG_FILE
fi


#-------------------------------------------------------------------------#
# Create file with monthly & quarterly cycle dates
#-------------------------------------------------------------------------#
if [[ $RETCODE = 0 ]]; then
	cat > $INPUT_PATH/$SQL_FILE <<- EOF
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
		spool $OUTPUT_PATH/$GDX_CONTROL_FILE_NAME

		SELECT
			a.rbate_cycle_gid
			|| ' '
			|| to_char(a.cycle_start_date,'MMDDYYYY')
			|| ' '
			|| to_char(a.cycle_end_date,'MMDDYYYY')
			|| ' '
			|| b.rbate_cycle_gid
			|| ' '
			|| to_char(b.cycle_start_date,'MMDDYYYY')
			|| ' '
			|| to_char(b.cycle_end_date,'MMDDYYYY')
		FROM dma_rbate2.t_rbate_cycle a, dma_rbate2.t_rbate_cycle b
		WHERE
			upper(a.rbate_cycle_status) = upper('A') AND
			a.rbate_cycle_type_id = $RBATE_CYCLE_MONTHLY_TYPE AND
			a.cycle_start_date >= b.cycle_start_date AND 
			a.cycle_start_date < trunc(b.cycle_end_date) + 1 AND
			b.rbate_cycle_type_id = $RBATE_CYCLE_QUARTERLY_TYPE;
		
		quit;
	EOF
	
	$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE
	RETCODE=$?

	if [[ $RETCODE != 0 ]]; then
		print_err "Error executing SQLPlus ($RETCODE)" >> $OUTPUT_PATH/$LOG_FILE
	fi
	
	print 'SQLPlus complete' >> $OUTPUT_PATH/$LOG_FILE
	print `date` >> $OUTPUT_PATH/$LOG_FILE
fi

#-------------------------------------------------------------------------#
# FTP file to GDX
#-------------------------------------------------------------------------#
if [[ $RETCODE = 0 ]]; then
	print " " >> $OUTPUT_PATH/$LOG_FILE
	print `date` "Copying control file to $GDX_HOST via FTP"                    >> $OUTPUT_PATH/$LOG_FILE
	cat <<-END_FTP > "$INPUT_PATH/$FTP_CMDS"
		cd $GDX_REMOTE_DIR
		del $GDX_CONTROL_FILE_NAME
		put $OUTPUT_PATH/$GDX_CONTROL_FILE_NAME $GDX_CONTROL_FILE_NAME
		bye
	END_FTP
	
	ftp -v -i $GDX_HOST < "$INPUT_PATH/$FTP_CMDS" >> $OUTPUT_PATH/$LOG_FILE
	RETCODE=$?

	if [[ $RETCODE != 0 ]]; then
		print_err "Error executing FTP ($RETCODE)" >> $OUTPUT_PATH/$LOG_FILE
	else
		print " " >> $OUTPUT_PATH/$LOG_FILE
		print `date` "FTP of "$OUTPUT_PATH/$DAT_FILE" to "$GDX_HOST" complete"  >> $OUTPUT_PATH/$LOG_FILE
	fi
fi


#-------------------------------------------------------------------------#
# Check for good return from sqlplus/ftp
#-------------------------------------------------------------------------#
if [[ $RETCODE != 0 ]]; then
	print "                                                                 "   >> $OUTPUT_PATH/$LOG_FILE
	print "===================== J O B  A B E N D E D ======================"   >> $OUTPUT_PATH/$LOG_FILE
	print "  Error Executing " $SCRIPT_PATH/$SCRIPTNAME                         >> $OUTPUT_PATH/$LOG_FILE
	print "  Look in "$OUTPUT_PATH/$LOG_FILE                                    >> $OUTPUT_PATH/$LOG_FILE
	print "================================================================="   >> $OUTPUT_PATH/$LOG_FILE
            
	cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`

	# Send the Email notification 
	export JOBNAME="RIHR4200 / RI_4200J"
	####   export SCRIPTNAME=$OUTPUT_PATH"/rbate_pre_gather_rpt_control_file_init.ksh"
	export LOGFILE=$OUTPUT_PATH"/rbate_pre_gather_rpt_control_file_init.log"
	export EMAILPARM4="  "
	export EMAILPARM5="  "
   
	print "Sending email notification with the following parameters"            >> $OUTPUT_PATH/$LOG_FILE
	print "JOBNAME is " $JOBNAME                                                >> $OUTPUT_PATH/$LOG_FILE
	print "SCRIPTNAME is " $SCRIPTNAME                                          >> $OUTPUT_PATH/$LOG_FILE
	print "LOGFILE is " $LOGFILE                                                >> $OUTPUT_PATH/$LOG_FILE
	print "EMAILPARM4 is " $EMAILPARM4                                          >> $OUTPUT_PATH/$LOG_FILE
	print "EMAILPARM5 is " $EMAILPARM5                                          >> $OUTPUT_PATH/$LOG_FILE
	print "****** end of email parameters ******"                               >> $OUTPUT_PATH/$LOG_FILE
   
	. $SCRIPT_PATH/rbate_email_base.ksh

	cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
	exit $RETCODE
fi

#-------------------------------------------------------------------------#
# Copy the log file over and end the job                  
#-------------------------------------------------------------------------#

print "....Completed executing " $SCRIPT_PATH/$SCRIPTNAME " ..."               >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

