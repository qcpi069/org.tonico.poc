#!/usr/bin/ksh

#############################################################################
#SCRIPT NAME : DFO_preprocessing_cleanup.ksh                                #
#                                                                           #
#PURPOSE     : To remove the temporary directory created after the          #
#              last run of the main DFO processing for a particular client  #
#              and to set the runstatus for the given client to "blank".    #
#									    #
#INSTRUCTIONS: This script takes one command line argument, CLIENT_NAME.    #
#              This script also uses some exports from the DFO profile      #
#              so if that is changed, the script should be changed as well. # 
#              The script will email the addresses specified by the 	    #
#              internal variable SUPPORT_MAIL_LIST_FILE with any errors.    #
#              This script is scheduled to run on the 1st of each month     #
#              through the crontab.					    #
#                                                                           #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
# 6013450       qcpi733       07/13/06   removed checks on the runstatus
#                                        file for easier restartability.
#  1.0        Peter Miller   09/05/2003  Initial Release                    #
#                                                                           #
#############################################################################

#EXPORTS AND VARS#
export HOME_DIR="/GDX/prod"
export SCRIPT_DIR="$HOME_DIR/script"
export REF_DIR="$HOME_DIR/control/reffile"
export SUPPORT_MAIL_LIST_FILE="$REF_DIR/DFO_support_maillist.ref"
export MAILFILE="/GDX/prod/error_mail_body"
touch $MAILFILE
CLIENT_NAME=$1
CLIENT_DIR="${HOME_DIR}/clients/${CLIENT_NAME}"
SCRIPT_NAME="DFO_preprocessing_cleanup.ksh"

echo "CLIENT_NAME passed as $CLIENT_NAME"
echo "CLIENT_DIR is $CLIENT_DIR"

#check if CLIENT_NAME parameter was passed
if [[ $1 = '' ]]
 then
  echo "CLIENT_NAME was not passed"
  echo "Script: $SCRIPT_NAME"                   \
       "\nProcessing for $CLIENT_NAME"                 \
       "CLIENT_NAME was not passed" > $MAILFILE
  export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
  $SCRIPT_DIR/mailto_IS_group.ksh
  exit 1
fi

#make sure CLIENT_DIR is a directory
if [[ ! -d $CLIENT_DIR ]]
   then
    echo "$CLIENT_DIR is a not a directory"
    echo "Script: $SCRIPT_NAME"                   \
         "\nProcessing for $CLIENT_NAME"                 \
         "\nError: $CLIENT_DIR is a not a directory" > $MAILFILE
    export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
    $SCRIPT_DIR/mailto_IS_group.ksh
  exit 1
else
  echo "$CLIENT_DIR is a directory"
fi

#make sure that last_temp_dir exists
if [[ -e ${CLIENT_DIR}/last_temp_dir ]]
  then
   echo "${CLIENT_DIR}/last_temp_dir is a file"
else
  echo "${CLIENT_DIR}/last_temp_dir not found"
  echo "Script: $SCRIPT_NAME"                   \
       "\nProcessing for $CLIENT_NAME"                 \
       "\nError: ${CLIENT_DIR}/last_temp_dir not found" > $MAILFILE
  export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
  $SCRIPT_DIR/mailto_IS_group.ksh
  exit 1
fi

#read the top line (ie directory to delete) from last_temp_dir
read delete_dir < ${CLIENT_DIR}/last_temp_dir

#make sure that last_temp_dir file contained a non-null entry
if [[ $delete_dir = "" ]]
  then
   echo "No directory specified for deletion in ${CLIENT_DIR}/last_temp_dir"
   echo "Script: $SCRIPT_NAME"                   \
        "\nProcessing for $CLIENT_NAME"                 \
        "\nError: No directory specified for deletion in ${CLIENT_DIR}/last_temp_dir" > $MAILFILE
   export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
   $SCRIPT_DIR/mailto_IS_group.ksh
  exit 1
fi    

#check to see if the specified directory exists
if [[ ! -d $delete_dir ]] 
  then
   echo "$delete_dir not found"
   echo "Script: $SCRIPT_NAME"                   \
        "\nProcessing for $CLIENT_NAME"                 \
        "\nError: Directory $delete_dir does not exist" > $MAILFILE
   export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
   $SCRIPT_DIR/mailto_IS_group.ksh
  exit 1
fi

echo "$delete_dir found and ready for deletion"

#delete the specified directory
rm -r $delete_dir
if [[ $? != 0 ]]
 then
   echo "$delete_dir could not be deleted. error code $? returned by rm."
   echo "Script: $SCRIPT_NAME"                   \
        "\nProcessing for $CLIENT_NAME"                 \
        "\nError: $delete_dir could not be deleted."    \
        " error code $? returned by rm." > $MAILFILE
   export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
   $SCRIPT_DIR/mailto_IS_group.ksh
  exit 1
fi

echo "$delete_dir and contents deleted"

