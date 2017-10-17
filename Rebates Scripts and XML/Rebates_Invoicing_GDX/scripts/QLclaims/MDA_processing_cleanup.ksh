#!/usr/bin/ksh

#############################################################################
#SCRIPT NAME : MDA_processing_cleanup.ksh                                   #
#                                                                           #
#PURPOSE     : To remove the temporary directory created after the          #
#              last run of the main MDA processing for a particular client  #
#              and to set the runstatus for the given RUN_MODE to "blank".  #
#									    #
#INSTRUCTIONS: This script takes two command line arguments, RUN_MODE and   #
#              DELETE_TEMP_DIR_FLAG (optional).                             #
#              This script also uses some exports from the MDA profile      #
#              so if that is changed, the script should be changed as well. # 
#              The script will email the addresses specified by the 	    #
#              internal variable SUPPORT_MAIL_LIST_FILE with any errors.    #
#              This script is scheduled to run on the Saturdays for weekly  #
#              clean up and on the 19th for monthly run.                    #
#                                                                           #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        William Price  05/15/2004  Initial Release                    #
#                                                                           #
#############################################################################

#EXPORTS AND VARS#
export HOME_DIR="/GDX/prod"
export SCRIPT_DIR="$HOME_DIR/script"
export REF_DIR="$HOME_DIR/control/reffile"
export SUPPORT_MAIL_LIST_FILE="$REF_DIR/MDA_support_maillist.ref"
export MAILFILE="/GDX/prod/error_mail_body"
touch $MAILFILE
DELETE_TEMP_DIR_FLAG=$2
SCRIPT_NAME="MDA_processing_cleanup.ksh"
#================================================
#ACCEPTS ONE COMMAND LINE PARAMETER.
#================================================

  if [[ $# -lt 1 ]] then
     echo "Usage MDA_process_cleanup.ksh <RUN MODE> <optional DELETE_FLAG>"
     exit 1
  else
     export RUN_MODE=`echo $1 | tr '[A-Z]' '[a-z]'`

     case ${RUN_MODE} in
     
         'w'         )
             echo "MDA Weekly claims clean up processing BEGINS - `date +'%b %d, %Y %H:%M:%S'`......." 
             RUN_MODE="weekly";;

         'm'         )
             echo "MDA Monthly claims clean up processing BEGINS - `date +'%b %d, %Y %H:%M:%S'`......." 
             RUN_MODE="monthly";;

      esac

  fi

  echo "parameter run mode : " ${RUN_MODE}  >> $LOG_FILE

CLAIMS_DIR="${HOME_DIR}/${RUN_MODE}"

echo "RUN MODE passed is $RUN_MODE"
echo "CLAIMS RUN_MODE DIR is $CLAIMS_DIR"

#make sure CLAIMS_DIR is a directory
if [[ ! -d $CLAIMS_DIR ]]
   then
    echo "$CLAIMS_DIR is a not a directory"
    echo "Script: $SCRIPT_NAME"                       \
         "\nProcessing for $RUN_MODE claims intake"   \
         "\nError: $CLAIMS_DIR is a not a directory" > $MAILFILE
    export MAIL_SUBJECT="MDA: $SCRIPT_NAME ERROR"
    $SCRIPT_DIR/mailto_IS_group.ksh
    exit
else
  echo "$CLAIMS_DIR is a directory"
fi

#check to see if CLAIMS_DIR/runstatus exists, if so set to "blank"
if [[ -e ${CLAIMS_DIR}/runstatus ]]
  then
   print "blank" > ${CLAIMS_DIR}/runstatus;
   echo "${CLAIMS_DIR}/runstatus set to 'blank'"
else
  echo "${CLAIMS_DIR}/runstatus not found"
  echo "Script: $SCRIPT_NAME"                   \
       "\nProcessing for $RUN_MODE"                 \
        "\nError: ${CLAIMS_DIR}/runstatus not found" > $MAILFILE
  export MAIL_SUBJECT="MDA: $SCRIPT_NAME ERROR"
  $SCRIPT_DIR/mailto_IS_group.ksh
  exit
fi

# If anything was in the delete flag, we'll eliminate the
# temp dir indicated in the {CLAIMS_DIR}/last_temp_dir file
if [[ $DELETE_TEMP_DIR_FLAG = "" ]]
   then
    echo "DELETE_TEMP_DIR_FLAG was not passed"
    echo "no deleting took place."
    exit 34
fi

#make sure that last_temp_dir exists
if [[ -e ${CLAIMS_DIR}/last_temp_dir ]]
  then
   echo "${CLAIMS_DIR}/last_temp_dir is a file"
else
  echo "${CLAIMS_DIR}/last_temp_dir not found"
  echo "Script: $SCRIPT_NAME"                   \
       "\nProcessing for $RUN_MODE"                 \
       "\nError: ${CLAIMS_DIR}/last_temp_dir not found" > $MAILFILE
  export MAIL_SUBJECT="MDA: $SCRIPT_NAME ERROR"
  $SCRIPT_DIR/mailto_IS_group.ksh
  exit
fi

#read the top line (ie directory to delete) from last_temp_dir
read delete_dir < ${CLAIMS_DIR}/last_temp_dir

#make sure that last_temp_dir file contained a non-null entry
if [[ $delete_dir = "" ]]
  then
   echo "No directory specified for deletion in ${CLAIMS_DIR}/last_temp_dir"
   echo "Script: $SCRIPT_NAME"                   \
        "\nProcessing for $RUN_MODE"                 \
        "\nError: No directory specified for deletion in ${CLAIMS_DIR}/last_temp_dir" > $MAILFILE
   export MAIL_SUBJECT="MDA: $SCRIPT_NAME ERROR"
   $SCRIPT_DIR/mailto_IS_group.ksh
   exit
fi    

#check to see if the specified directory exists
if [[ ! -d $delete_dir ]] 
  then
   echo "$delete_dir not found"
   echo "Script: $SCRIPT_NAME"                   \
        "\nProcessing for $RUN_MODE"                 \
        "\nError: Directory $delete_dir does not exist" > $MAILFILE
   export MAIL_SUBJECT="MDA: $SCRIPT_NAME ERROR"

###  not 'really' an error... we wanted it gone anyways
###   $SCRIPT_DIR/mailto_IS_group.ksh
   exit
fi

echo "$delete_dir found and ready for deletion"

#delete the specified directory
rm -r $delete_dir
if [[ $? != 0 ]]
 then
   echo "$delete_dir could not be deleted. error code $? returned by rm."
   echo "Script: $SCRIPT_NAME"                   \
        "\nProcessing for $RUN_MODE"                 \
        "\nError: $delete_dir could not be deleted."    \
        " error code $? returned by rm." > $MAILFILE
   export MAIL_SUBJECT="MDA: $SCRIPT_NAME ERROR"
   $SCRIPT_DIR/mailto_IS_group.ksh
   exit
fi

echo "$delete_dir and contents deleted"

