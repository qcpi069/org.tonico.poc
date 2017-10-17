#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KSMN7600_KS_7605J_rxc_lcm_refresh.ksh   
# Title         : .
#
# Description   : Create the MSTAR Reporting data, and extract it and 
#                 other MSTAR necessary files, for Gary Kauffman and the
#                 Strategic Contracting group.                 
#                 
# Maestro Job   : KSMN7600/KS_7605J
#
# Parameters    : Accepts an input date in the form of MMDDYYYY, BUT 
#                 script does not require it.  If not passed in, the 
#                 stored procedure call will default to SYSDATE.
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 05-12-04   is45401     Initial Creation. Intentionally did not use EXPORT
# 09-13-05   B. Castillo Modifications for Rebates Integration Phase 2
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
	if [[ $QA_REGION = "true" ]];   then
		# Running in the QA region
		export ALTER_EMAIL_ADDRESS="${ALTER_EMAIL_ADDRESS:-randy.redus@caremark.com}"
		MVS_PREFIX="TEST.X"
	else
		# Running in Prod region
		export ALTER_EMAIL_ADDRESS=''
		MVS_PREFIX="PCS.P"
	fi
else
	# Running in Development region
	export ALTER_EMAIL_ADDRESS="${ALTER_EMAIL_ADDRESS:-randy.redus@caremark.com}"
	MVS_PREFIX="TEST.D"
fi

RETCODE=0
SCHEDULE="KSMN7600"
JOB="KS_7605J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_rxc_lcm_refresh"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
SQL_FILE=$INPUT_PATH/$FILE_BASE".sql"
PKG_LOG=$OUTPUT_PATH/$FILE_BASE"_pkglog.log"
FTP_CMDS=$OUTPUT_PATH/$FILE_BASE"_ftpcommands.txt"
FTP_MVS=204.99.4.30
FTP_DATA_FILE_BASE=$MVS_PREFIX."KSZ4000J.PLANLCM.EDWFEED.INIT"
FTP_UNIX_FILE_SRC_DIR=/staging/rebate2
FTP_UNIX_FILE_SRC=$FTP_UNIX_FILE_SRC_DIR/$FTP_DATA_FILE_BASE
FTP_UNIX_TRG_FILE_SRC=$FTP_UNIX_FILE_SRC_DIR/$FTP_DATA_FILE_BASE".TRG"
FTP_MVS_FILE_TRGT=$FTP_DATA_FILE_BASE
FTP_MVS_TRG_FILE_TRGT=$FTP_DATA_FILE_BASE".TRG"
RXLIVES_TRIGGER_FILE=$INPUT_PATH/monthly_rxlives_done.trg
# Oracle package parms - third parm could be null
Package_Name="rbate_reg.pk_rxc_lcm_driver.prc_rxc_lcm_driver"
PKG_PARM_1=$JOB
PKG_PARM_2="RXCLAIM LCM FEED"
PKG_PARM_3=$1

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $SQL_FILE
rm -f $FTP_CMDS
rm -f $PKG_LOG
rm -f $FTP_UNIX_FILE_SRC
rm -f $FTP_UNIX_TRG_FILE_SRC

print " " >> $OUTPUT_PATH/$LOG_FILE
print `date` "Starting " $SCRIPTNAME >> $OUTPUT_PATH/$LOG_FILE
print " " >> $OUTPUT_PATH/$LOG_FILE


# Remove success trigger file -bcc
rm -f $RXLIVES_TRIGGER_FILE

if [[ $# -lt 1 ]]; then
    # Only send the first two parms, third parm will default in stored procedure
	PKGEXEC=$Package_Name\(\'$PKG_PARM_1\'\,\'$PKG_PARM_2\'\);
else
	# Send all three parms
	PKGEXEC=$Package_Name\(\'$PKG_PARM_1\'\,\'$PKG_PARM_2\'\,\'$PKG_PARM_3\'\);
fi

print `date` >> $OUTPUT_PATH/$LOG_FILE
print "Beginning Package call of " $PKGEXEC  >> $OUTPUT_PATH/$LOG_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Execute the SQL run the Package
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/$LOG_FILE

cat > $SQL_FILE <<- EOF
	set linesize 5000
	set flush off
	set TERMOUT OFF
	set PAGESIZE 0
	set NEWPAGE 0
	set SPACE 0
	set ECHO OFF
	set FEEDBACK OFF
	set HEADING OFF
	set WRAP on
	set verify off
	whenever sqlerror exit 1
	SPOOL $PKG_LOG
	
	EXEC $PKGEXEC; 
	
	quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE
RETCODE=$?

#PKG_LOG file will be empty if package was successful, will hold ORA errors if unsuccessful
cat $PKG_LOG >> $OUTPUT_PATH/$LOG_FILE

print " " >> $OUTPUT_PATH/$LOG_FILE
print `date`  >> $OUTPUT_PATH/$LOG_FILE

if [[ $RETCODE = 0 ]]; then
	print "Successfully completed Package call of " $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE
else
	print "Failure in Package call of " $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE
fi

print "Package call Return Code is :" $RETCODE >> $OUTPUT_PATH/$LOG_FILE
print " " >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# See if the files exist or not
#-------------------------------------------------------------------------#
if [[ ! -f "$FTP_UNIX_FILE_SRC" ]]; then
	print "File [$FTP_UNIX_FILE_SRC] does not exist" >> $OUTPUT_PATH/$LOG_FILE
	RETCODE=1
fi

#-------------------------------------------------------------------------#
# Build the FTP commands and execute FTP for created files
#-------------------------------------------------------------------------#
if [[ $RETCODE = 0 ]]; then

	print "Create FTP commands and FTP ascii files" >> $OUTPUT_PATH/$LOG_FILE
	
	print 'put ' $FTP_UNIX_FILE_SRC           "'"$FTP_MVS_FILE_TRGT"'" ' (replace' >> $FTP_CMDS
	print 'put ' $FTP_UNIX_TRG_FILE_SRC   "'"$FTP_MVS_TRG_FILE_TRGT"'" ' (replace' >> $FTP_CMDS
	print 'quit'                                                   >> $FTP_CMDS
	cat $FTP_CMDS                                                  >> $FTP_UNIX_TRG_FILE_SRC   
	print " "                                                      >> $FTP_UNIX_TRG_FILE_SRC   
	print "Written out from UNIX Schedule "$SCHEDULE"/Job "$JOB    >> $FTP_UNIX_TRG_FILE_SRC  
	print "  and script "$SCRIPTNAME                               >> $FTP_UNIX_TRG_FILE_SRC  
	
	# print the FTP commands in the LOG file
	print " " >> $OUTPUT_PATH/$LOG_FILE
	cat $FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
	print " " >> $OUTPUT_PATH/$LOG_FILE
	
	ftp -v -i $FTP_MVS < $FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
	RETCODE=$?
	
	print `date`  >> $OUTPUT_PATH/$LOG_FILE
	
	if [[ $RETCODE = 0 ]]; then
		print "FTP of files completed - Return code =" $RETCODE >> $OUTPUT_PATH/$LOG_FILE
	else
		print "Failure in FTP" >> $OUTPUT_PATH/$LOG_FILE
	fi
	
	print "FTP Return Code is :" $RETCODE >> $OUTPUT_PATH/$LOG_FILE
	print " " >> $OUTPUT_PATH/$LOG_FILE

fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
	print " " >> $OUTPUT_PATH/$LOG_FILE
	print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
	print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
	print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
	print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE

	# Send the Email notification - have to use 'export' because fields are globally used in rbate_email_base.ksh
	JOBNAME=$SCHEDULE/$JOB
	SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
	LOGFILE=$OUTPUT_PATH/$LOG_FILE
	EMAILPARM4="  "
	EMAILPARM5="  "

	print "Sending email notification with the following parameters" >> $OUTPUT_PATH/$LOG_FILE
	print "JOBNAME is " $JOBNAME                                     >> $OUTPUT_PATH/$LOG_FILE 
	print "SCRIPTNAME is " $SCRIPTNAME                               >> $OUTPUT_PATH/$LOG_FILE
	print "LOGFILE is " $LOGFILE                                     >> $OUTPUT_PATH/$LOG_FILE
	print "EMAILPARM4 is " $EMAILPARM4                               >> $OUTPUT_PATH/$LOG_FILE
	print "EMAILPARM5 is " $EMAILPARM5                               >> $OUTPUT_PATH/$LOG_FILE
	print "****** end of email parameters ******"                    >> $OUTPUT_PATH/$LOG_FILE

	. $SCRIPT_PATH/rbate_email_base.ksh
	cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`

	exit $RETCODE
else
	rm -f $SQL_FILE
	rm -f $FTP_CMDS
	rm -f $PKG_LOG
	
	# Create the completion trigger file -bcc
	{
		print "Completion Trigger File"
		print "Created:       "`date`
		print "Generated By:  $0"
		print "User:          $USER"
		print "-------------------------------"
		print "This trigger file should be removed by rbate_refresh_cycle.ksh"
	} > $RXLIVES_TRIGGER_FILE

    print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
    mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
fi

exit $RETCODE

