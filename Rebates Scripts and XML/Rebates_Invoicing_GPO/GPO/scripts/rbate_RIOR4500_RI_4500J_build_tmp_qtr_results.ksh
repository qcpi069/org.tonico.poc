#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIOR4500_RI_4500J_build_tmp_qtr_results.ksh  
# Title         : APC file processing.
#
# Description   : Extracts APC records into the 323 byte format 
#                 for future split into 10,000,000 record files,
#                 zip and transmit to MVS
# Maestro Job   : RIOR4500 RI_4500J
#
# Parameters    : CYCLE_GID
#
# Output        : Log file as $OUTPUT_PATH/rbate_RIOR4500_RI_4500J_build_tmp_qtr_results.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date        ID      PARTE #  Description
# ---------  ---------  -------  ------------------------------------------#
# 09-14-2007  is23301		 Initial Creation.
#                                Split rbate_RIOR4500_RI_4500J_APC_rbated_clm_extract.ksh
#                                script into 3 parts, RI_4500J is Build TMP QTR Results,
#                                RI_4502J to extract rebated APC and RI_4552J is the 
#                                LCM AMT Rebated Extracted Report.
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
  if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
    export ALTER_EMAIL_ADDRESS='richard.hutchison@Caremark.com'
    MVS_FTP_PREFIX='TEST.X'
    SCHEMA_OWNER="dma_rbate2"
    FTP_USER_DIR=/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/APC_files
  else
    # Running in Prod region
    export ALTER_EMAIL_ADDRESS=''
    MVS_FTP_PREFIX='PCS.P'
    SCHEMA_OWNER="dma_rbate2"
    FTP_USER_DIR=/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/APC_files/test
  fi
else
  # Running in Development region
  export ALTER_EMAIL_ADDRESS='nick.tucker@Caremark.com'
  MVS_FTP_PREFIX='TEST.D'
  SCHEMA_OWNER="dma_rbate2"
  FTP_USER_DIR=/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/APC_files/test
fi

RETCODE=0
APCType='REBATED'
FTP_IP='204.99.4.30'
FTP_USER_IP=AZSHISP00
FTP_USER_SOURCE_DIR="/staging/rebate2"
FTP_USER_FILE="apc_tmp_quarter_results_summary_data.txt"
SCHEDULE="RIOR4500"
JOB="RI_4500J"
APC_OUTPUT_DIR=$OUTPUT_PATH/apc
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_build_tmp_qtr_results"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
LOG_ARCH=$FILE_BASE".log"
SQL_FILE=$APC_OUTPUT_DIR/$FILE_BASE".sql"
SQL_PIPE_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_pipe.lst"
SQL_LOG_FILE1=$APC_OUTPUT_DIR/$FILE_BASE"SQLLOG1.sql"
SQL_LOG_FILE2=$APC_OUTPUT_DIR/$FILE_BASE"SQLLOG2.sql"
DAT_FILE_OUTPUT=$APC_OUTPUT_DIR/$FILE_BASE".dat"
MVS_FTP_COM_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_ftpcommands.txt" 
EMAIL_TEXT_DATA_CENTER=$FILE_BASE"_email.txt"  
FTP_MVS_CNTLCARD_FILE=" '"$MVS_FTP_PREFIX".TM30D011.CNTLCARD(KSZ4900C)'"
FTP_MVS_SCL_TRIGGER=" '"$MVS_FTP_PREFIX".KSZ4900.KS15APC.SCL.TRIGGER'"
MVS_CNTLCARD_DAT=$APC_OUTPUT_DIR"/rbate_APC_"$APCType"_file_KSZ4900C.dat"
MVS_SCL_TRG=$APC_OUTPUT_DIR"/rbate_APC_extract_scl.trg"
FTP_MVS_RBATED_CLM_TRIGGER=" '"$MVS_FTP_PREFIX".KSZ4920J.APCFINAL.REBATED.DETL.TRIG'"
MVS_RBATED_CLM_TRIGGER=$APC_OUTPUT_DIR"/rbate_APC_rbated_clm.trg"
ORA_PACKAGE_NME=$SCHEMA_OWNER".pk_bld_tmp_qtr_results_driver.prc_bld_tmp_qtr_results_driver"
ORACLE_PKG_RETCODE=$OUTPUT_PATH/$FILE_BASE"_ora.log"
FTP_USER_COM_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_ftpcommands_user_file.txt"

#added for SOX
CYCLE_GID_DAT=$APC_OUTPUT_DIR/$FILE_BASE"_closed_cycle_gid.dat"
CYCLE_GID_SQL=$APC_OUTPUT_DIR/$FILE_BASE"_closed_cycle_gid.sql"

rm -f $LOG_FILE
rm -f $DAT_FILE_OUTPUT
rm -f $MVS_CNTLCARD_DAT
rm -f $MVS_SCL_TRG
rm -f $MVS_FTP_COM_FILE
rm -f $SQL_PIPE
rm -f $FTP_MVS_RBATED_CLM_TRIGGER
rm -f $MVS_RBATED_CLM_TRIGGER
rm -f $CYCLE_GID_DAT
rm -f $CYCLE_GID_SQL
rm -f $ORACLE_PKG_RETCODE
rm -f $FTP_USER_FILE

#Clean up previous runs trigger files - must do to allow reruns of the split job.  See Sleep in split job.
# NOTE that the Data Mart Trigger file name is used in the rbate_APC_extract_split.ksh, 
# the rbate_APC_extract_zip.ksh and the rbate_RIOR4500_RI_4504J_APC_submttd_clm_extract.ksh 
# scripts, so if the name changes, it must change in all four scripts.

rm -f $APC_OUTPUT_DIR/rbate_APC_extract_zip_DMART*.trg

print "Starting "$SCRIPTNAME                                                   >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
# PKGEXEC is the full SQL command to be executed
#-------------------------------------------------------------------------#

CYCLE_GID=$1
print ' '                                                                      >> $LOG_FILE

#added for SOX
if [[ $# -lt 1 ]]; then
    print "Cycle gid was not passed in, get CYCLE_GID from Oracle "            >> $LOG_FILE
    print "  where RBATE_CYCLE_STATUS = 'C'"                                   >> $LOG_FILE 
else
    print "Cycle gid was passed in, get CYCLE_GID from Oracle "                >> $LOG_FILE
    print "  where RBATE_CYCLE_STATUS = 'C' "                                  >> $LOG_FILE 
    print "  and use AND_CLAUSE variable"                                      >> $LOG_FILE 
    AND_CLAUSE="    AND rbate_cycle_gid = $CYCLE_GID" 
    print "  AND_CLAUSE variable is " $AND_CLAUSE                              >> $LOG_FILE 
fi    

    db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

### CANNOT INDENT THIS, DOWN TO EOF!
cat > $CYCLE_GID_SQL << EOF
set LINESIZE 200
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
SPOOL $CYCLE_GID_DAT
SELECT MAX(rbate_cycle_gid)
      ,' '
      ,TO_CHAR(cycle_start_date,'MM-DD-YYYY')
      ,' '
      ,TO_CHAR(cycle_end_date,'MM-DD-YYYY')
      ,' '
      ,substrb(MAX(rbate_cycle_gid),1,4)||decode(substrb(MAX(rbate_cycle_gid),6,1),1,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1)
                                                                                  ,2,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1)
                                                                                  ,3,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1)
                                                                                  ,4,     (((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1))
      ,' '
      ,substrb(MAX(rbate_cycle_gid),1,4)||decode(substrb(MAX(rbate_cycle_gid),6,1),1,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2)
                                                                                  ,2,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2)
                                                                                  ,3,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2)
                                                                                  ,4,     (((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2))     
      ,' '
      ,substrb(MAX(rbate_cycle_gid),1,4)||decode(substrb(MAX(rbate_cycle_gid),6,1),1,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3)
                                                                                  ,2,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3)
                                                                                  ,3,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3)
                                                                                  ,4,     (((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3))     
    FROM dma_rbate2.t_rbate_cycle
    WHERE rbate_cycle_gid = (SELECT MAX(rbate_cycle_gid) 
                                   FROM dma_rbate2.t_rbate_cycle
                                  WHERE rbate_cycle_type_id = 2
                                AND   rbate_cycle_status = UPPER('C') $AND_CLAUSE)
    GROUP BY cycle_start_date, cycle_end_date
;    
quit;
EOF
 
    $ORACLE_HOME/bin/sqlplus -s $db_user_password @$CYCLE_GID_SQL

    RETCODE=$?
 
    #  Leave READ here even if error occurred, to show what was written out.
    FIRST_READ=1
    while read input_CYCLE_GID input_QTR_STRT_DT input_QTR_END_DT input_MTH1_GID input_MTH2_GID input_MTH3_GID; do
      if [[ $FIRST_READ != 1 ]]; then
        print "Finishing control file read" >>  $LOG_FILE
      else
        FIRST_READ=0
        print "Cycle Gid from Oracle is          >"$input_CYCLE_GID"<"         >> $LOG_FILE
        print "Quarter Start Date from Oracle is >"$input_QTR_STRT_DT"<"       >> $LOG_FILE
        print "Quarter End Date from  Oracle is  >"$input_QTR_END_DT"<"        >> $LOG_FILE
        print "Month 1 Cycle Gid from Oracle is  >"$input_MTH1_GID"<"          >> $LOG_FILE
        print "Month 2 Cycle Gid from Oracle is  >"$input_MTH2_GID"<"          >> $LOG_FILE
        print "Month 3 Cycle Gid from Oracle is  >"$input_MTH3_GID"<"          >> $LOG_FILE
        CYCLE_GID=$input_CYCLE_GID
        QTR_STRT_DT=$input_QTR_STRT_DT
        QTR_END_DT=$input_QTR_END_DT
        MTH1_GID=$input_MTH1_GID
        MTH2_GID=$input_MTH2_GID
        MTH3_GID=$input_MTH3_GID
      fi
    done < $CYCLE_GID_DAT

if [[ -z $CYCLE_GID || -z $QTR_STRT_DT || -z $QTR_END_DT || -z $MTH1_GID || -z $MTH2_GID || -z $MTH3_GID ]]; then
    RETCODE=1
    print " "                                                                  >> $LOG_FILE
    print `date`                                                               >> $LOG_FILE
    print "Script abending because no data returned from Oracle."              >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Cycle Gid from Oracle is          >"$CYCLE_GID"<"                   >> $LOG_FILE
    print "Quarter Start Date from Oracle is >"$QTR_STRT_DT"<"                 >> $LOG_FILE
    print "Quarter End Date from  Oracle is  >"$QTR_END_DT"<"                  >> $LOG_FILE
    print "Month 1 Cycle Gid from Oracle is  >"$MTH1_GID"<"                    >> $LOG_FILE
    print "Month 2 Cycle Gid from Oracle is  >"$MTH2_GID"<"                    >> $LOG_FILE
    print "Month 3 Cycle Gid from Oracle is  >"$MTH3_GID"<"                    >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
fi




#----------------------------------
# Create the Package to be executed
#----------------------------------

if [[ $RETCODE = 0 ]]; then

    print ' '                                                                  >> $LOG_FILE
    CUR_PARM="'CUR'"
    print `date`                                                               >> $LOG_FILE

    ORA_PKG_CYCLE_INPUT=\($CYCLE_GID","$CUR_PARM\)";"

    print " "                                                                  >> $LOG_FILE

    PKGEXEC=$ORA_PACKAGE_NME$ORA_PKG_CYCLE_INPUT

    print " "                                                                  >> $LOG_FILE
    print `date`                                                               >> $LOG_FILE
    print "Beginning Package call of " $PKGEXEC                                >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    #----------------------------------
    # Oracle userid/password
    #----------------------------------

    db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

    #-------------------------------------------------------------------------#
    # Execute the SQL run the Package to manipulate the IPDR file
    #-------------------------------------------------------------------------#

# CANNOT INDENT THIS!!  IT WONT FIND THE EOF!
cat > $SQL_FILE << EOF
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
SPOOL $ORACLE_PKG_RETCODE
EXEC $PKGEXEC
quit;
EOF

    $ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

    RETCODE=$?

    print " "                                                                  >> $LOG_FILE
    print `date`                                                               >> $LOG_FILE
    print "Package call Return Code is :" $RETCODE                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
fi
    
if [[ $RETCODE = 0 ]]; then
    print ' '                                                                  >> $LOG_FILE
    print "Successfully completed Package call of " $PKGEXEC                   >> $LOG_FILE
    print ' '                                                                  >> $LOG_FILE
else
    print "Failure in Package call of " $PKGEXEC                               >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    #ORACLE_PKG_RETCODE file will be empty if package was successful, will hold ORA errors if unsuccessful
    cat $ORACLE_PKG_RETCODE 							>> $LOG_FILE

    print ' '                                                                  >> $LOG_FILE
    print "===================== SCRIPT FAILED ==========================" >> $LOG_FILE
    print "script "$TMP_QTR_RESULTS_CALL_SCRIPT "Failed."                  >> $LOG_FILE
    print "Look in " $OUTPUT_PATH/$TMP_QTR_RESULTS_CALL_SCRIPT_LOG          >> $LOG_FILE
    print `date`                                                           >> $LOG_FILE
    print "==============================================================" >> $LOG_FILE
    print ' '                                                                  >> $LOG_FILE
fi


if [[ $RETCODE = 0 ]]; then

    # Start FTP the KSZ4900C MVS Control Card to the MVS
    
    print $CYCLE_GID > awk_input.dat

    Rbate_Yr=`nawk 'BEGIN { getline ndate;
                        $1 = substr(ndate,3,2)
            print $1
                        exit
                      }' < awk_input.dat`

    Rbate_Qtr=`nawk 'BEGIN { getline ndate;
                        $1 = substr(ndate,5,2)
                        print $1
            exit
                      }' < awk_input.dat`

    if [ $Rbate_Qtr = '41' ]; then
        Rbate_Qtr='Q1'
    fi
    if [ $Rbate_Qtr = '42' ]; then
        Rbate_Qtr='Q2'
    fi
    if [ $Rbate_Qtr = '43' ]; then
        Rbate_Qtr='Q3'
    fi
    if [ $Rbate_Qtr = '44' ]; then
        Rbate_Qtr='Q4'
    fi
    
    print " " >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    print "FTPing the KSZ4900C MVS Control Card to the MVS. "  >> $LOG_FILE
    print "Parms used in the CNTLCARD - APCType " $APCType ","  >> $LOG_FILE
    print "Rbate_Yr = " $Rbate_Yr ", and Rbate_Qtr " $Rbate_Qtr "." >> $LOG_FILE
    print `date` >> $LOG_FILE

    print "//*  THIS CONTROL CARD FILE IS GENERATED FROM UNIX KORN SCRIPT "   >> $MVS_CNTLCARD_DAT
    print "//*  " $SCRIPTNAME    >> $MVS_CNTLCARD_DAT
    print "//*  ITS PURPOSE IS TO MAKE AVAILABLE THE PROPER SUBSTITUTION  "   >> $MVS_CNTLCARD_DAT
    print "//*  VARIABLES FOR NAMING THE APC FILE PROPERLY THAT HAS BEEN  "   >> $MVS_CNTLCARD_DAT
    print "//*  SENT UP FROM UNIX.                                        "   >> $MVS_CNTLCARD_DAT
    print "//*                                                            "   >> $MVS_CNTLCARD_DAT
    print "//   SET CQTRYY=""'"$Rbate_Yr"'" "             CURRENT YEAR"        >> $MVS_CNTLCARD_DAT
    print "//   SET CQTR=""'"$Rbate_Qtr"'" "            CURRENT QUARTER"      >> $MVS_CNTLCARD_DAT

    print "Control Card Built - " $MVS_CNTLCARD_DAT >>$LOG_FILE
    print "Trigger file for loading SCL KS15APC to the schedule."   >> $MVS_SCL_TRG
    print 'put ' $MVS_CNTLCARD_DAT " " $FTP_MVS_CNTLCARD_FILE ' (replace' >> $MVS_FTP_COM_FILE
    print 'put ' $MVS_SCL_TRG " " $FTP_MVS_SCL_TRIGGER ' (replace' >> $MVS_FTP_COM_FILE  
    print "=================================================================" >> $LOG_FILE
    print "quit" >> $MVS_FTP_COM_FILE
    
    print " " >> $LOG_FILE
    print "================== CONCATENATE FTP COMMANDS =========================" >> $LOG_FILE
    print "Start Concatenating FTP Commands " >> $LOG_FILE
    cat $MVS_FTP_COM_FILE >> $LOG_FILE
    print "End Concatenating FTP Commands " >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    #do not capture return code here, if cat to the log failed, do not end script.

    ftp -i  $FTP_IP < $MVS_FTP_COM_FILE >> $LOG_FILE

    RETCODE=$?
    
    if  [[ $RETCODE != 0 ]]; then
        print " " >> $LOG_FILE
        print "================= FTP COMMAND FAILED ============================" >> $LOG_FILE
        print "FTP of MVS Control Card FAILED." >> $LOG_FILE
        print `date` >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
    else
        print " " >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
        print "MVS Control Card ftp process complete "  >> $LOG_FILE
        print `date` >> $LOG_FILE
        # End FTP the KSZ4900C MVS Control Card to the MVS
        print "=================================================================" >> $LOG_FILE
    fi
    print 'put ' $MVS_CNTLCARD_DAT " " $FTP_MVS_CNTLCARD_FILE ' (replace' >> $MVS_FTP_COM_FILE
    print 'put ' $MVS_SCL_TRG " " $FTP_MVS_SCL_TRIGGER ' (replace' >> $MVS_FTP_COM_FILE  
    print "=================================================================" >> $LOG_FILE
    print "quit" >> $MVS_FTP_COM_FILE
    
    print " " >> $LOG_FILE
    print "================== CONCATENATE FTP COMMANDS =========================" >> $LOG_FILE
    print "Start Concatenating FTP Commands " >> $LOG_FILE
    cat $MVS_FTP_COM_FILE >> $LOG_FILE
    print "End Concatenating FTP Commands " >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    #do not capture return code here, if cat to the log failed, do not end script.

    ftp -i  $FTP_IP < $MVS_FTP_COM_FILE >> $LOG_FILE

    RETCODE=$?
    
    if  [[ $RETCODE != 0 ]]; then
        print " "                                                                 >> $LOG_FILE
        print "================= FTP COMMAND FAILED ============================" >> $LOG_FILE
        print "FTP of MVS Control Card FAILED."                                   >> $LOG_FILE
        print `date`                                                              >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
    else
        print " "                                                                 >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
        print "MVS Control Card ftp process complete "                            >> $LOG_FILE
        print `date`                                                              >> $LOG_FILE
        # End FTP the KSZ4900C MVS Control Card to the MVS
        print "=================================================================" >> $LOG_FILE
    fi

    if  [[ $RETCODE = 0 ]]; then
        # The file being FTPd here is an output file from the call to the Oracle PK_BLD_TMP_QTR_RESULTS_DRIVER.
        # It is being FTPd over to the users LAN so that they can review it.
	print " "                                                                          >> $LOG_FILE
	print "cd " $FTP_USER_DIR                                                          >> $FTP_USER_COM_FILE
	print "put " $FTP_USER_SOURCE_DIR/$FTP_USER_FILE " " $FTP_USER_FILE " (replace"    >> $FTP_USER_COM_FILE
	print "==========================================================================" >> $LOG_FILE
	print "quit"                                                                       >> $FTP_USER_COM_FILE
	print " "                                                                          >> $LOG_FILE
	print "================== CONCATENATE USER FTP COMMANDS =========================" >> $LOG_FILE
	print "Start Concatenating USER FTP Commands "                                     >> $LOG_FILE
	cat $FTP_USER_COM_FILE                                                             >> $LOG_FILE
	print "End Concatenating USER FTP Commands "                                       >> $LOG_FILE
	print "==========================================================================" >> $LOG_FILE
	#do not capture return code here, if cat to the log failed, do not end script.

	ftp -i  $FTP_USER_IP < $FTP_USER_COM_FILE                                          >> $LOG_FILE

	RETCODE=$?

	if  [[ $RETCODE != 0 ]]; then
            print " " >> $LOG_FILE
            print "================= FTP COMMAND FAILED ============================" >> $LOG_FILE
            print "USER summary file FTP FAILED."                                     >> $LOG_FILE
            print `date`                                                              >> $LOG_FILE
            print "=================================================================" >> $LOG_FILE
        else
            print " "                                                                 >> $LOG_FILE
            print "=================================================================" >> $LOG_FILE
            print "USER summary file ftp process complete "                           >> $LOG_FILE
            print `date`                                                              >> $LOG_FILE
            print "=================================================================" >> $LOG_FILE
	fi
    fi
fi

#start script abend logic
if  [[ $RETCODE != 0 ]]; then
    print "APC Extract Failed - error message is: " >> $LOG_FILE 
    print ' ' >> $LOG_FILE 
    print "===================== J O B  A B E N D E D ======================" >> $LOG_FILE
    print "  Error Executing "$SCRIPTNAME"          " >> $LOG_FILE
    print "  Look in "$LOG_FILE       >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE

    # Send the Email notification 

    export JOBNAME=$SCHEDULE" / "$JOB
    export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
    export LOGFILE=$LOG_FILE
    export EMAILPARM4="  "
    export EMAILPARM5="  "

    print "Sending email notification with the following parameters" >> $LOG_FILE
    print "JOBNAME is " $JOBNAME >> $LOG_FILE 
    print "SCRIPTNAME is " $SCRIPTNAME >> $LOG_FILE
    print "LOGFILE is " $LOGFILE >> $LOG_FILE
    print "EMAILPARM4 is " $EMAILPARM4 >> $LOG_FILE
    print "EMAILPARM5 is " $EMAILPARM5 >> $LOG_FILE
    print "****** end of email parameters ******" >> $LOG_FILE

    . $SCRIPT_PATH/rbate_email_base.ksh
    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
    exit $RETCODE
fi

#Clean up files - DO NOT REMOVE THE MVS_CNTCARD_DAT FILE!  Required for RI_4508J job.
rm -f $SQL_FILE
# do not remove SQL_PIPE_FILE - issue came up where pipe file was deleted before all records spooled out.
##rm -f $SQL_PIPE_FILE
rm -f $MVS_SCL_TRG
rm -f $MVS_FTP_COM_FILE
rm -f $CYCLE_GID_DAT
rm -f $CYCLE_GID_SQL
rm -f $ORACLE_PKG_RETCODE

print "....Completed executing " $SCRIPTNAME " ...."   >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE

