#!/usr/bin/ksh

#############################################################################
#SCRIPT NAME : DFO_clt_deadline_chk.ksh                                     #
#                                                                           #
#PURPOSE     : To see if the monthly processing has run or is running       #
#              for a given client and notify the client and IS if it is not.#
#             								    #
#									    #
#INSTRUCTIONS: This script takes one command line argument, CLIENT_NAME.    #
#              This script also uses some exports from the DFO profile      #
#              so if that is changed, the script should be changed as well. # 
#              The script will email the addresses specified by the 	    #
#              internal variable SUPPORT_MAIL_LIST_FILE with any errors.    #
#              Client will be notified that they are past deadline          #
#              through the script mailto_CLIENT_group.ksh.                  #
#	       If client is past deadline, the client's runstatus will      #
#              be changed to 'past deadline'.                               #
#              This script is scheduled to run on the 8th of each month     #
#              for PHARMASSESS and 2nd of each month for FIRSTHEALTH        #
#              through the crontab.					    #
#                                                                           #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        Peter Miller   09/05/2003  Initial Release                    #
#                                                                           #
#############################################################################

#EXPORTS AND VARS#
export HOME_DIR="/vradfo/prod"
export SCRIPT_DIR="$HOME_DIR/script"
export REF_DIR="$HOME_DIR/control/reffile"
export SUPPORT_MAIL_LIST_FILE="$REF_DIR/DFO_support_maillist.ref"
export MAILFILE="/vradfo/test/error_mail_body"
touch $MAILFILE
CLIENT_NAME=$1
CLIENT_DIR="${HOME_DIR}/clients/${CLIENT_NAME}"
SCRIPT_NAME="DFO_clt_deadline_chk.ksh"

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
  exit
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
    exit
else
  echo "$CLIENT_DIR is a directory"
fi

#make sure that CLIENT_DIR/runstatus exists
if [[ ! -e ${CLIENT_DIR}/runstatus ]]
 then
  echo "${CLIENT_DIR}/runstatus not found"
  echo "Script: $SCRIPT_NAME"                   \
       "\nProcessing for $CLIENT_NAME"                 \
        "\nError: ${CLIENT_DIR}/runstatus not found" > $MAILFILE
  export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
  $SCRIPT_DIR/mailto_IS_group.ksh
  exit
fi

#get runstatus by grabbing first line and checking for no entry
read runstatus < ${CLIENT_DIR}/runstatus
if [[ $runstatus = '' ]]
 then
  echo "${CLIENT_DIR}/runstatus is empty"
  echo "Script: $SCRIPT_NAME"                   \
        "\nProcessing for $CLIENT_NAME"                 \
        "\nError: ${CLIENT_DIR}/runstatus is empty" > $MAILFILE
  export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
  $SCRIPT_DIR/mailto_IS_group.ksh
  exit
fi    
  
#check status: if blank, change to past deadline and notify
if [[ $runstatus = "blank" ]]
 then
  echo "$CLIENT_NAME runstatus is $runstatus."
  #change runstatus to 'past deadline'
  print "past deadline" > ${CLIENT_DIR}/runstatus
  echo "changed runstatus to past deadline"
  echo "Script: $SCRIPT_NAME"                   \
        "\nProcessing for $CLIENT_NAME"                 \
        "\nError: ${CLIENT_DIR}/runstatus was 'blank'," \
        " runstatus changed to 'past deadline'" > $MAILFILE
  export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
  #notify IS
  $SCRIPT_DIR/mailto_IS_group.ksh
  #notify client
  echo "We have not recieved your claims data dump" \
       " for this month yet. Please submit it or " \
       " get in touch with with your Caremark contact. " > $MAILFILE
  export MAIL_SUBJECT="CAREMARK has not recieved your monthly claims data"
  $SCRIPT_DIR/mailto_CLIENT_group.ksh
fi

read runstatus < ${CLIENT_DIR}/runstatus
echo "$CLIENT_NAME runstatus is $runstatus"

$SCRIPT_DIR/DFO_chk_all_clts_complete.ksh 
