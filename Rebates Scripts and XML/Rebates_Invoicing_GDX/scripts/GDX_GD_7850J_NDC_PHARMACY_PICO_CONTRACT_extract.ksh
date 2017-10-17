#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GD_7850J_NDC_PHARMACY_PICO_CONTRACT_extract.ksh
# Title         : Extract NDC, PHARMACY, PICP and CONTRACT from ORACLE and SFTP to Webtransport
#
# Description   : Extract information from DMA_Rbate2 for Rebate Payments 
#
# Abends        :
#
# Maestro Job   : GD_7850J 
#
# Parameters    : It is option. CYCLE_GID: APC billing quarter or a specific quarter
#               : The format is yyyy4q. 
#               : It is can be passed in as parameter, or will query from the table.
# 
# Output        : Log file as $LOG_FILE, 
#               : Data files as $NDC_DATA_FILE_OUTPUT, $PHARM_DATA_FILE_OUTPUT, PICO_DATA_FILE_OUTPUT
#               : SQL files as NDC_SQL_FILE, PHARM_SQL_FILE, PICO_SQL_FILE
#
# Input Files   : 
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 06/22/15   Z112009	 ITPR011275 - FTP Remediation - No Datafiles will be sent to MVS.
#			 Trigger file will be sent to MVS thru webtransport 
# 07-06-12   qcpi0n6     ITPR003455 - ACE 2012 - Rebates Phase 1
#                        Added CORP_CD as last field in PICO file extract
#						 File size increased to 68 bytes, CD_NM shortened to 25 from 30
#						 lrcel change before ftp step
# 07-06-12   qcpi0n6     ITPR003455 - ACE 2012 - Rebates Phase 1
# 05-14-10   qcpi733     Fixed call to Common_GDX_Email_Abend script, which was
#                        using a dev abend script from Vaibhav's changes.
# 03-22-10   qcpi733     Uncommented the END for APC status update which was
#                        accidently left commented by Vaibhavs code.
# 07-28-09   qcpi733     Added GDX APC status update
# 06-24-09   qcpi19v     Check to see if trigger file exists and remove the file
# 12-23-08   qcpue45a    Added Trigger file. 
# 09-07-07   Gries       Change to pull from GDX instead of Oracle. 
# 03-16-07   qcpi08a     initial Version
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    EMAILPARM4='  '
    EMAILPARM5='  '

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    {
        print 'Sending email notification with the following parameters'

        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"

        print '****** end of email parameters ******'
    } >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh
 
    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    . `dirname $0`/Common_GDX_APC_Status_update.ksh 140 ERR >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`

    exit $RETCODE
}

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

#-------------------------------------------------------------------------#
# Call the Common used script functions to make functions available
#-------------------------------------------------------------------------#

. $SCRIPT_PATH/Common_GDX_Script_Functions.ksh

#------------------------------------------------------------------------#
# Variables
#-------------------------------------------------------------------------#

RETCODE=0
SCHEDULE="RIOR4500"
JOBNAME="GD_7850J"
SCRIPTNAME=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log"
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"
ORACLE_DB_USER_PASSWORD=$(cat "${SCRIPT_PATH}/ora_user.fil")
CYCLE_GID_DAT=$OUTPUT_PATH/$FILE_BASE"_CYC_GID.dat"
CYCLE_GID_SQL=$SQL_PATH/$FILE_BASE"_CYCLE_GID.sql"

NDC_SQL_FILE=$SQL_PATH/$FILE_BASE"_NDC.sql"
NDC_SQL_PIPE_FILE=$OUTPUT_PATH/$FILE_BASE"_NDC_pipe.lst"
NDC_DATA_FILE_OUTPUT=$OUTPUT_PATH/$FILE_BASE".NDC.data"

PHARM_SQL_FILE=$SQL_PATH/$FILE_BASE"PHARM.sql"
PHARM_SQL_PIPE_FILE=$OUTPUT_PATH/$FILE_BASE"_PHARM_pipe.lst"
PHARM_DATA_FILE_OUTPUT=$OUTPUT_PATH/$FILE_BASE".PHARM.data"

PICO_SQL_FILE=$SQL_PATH/$FILE_BASE"_PICO.sql"
PICO_SQL_PIPE_FILE=$OUTPUT_PATH/$FILE_BASE"_PICO_pipe.lst"
PICO_DATA_FILE_OUTPUT=$OUTPUT_PATH/$FILE_BASE".PICO.data"

NODUP_APC_TRIG=$INPUT_PATH/"GDX_NO_DUPLICATES_IN_APC.trg"

TRIGGER_FILE="$OUTPUT_PATH/KSZ4001J.TRIGGER"

rm -f $LOG_FILE
rm -f $CYCLE_GID_DAT
rm -f $CYCLE_GID_SQL


rm -f $NDC_SQL_FILE
rm -f $NDC_SQL_PIPE_FILE
rm -f $NDC_DATA_FILE_OUTPUT


rm -f $PHARM_SQL_FILE
rm -f $PHARM_SQL_PIPE_FILE
rm -f $PHARM_DATA_FILE_OUTPUT


rm -f $PICO_SQL_FILE
rm -f $PICO_SQL_PIPE_FILE
rm -f $PICO_DATA_FILE_OUTPUT

rm -f ${TRIGGER_FILE}

. `dirname $0`/Common_GDX_APC_Status_update.ksh 140 STRT >> $LOG_FILE


#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
print "Starting the script $SCRIPTNAME ......"                                 >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

#-------------------------------------------------------------------------#
# Check to see if the GDX_NO_DUP_INAP trigger exists.  If so delete       #
#-------------------------------------------------------------------------#
print "Checking if $NODUP_APC_TRIG exists......"                                >> $LOG_FILE
print "***************************************"                                >> $LOG_FILE

if [[ -e $NODUP_APC_TRIG ]];then
    print "Removing the $NODUP_APC_TRIG file" >>$LOG_FILE
    rm -f $NODUP_APC_TRIG
fi

#-------------------------------------------------------------------------#
# Extract the NDC 
#-------------------------------------------------------------------------#
print `date` " =============== Started Extract NDC =========================="          >> $LOG_FILE

#################################################################################
#
# ?.  Set up the SQL and Connect to the Database 
#
#################################################################################

SQL_STRING="SELECT DISTINCT "
SQL_STRING=$SQL_STRING"    NDC_LC11_ID "
SQL_STRING=$SQL_STRING"   ||SUBSTR(coalesce(BRAND_NAME,' '),1,30)  " 
SQL_STRING=$SQL_STRING"   ||substr(coalesce(LBL_NAME,' '),1,20)  "
SQL_STRING=$SQL_STRING" FROM vrap.tdrug_edw "
SQL_STRING=$SQL_STRING" order by NDC_LC11_ID"  
SQL_STRING=$SQL_STRING"   ||SUBSTR(coalesce(BRAND_NAME,' '),1,30)  " 
SQL_STRING=$SQL_STRING"   ||substr(coalesce(LBL_NAME,' '),1,20)  "

print $SQL_STRING  >> $LOG_FILE 
db2 -x $SQL_STRING >> $NDC_DATA_FILE_OUTPUT 

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
{
    print `date` "Error when extracting NDC from GDX."
    tail -20 $NDC_DATA_FILE_OUTPUT
}   >> $LOG_FILE
    exit_error $RETCODE
else
    print `date` "Completed extract of NDC " >> $LOG_FILE
fi   


#-------------------------------------------------------------------------#
# Build Oracle Pharmacy sql file
#-------------------------------------------------------------------------#
print `date` "=======================  Build PHARMACY SQL ======================="    >> $LOG_FILE

#################################################################################
#
# ?.  Set up the SQL and Connect to the Database 
#
#################################################################################

SQL_STRING="SELECT DISTINCT "
SQL_STRING=$SQL_STRING" substr(case when length(rtrim(nabp_id)) = 0 then '000000000' "
SQL_STRING=$SQL_STRING"      when length(rtrim(nabp_id)) = 1 then '00000000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"      when length(rtrim(nabp_id)) = 2 then '0000000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"      when length(rtrim(nabp_id)) = 3 then '000000'||rtrim(nabp_id) "  
SQL_STRING=$SQL_STRING"      when length(rtrim(nabp_id)) = 4 then '00000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"      when length(rtrim(nabp_id)) = 5 then '0000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"      when length(rtrim(nabp_id)) = 6 then '000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"      when length(rtrim(nabp_id)) = 7 then '00'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"      when length(rtrim(nabp_id)) = 8 then '0'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"      when length(rtrim(nabp_id)) = 9 then rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"      else rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"  end  "
SQL_STRING=$SQL_STRING" ||SUBSTR(pharm_nm,1,30),1,39)  "
SQL_STRING=$SQL_STRING" FROM vrap.tpharm "
SQL_STRING=$SQL_STRING" order by  substr(case when length(rtrim(nabp_id)) = 0 then '000000000' "
SQL_STRING=$SQL_STRING"                when length(rtrim(nabp_id)) = 1 then '00000000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"                when length(rtrim(nabp_id)) = 2 then '0000000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"                when length(rtrim(nabp_id)) = 3 then '000000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"                when length(rtrim(nabp_id)) = 4 then '00000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"                when length(rtrim(nabp_id)) = 5 then '0000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"                when length(rtrim(nabp_id)) = 6 then '000'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"                when length(rtrim(nabp_id)) = 7 then '00'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"                when length(rtrim(nabp_id)) = 8 then '0'||rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"                when length(rtrim(nabp_id)) = 9 then rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"                else rtrim(nabp_id) "
SQL_STRING=$SQL_STRING"                end "
SQL_STRING=$SQL_STRING" ||SUBSTR(pharm_nm,1,30),1,39)  "  

print $SQL_STRING  >> $LOG_FILE 
db2 -x $SQL_STRING >> $PHARM_DATA_FILE_OUTPUT 

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
{
    print `date` "Error when extracting Pharmacy from GDX."
    tail -20 $NDC_DATA_FILE_OUTPUT
}   >> $LOG_FILE
    exit_error $RETCODE
else
    print `date` "Completed extract of Pharmacy " >> $LOG_FILE
fi   

#-------------------------------------------------------------------------#
# Build Oracle PICO sql file
#-------------------------------------------------------------------------#
print `date` "======================= Build PICO SQL =========================="      >> $LOG_FILE

#################################################################################
#
# ?.  Set up the SQL and Connect to the Database 
#
#################################################################################

SQL_STRING="select distinct "
SQL_STRING=$SQL_STRING"  substr(a.pico_no "
SQL_STRING=$SQL_STRING" ||substr(b.cd_nmon_txt,1,3)  "
SQL_STRING=$SQL_STRING" ||upper(substr(a.pico_name,1,30)) "
SQL_STRING=$SQL_STRING" ||upper(substr(b.cd_nm,1,25)) "
SQL_STRING=$SQL_STRING" || a.corp_cd, 1,68 ) "
SQL_STRING=$SQL_STRING" from  (select substr(digits(ndc5_nb),2,9) as pico_no "
SQL_STRING=$SQL_STRING"              ,min(vndr_nm) as pico_name "
SQL_STRING=$SQL_STRING"              ,corp_cd as corp_cd "
SQL_STRING=$SQL_STRING"          from vrap.tvndr "
SQL_STRING=$SQL_STRING"         where ndc5_nb > 0  "
SQL_STRING=$SQL_STRING"         group by substr(digits(ndc5_nb),2,9), corp_cd) a "
SQL_STRING=$SQL_STRING"      ,vrap.vvndr_rebt_cd_corp b  "
SQL_STRING=$SQL_STRING" where b.typ_cd = 57  "
SQL_STRING=$SQL_STRING" and a.corp_cd = b.corp_cd  "
SQL_STRING=$SQL_STRING" order by substr(a.pico_no||substr(b.cd_nmon_txt,1,3)||upper(substr(a.pico_name,1,30))||upper(substr(b.cd_nm,1,25))|| a.corp_cd,1,68) "  

print $SQL_STRING  >> $LOG_FILE 
db2 -x $SQL_STRING >> $PICO_DATA_FILE_OUTPUT 

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
{
    print `date` "Error when extracting PICO from GDX."
    tail -20 $NDC_DATA_FILE_OUTPUT
}   >> $LOG_FILE
    exit_error $RETCODE
else
    print `date` "Completed extract of PICO " >> $LOG_FILE
fi   

#-------------------------------------------------------------------------#
# Write Trigger File 
#-------------------------------------------------------------------------#
print "$JOBNAME job" >> ${TRIGGER_FILE}
print "executes ${SCRIPTNAME}" >> ${TRIGGER_FILE}
print "and SFTP the below file" >> ${TRIGGER_FILE}
print "to MVS thru Webtransport" >> ${TRIGGER_FILE}
print "${TRIGGER_FILE}" >> ${TRIGGER_FILE}


#-------------------------------------------------------------------------#
# SFTP the Trigger file to MVS via Webtransport server  
#-------------------------------------------------------------------------#

if [[ $RETCODE = 0 ]]; then

print "===================== Call Common SFTP script =================="        >> $LOG_FILE

print "Starting the SFTP Trigger file to Webtransport Server"                   >> $LOG_FILE
print `date +"%D %r %Z"`                                                        >> $LOG_FILE

Common_SFTP_Process.ksh -p $SCRIPTNAME					

RETCODE=$?

if [[ $RETCODE == 0 ]]; then

	print "Completed the SFTP"                                              >> $LOG_FILE
	print `date +"%D %r %Z"`                                                >> $LOG_FILE
  else 
	print "Error SFTP the trigger file to webtransport" $RETCODE		>> $LOG_FILE
	exit $RETCODE
  fi

fi

. `dirname $0`/Common_GDX_APC_Status_update.ksh 140 END                         >> $LOG_FILE

#-------------------------------------------------------------------------#
# Script completed
#-------------------------------------------------------------------------#
{
    print
    print
    print "....Completed executing $SCRIPTNAME ...."
    date +"%D %r %Z"

} >> $LOG_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
exit $RETCODE
