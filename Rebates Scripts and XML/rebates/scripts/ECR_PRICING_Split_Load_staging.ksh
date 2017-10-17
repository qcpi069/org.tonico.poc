#!/bin/ksh

#-----------------------------------------------------------------------------------------------------------------------#
# Script						: ECR_PRICING_Split_Load_staging.ksh at location $REBATES_HOME/scripts
#
# Parameters				: -w Workflow Name, -f File name 
#
# Output						: 1. Load Staging Tables from new or existing file. 
# 									: 2. Insert Record in Audit table for Process 
#
# Process						: 1. Input parameter contain null file name then process new file from input location if available
# 									: 2. Input parameter contain valid not null file name then process existing file from source location.
#
# Hardcode Values		: EMAIL_SUBJECT, V_T_AUDIT,V_DB_SCHEMA, V_SEQ_AUDT_NEXT, V_F_TEMP_MSG, rebatereg@cvscaremark
#
# Date          User ID          Description
# ------------  ---------------  ----------------------------
# 12-14-2015    QCPU845          Initial Script.
# 02-19-2016    QCPU845          Change search new file pattern from "mvp_rbat_pricing*" to "*rbat_pricing*"
#
#-------------------------------------------------------------------------------------------------------------------------#

#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Caremark Rebates Environment variables
. `dirname $0`/Common_RCI_Environment.ksh 
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Function to exit the script
function FUN_EXIT_SCRIPT
{
	RETCODE=$1
	ERROR=$2
	if [[ $RETCODE == 1 ]]
	then
		#-----------------------------------Failed Script without Email
		{
			echo "\n\n"" !!! Aborting!!! ""\n"
			echo "Return_code =  $RETCODE"
			echo "Error_Reason =  $ERROR""\n"
			echo "*----------Ending script $SCRIPTNAME `date`----------*""\n"
		}                                                                                                        >> $LOG_FILE
	fi
	
	if [[ $RETCODE == 2 ]]
	then
		#-----------------------------------Failed Script with Email
		{
			echo "\n\n"" !!! Aborting!!! ""\n"
			echo "Return_code =  $RETCODE"
			echo "Error_Reason =  $ERROR""\n"
			echo "*----------Ending script $SCRIPTNAME `date`----------*""\n"
		}                                                                                                        >> $LOG_FILE
		#-----------------------------------Send Email
		EMAIL_SUBJECT="FAILURE: $wf_nm - "$REGION" due to $ERROR"
		V_TO_MAIL=$TO_MAIL,gdxdevtest@cvscaremark.com
		#-----------------------------------Add Business email for new file process in production environment.
		if [[ $REGION == "PROD" && $file_nm == "" ]]
		then
			V_TO_MAIL=$TO_MAIL,rebatereg@cvscaremark.com
		fi
		#-----------------------------------Check if error message needs to be CCed (when email ID is passed)
		if [[ $CC_EMAIL_LIST = '' ]] 
		then
			mailx -s "$EMAIL_SUBJECT" $V_TO_MAIL                                                                    < $LOG_FILE
		else
			mailx -s "$EMAIL_SUBJECT" -c $CC_EMAIL_LIST $V_TO_MAIL                                                  < $LOG_FILE
		fi
	fi
	
	if [[ $RETCODE == 0 ]]
	then
		#-----------------------------------Succeed Script without Email
		{
			echo "\n"".... $SCRIPTNAME  completed with return code $RETCODE ....""\n"
			echo "*----------Ending script $SCRIPTNAME `date`----------*""\n"
			}                                                                                                      >> $LOG_FILE
		mv $LOG_FILE $LOG_FILE_ARCH
	fi
	exit $RETCODE
}
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Function To Load data in table
function FUN_LOAD_TBL
{
	f_file=$1
	t_tbl=$2
	print " ------Start $t_tbl Load"                                                                           >> $LOG_FILE
	print " -------Detail"                                                                                     >> $LOG_FILE
	db2 import from $f_file of del modified by coldel'|' keepblanks messages $LOG_FILE REPLACE INTO $V_DB_SCHEMA.$t_tbl > $V_F_TEMP_MSG
	RC=$((RC+$?))
	if [[ $RC != 0 ]]
	then
		#-----------------------------------update audit table as Failed
		db2 "update $V_T_AUDIT 
		SET "FILE_LOAD_STAT_TXT"='2', "STAGE_LOAD_STAT_TXT"='2', "UPDT_TS"=SYSDATE 
		WHERE 
		"CR_AUDT_PRC_ID"= '${Seq_val}' ";                                                                        >> $LOG_FILE
		db2 "commit";                                                                                            >> $LOG_FILE
		db2 -stvx connect reset                                                                                  >> $LOG_FILE
		db2 -stvx quit                                                                                           >> $LOG_FILE
		print " -------Summary"                                                                                  >> $LOG_FILE
		cat $V_F_TEMP_MSG                                                                                        >> $LOG_FILE
		FUN_EXIT_SCRIPT 2 "Error in Loading $t_tbl Table"
	fi
	print " -------Summary"                                                                                    >> $LOG_FILE
	cat $V_F_TEMP_MSG                                                                                          >> $LOG_FILE
}
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Set Variables1
SCRIPTNAME=$(basename "$0")
SCRIPTS_DIR=$(dirname "$0")
LOG_FILE_ARCH=${ARCH_LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"

#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Start Script Log
echo "\n""*----------Starting script execution  $SCRIPTNAME `date`----------*""\n"                           >> $LOG_FILE
file_nm=""
wf_nm=""
RC=0
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Get Parameters
while getopts f:w: opt
	do
		case $opt in
			w)
				wf_nm=$OPTARG
				;;
			f)
				file_nm=$OPTARG
				;;
			*)
				FUN_EXIT_SCRIPT 2 "Incorrect arguments passed - $opt "
				;;
		esac
	done
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Set Variables2
V_DIR_SRC_INPUT=$REBATES_HOME/input/ECRstage
V_DIR_SRC=$REBATES_HOME/SrcFiles
V_DIR_ARK=$REBATES_HOME/SrcFiles/archive

V_F_MSTR=$V_DIR_SRC/F_CRT_PRC_MSTR.txt
V_F_RULE=$V_DIR_SRC/F_CRT_PRC_RULE.txt
V_F_POOL=$V_DIR_SRC/F_CRT_PRC_POOL.txt
V_F_TERA=$V_DIR_SRC/F_CRT_PRC_TERM_ADV_PMT.txt
V_F_TERG=$V_DIR_SRC/F_CRT_PRC_TERM_GUAR.txt
V_F_TERS=$V_DIR_SRC/F_CRT_PRC_TERM_SHR.txt
V_F_TIER=$V_DIR_SRC/F_CRT_PRC_TIER.txt

V_F_TEMP_MSG=$V_DIR_SRC/rbat_msg_pricing_load_msg.txt
V_DB_SCHEMA=CLIENT_REG
V_T_AUDIT=$V_DB_SCHEMA.CRT_AUDT_PRC_LOAD
V_SEQ_AUDT_NEXT=$V_DB_SCHEMA.AUDT_CRT_PRC_ID_SEQ.NEXTVAL

print " -Source File Input Location: $V_DIR_SRC_INPUT"                                                       >> $LOG_FILE
print " -Source File Process Location: $V_DIR_SRC"                                                           >> $LOG_FILE
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Get file need to process
if [[ $file_nm == "" ]]
then
	#-----------------------------------For new file check
	print " --Checking New File"                                                                               >> $LOG_FILE
	#-----------------------------------Input Directory Check
	if [ ! -d $V_DIR_SRC_INPUT ]
	then
		FUN_EXIT_SCRIPT 2 "$V_DIR_SRC_INPUT Directory is not available "
	fi
	#-----------------------------------Count total file available at input location for same format
	typeset -i V_SRC_FILE_CNT=$(ls $V_DIR_SRC_INPUT/*rbat_pricing* | wc -l)
	print " ---Number of files available: $V_SRC_FILE_CNT"                                                     >> $LOG_FILE
	#-----------------------------------Check total file available to process
	if [ "$V_SRC_FILE_CNT" == 0 ]
	then
		FUN_EXIT_SCRIPT 1 "!!File is not available to process"
	fi
	#-----------------------------------Get first file if multiple available
	V_SRC_FILE_TO_PROCESS=$(basename "$(ls -rt $V_DIR_SRC_INPUT/*rbat_pricing* | head -1)")
	print " ---File need to Move: $V_SRC_FILE_TO_PROCESS"                                                      >> $LOG_FILE
	#-----------------------------------Move file from input directory to source directory to process.
	mv $V_DIR_SRC_INPUT/$V_SRC_FILE_TO_PROCESS $V_DIR_SRC/$V_SRC_FILE_TO_PROCESS
	print " ---File need to Process: $V_SRC_FILE_TO_PROCESS"                                                   >> $LOG_FILE
else
	#-----------------------------------For existing file check
	print " --Checking for existing file"                                                                      >> $LOG_FILE
	print " ---File name: $file_nm.txt"                                                                        >> $LOG_FILE
	#-----------------------------------Source Directory Check
	if [ ! -d $V_DIR_SRC ]
	then
		FUN_EXIT_SCRIPT 2 "$V_DIR_SRC Directory is not available "
	fi
	if [ ! -s $V_DIR_SRC/$file_nm.txt ]
	then
		FUN_EXIT_SCRIPT 2 "!!File is not available at source location to process"
	fi
	V_SRC_FILE_TO_PROCESS=$file_nm.txt
	print " ---File need to Process: $V_SRC_FILE_TO_PROCESS"                                                   >> $LOG_FILE
fi
chmod g+w $V_DIR_SRC/$V_SRC_FILE_TO_PROCESS
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Convert dos2unix
awk '{ sub("\r$", ""); print }' $V_DIR_SRC/$V_SRC_FILE_TO_PROCESS > $V_DIR_SRC/temp_rbat_temp_pricing_temp.txt
mv $V_DIR_SRC/temp_rbat_temp_pricing_temp.txt $V_DIR_SRC/$V_SRC_FILE_TO_PROCESS
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Empty Temp Files
> $V_F_MSTR > $V_F_RULE > $V_F_POOL > $V_F_TERA > $V_F_TERG > $V_F_TERS > $V_F_TIER
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Read source file and split in multiple Temp Files
print " --Start split files"`date +"%D %r %Z"`                                                               >> $LOG_FILE
typeset -L2 V_REC_TYP
typeset -i V_LINE_NUM=0
while IFS= read mLine
do
	V_REC_TYP=$mLine
	V_LINE_NUM=$((V_LINE_NUM+1))
	case $V_REC_TYP in
       'H|')
         #------------------------------Get file name from header in file
         V_FILE_NM_HEADER=$(echo $mLine|cut -c3-)
         ;;
       01)
         echo "$mLine"|cut -c4-                                                                              >> $V_F_MSTR
         ;;
       02)
         echo "$mLine"|cut -c4-                                                                              >> $V_F_RULE
         ;;
       03)
         echo "$mLine"|cut -c4-                                                                              >> $V_F_POOL
         ;;
       04)
         echo "$mLine"|cut -c4-                                                                              >> $V_F_TERA
         ;;
       05)
         echo "$mLine"|cut -c4-                                                                              >> $V_F_TERG
         ;;
       06)
         echo "$mLine"|cut -c4-                                                                              >> $V_F_TERS
         ;;
       07)
         echo "$mLine"|cut -c4-                                                                              >> $V_F_TIER
         ;;
       *) 
         ER_MS="Incorrect arguments '"'$V_REC_TYP'"' passed at Line Number = $V_LINE_NUM"
         FUN_EXIT_SCRIPT 2 "$ER_MS"
         ;;
	esac
done < "$V_DIR_SRC/$V_SRC_FILE_TO_PROCESS"
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Check File name match with header record
#print " --V_SRC_FILE_TO_PROCESS=$V_SRC_FILE_TO_PROCESS"                                                   >> $LOG_FILE
#print " --V_FILE_NM_HEADER=$V_FILE_NM_HEADER"                                                    >> $LOG_FILE
if [[ $V_SRC_FILE_TO_PROCESS != $V_FILE_NM_HEADER.txt ]]
then
        mv $V_DIR_SRC/$V_SRC_FILE_TO_PROCESS $V_DIR_ARK/$V_SRC_FILE_TO_PROCESS
	FUN_EXIT_SCRIPT 2 "File name not match with File header name"
fi
print " --Start Staging Tables Loading"`date +"%D %r %Z"`                                                    >> $LOG_FILE
##-------------------------------------------------------------------------------------------------------------------------#
##---------------------------------------Connect DB
print " ---Connect DB "`date +"%D %r %Z"`                                                                    >> $LOG_FILE
db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"                                            >> $LOG_FILE
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Check for Connecting Error
if [[ $? != 0 ]]
then
	FUN_EXIT_SCRIPT 2 "aborting script - cant connect to udb "
fi
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Get Next sequence value
Seq_val=$(db2 -x "select $V_SEQ_AUDT_NEXT from SYSIBM.SYSDUMMY1")                                            >> $LOG_FILE
#---------------------------------------Check Audit Table ID is valid and not Greter thatn sequence new value
typeset -i invalid_rec=$(db2 -x "select count(*) from $V_T_AUDIT where CR_AUDT_PRC_ID>$Seq_val")
if [[ $invalid_rec != 0 ]]
then
	FUN_EXIT_SCRIPT 2 "Audit Table ID is greter than sequence value"
fi
#---------------------------------------Insert new record in Audit table
print " ----Insert into Audit Table in DB "`date +"%D %r %Z"`                                                >> $LOG_FILE
db2 "insert into $V_T_AUDIT 
("CR_AUDT_PRC_ID", "INPUT_FILE_NM", "FILE_LOAD_STAT_TXT", "STAGE_LOAD_STAT_TXT", "INSRT_TS", "INSRT_USER_ID", "UPDT_TS", "UPDT_USER_ID") 
values 
('${Seq_val}', '${V_FILE_NM_HEADER}', '3', '3', sysdate, 'INFA', sysdate, 'INFA') ";                         >> $LOG_FILE
db2 "commit";                                                                                                >> $LOG_FILE
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Load Staging Tables from files
print " -----Insert Staging DB "`date +"%D %r %Z"`                                                           >> $LOG_FILE
FUN_LOAD_TBL $V_F_MSTR 'CRT_STAGE_PRC_MSTR'
FUN_LOAD_TBL $V_F_RULE 'CRT_STAGE_PRC_RULE'
FUN_LOAD_TBL $V_F_POOL 'CRT_STAGE_PRC_POOL'
FUN_LOAD_TBL $V_F_TERA 'CRT_STAGE_PRC_TERM_ADV_PMT'
FUN_LOAD_TBL $V_F_TERG 'CRT_STAGE_PRC_TERM_GUAR'
FUN_LOAD_TBL $V_F_TERS 'CRT_STAGE_PRC_TERM_SHR'
FUN_LOAD_TBL $V_F_TIER 'CRT_STAGE_PRC_TIER'
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------update audit table as succeeded
db2 "update $V_T_AUDIT 
SET 
"STAGE_LOAD_STAT_TXT"='1',"PRFL_STAT_TXT"='3', "UPDT_TS"=SYSDATE 
WHERE 
"CR_AUDT_PRC_ID"= '${Seq_val}' ";                                                                            >> $LOG_FILE
db2 "commit";                                                                                                >> $LOG_FILE
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Reset and quit connection
db2 -stvx connect reset                                                                                      >> $LOG_FILE
db2 -stvx quit                                                                                               >> $LOG_FILE
print " --End Staging Tables Loading"`date +"%D %r %Z"`                                                      >> $LOG_FILE
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Reset Error File at Target Location
> $REBATES_HOME/TgtFiles/"ERR_$V_FILE_NM_HEADER.txt"
chmod g+w $REBATES_HOME/TgtFiles/"ERR_$V_FILE_NM_HEADER.txt"
#-------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------Defoult Exit
FUN_EXIT_SCRIPT 0 "Complete"
