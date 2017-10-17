#!/bin/ksh

#-----------------------------------------------------------------------------------------------------------------------#
# Script						: ECR_SAP_detail_to_trailer_balance.ksh at location $REBATES_HOME/scripts
#
# Parameters				:-d Source File Directory						i.e. Full path with informatica parameters i.e. $PMSourceFileDir/
#										 -f filename												i.e. File Name with extention i.e. rpsdm_customer.txt
#										 -w Workflow name										i.e. $PMWorkflowName 
#										 -s Session name										i.e. s_m_TruncLoad_SAP_CUST_MSTR
#										 -F Informatica folder name					i.e. $PMFolderName
#
# Output						: Create Parameter file   i.e. $REBATES_HOME/SrcFiles/ParmFiles/ECR_SAP_parameters.txt
#
# Hardcode Values		: PARA_FILE=$REBATES_HOME/SrcFiles/ParmFiles/ECR_SAP_parameters.txt
#
# Date          User ID          Description
# ------------  ---------------  ----------------------------
# 09-03-2015    qcpu845          Initial Creation
# 09-09-2015		qcpu845					 Small changes after 1st code review.
#																	1.check parameter passed correct, 
#																	2.defoult RETCODE to 1, 
#																	3.infworkfolder value passed as parameters insted of hardcode
#
#-------------------------------------------------------------------------------------------------------------------------#

#-------------------------------------------------------------------------------------------------------------------------#
#                              Caremark Rebates Environment variables
#-------------------------------------------------------------------------------------------------------------------------#

 . `dirname $0`/Common_RCI_Environment.ksh

#-------------------------------------------------------------------------------------------------------------------------#
#                                       Function to exit the script
#-------------------------------------------------------------------------------------------------------------------------#

function exit_script {

   RETCODE=$1
   ERROR=$2

   if [[ $RETCODE != 0 ]];then
               {
               print " "
               print $ERROR
               print " "
               print " !!! Aborting!!!"
               print " "
               print "return_code = " $RETCODE
               print " "
               print "*******************************************************"
               print "End of Script $SCRIPTNAME   with return code $RETCODE "
               print `date +"%D %r %Z"`
               print "*******************************************************"
               print " "
               }                                                               >> $LOG_FILE
               EMAIL_SUBJECT="$wf_nm failed in "$REGION" due to out of balance condition"
               # Check if error message needs to be CCed (when email ID is passed)
               if [[ $CC_EMAIL_LIST = '' ]] 
               then
                     mailx -s "$EMAIL_SUBJECT" $TO_MAIL                         < $LOG_FILE
               else 
                     mailx -s "$EMAIL_SUBJECT" -c $CC_EMAIL_LIST $TO_MAIL       < $LOG_FILE
               fi 
   else
               {
               print " "
               print "*******************************************************"
               print "End of Script $SCRIPTNAME   with return code $RETCODE "
               print `date +"%D %r %Z"`
               print "*******************************************************"
               print " "
               }                                                               >> $LOG_FILE
               mv $LOG_FILE $LOG_FILE_ARCH
    fi

   exit $RETCODE
}

#-------------------------------------------------------------------------------------------------------------------------#
#                                          Main Script Start
#-------------------------------------------------------------------------------------------------------------------------#

# Set Variables
RETCODE=1
SCRIPTNAME=$(basename "$0")
infworkfolder=" "
dir_nm=" "
file_nm=" "
wf_nm=" "
sess_nm=" "
chk=" "

while getopts d:f:w:s:F: opt
 do
  case $opt in
       w)
         wf_nm=$OPTARG
         ;;
       d)
         dir_nm=$OPTARG
         ;;
       f)
         file_nm=$OPTARG
         ;;
       s)
         sess_nm=$OPTARG
         ;;
       F)
         infworkfolder=$OPTARG
         ;;
       *) 
         exit_script $RETCODE "Incorrect arguments passed"
         ;;
  esac
 done




# Set file path and names
LOG_FILE_ARCH=${ARCH_LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')"_$file_nm.log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')"_$file_nm.log"
PARA_FILE=$REBATES_HOME/SrcFiles/ParmFiles/ECR_SAP_parameters.txt


# Starting the script and log the starting time.
print " "                                                                       >> $LOG_FILE
print "********************************************"                            >> $LOG_FILE
print "Starting the script $SCRIPTNAME "                                        >> $LOG_FILE
print `date +"%D %r %Z"`                                                        >> $LOG_FILE
print "********************************************"                            >> $LOG_FILE
print " "                                                                       >> $LOG_FILE
print "Archive log file name              : $LOG_FILE_ARCH"                     >> $LOG_FILE
print "Log file name                      : $LOG_FILE"                          >> $LOG_FILE
print "Informatica folder name            : $infworkfolder"                     >> $LOG_FILE
print "Workflow name                      : $wf_nm"                             >> $LOG_FILE
print "Session name                       : $sess_nm"                           >> $LOG_FILE
print "Source file Directory              : $dir_nm"                            >> $LOG_FILE
print "Source file name                   : $file_nm"                           >> $LOG_FILE


#-------------------------------------------------------------------------------------------------------------------------#
#                                      Check parameter received valid or not
#-------------------------------------------------------------------------------------------------------------------------#

if [[ $wf_nm == " " ]]
then
    exit_script $RETCODE "Workflow name is reqiured! see usage: $SCRIPTNAME -w"
fi

if [[ "$dir_nm" != '/'* ]] 
then 
    exit_script $RETCODE "Source file Directory is not Valid"
fi

if [[ $file_nm == " " ]]
then
    exit_script $RETCODE "Source file name is reqiured! see usage: $SCRIPTNAME -f"
fi

if [[ $sess_nm == " " ]]
then
    exit_script $RETCODE "Session name is reqiured! see usage: $SCRIPTNAME -s"
fi

if [[ $infworkfolder == " " ]]
then
    exit_script $RETCODE "Informatica folder name is reqiured! see usage: $SCRIPTNAME -F"
fi

sourcefile=$dir_nm/$file_nm

if [[ ! -e $sourcefile ]]
then
 exit_script $RETCODE "$sourcefile : This Source file is not available" 
fi

print "Source file name with path         : $sourcefile"                        >> $LOG_FILE

#------------------------------------------Source File check ------------------------------------------------#

# Get Total Line count
typeset -i rcnt=$(wc -l $sourcefile | cut -b -8)
print "Source file total line count is    : $rcnt"                              >> $LOG_FILE

rcnt=$((rcnt-1))
print "Source file detail record count is : $rcnt"                              >> $LOG_FILE

if [ $rcnt -lt 1 ]
then
	exit_script $RETCODE "Source file not contain data"
fi

#get file line count value from last line
typeset -i tcnt=$(tail -1 $sourcefile | cut -b 2-10)
print "Source file trailer value          : $tcnt"                              >> $LOG_FILE

#compare both value to get final result
typeset -i result=$tcnt-$rcnt
print "Compare difference is              : $result"                            >> $LOG_FILE

if [ $result == 0 ]
then
 print " "                                                                      >> $LOG_FILE
 print "Result is expected................"                                     >> $LOG_FILE
 print "Start Writing Parameter file      : $PARA_FILE"                         >> $LOG_FILE
 touch $PARA_FILE
 > $PARA_FILE
 echo '###########'create time    `date +"%D %r %Z"`'#############'         >> $PARA_FILE
 echo "[$infworkfolder.WF:$wf_nm.ST:$sess_nm]"                              >> $PARA_FILE
 echo '$$'"WF_REC_CNT=$tcnt"                                                >> $PARA_FILE
 echo '$$'"WF_ROW_CNT=$rcnt"                                                >> $PARA_FILE
 echo '$$'"TABLE_NM="                                                       >> $PARA_FILE
 print "Done Writing Parameter file       : $PARA_FILE"                         >> $LOG_FILE 
else
 print " "                                                                      >> $LOG_FILE
 print "Result is not expected .........."                                      >> $LOG_FILE
 exit_script $RETCODE "Source File is not Balanced"
fi

exit_script 0 "Complete"
