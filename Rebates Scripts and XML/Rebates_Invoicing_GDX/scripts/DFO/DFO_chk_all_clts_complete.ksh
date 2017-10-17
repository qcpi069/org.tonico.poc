#!/usr/bin/ksh

#############################################################################
#SCRIPT NAME : DFO_chk_all_clts_complete.ksh                                #
#                                                                           #
#PURPOSE     : To see if the DFO processing for the current run period      #
#              has been completed (or is past deadline)                     #
#              for all clients in the active clients list                   #
#             								    #
#									    #
#INSTRUCTIONS: This script takes no command line arguments.                 #
#              This script also uses some exports from the DFO profile      #
#              so if that is changed, the script should be changed as well. # 
#              The script will email the addresses specified by the 	    #
#              internal variable SUPPORT_MAIL_LIST_FILE with any errors.    #
#              The script will notify MDA support if all the processing is  #
#              completed or past deadline using the addressed specified     #
#	       by the variable MDA_SUPPORT_MAIL_LIST_FILE.                  #
#              This script will be scheduled to run through the crontab.    #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
# 6013450	qcpi733       07/13/06   removed checks on the runstatus 
#                                        file for easier restartability.
#  1.0        Peter Miller   09/08/2003  Initial Release                    #
#                                                                           #
#############################################################################

export MDA_SUPPORT_MAIL_LIST_FILE="$REF_DIR/DFO_notify_MDA.ref"

export CLIENTSTATUS="$HOME_DIR/client_status"
touch $MAILFILE
touch $CLIENTSTATUS
CLIENT_NAME=$1
SCRIPT_NAME="DFO_chk_all_clts_complete.ksh"
integer clients_not_done=0

#check for active clients list file
if [[ ! -e ${HOME_DIR}/clients/active_clients.ref ]]
 then
  echo "Client list not found at ${HOME_DIR}/clients/active_clients.ref"
  echo "Script: $SCRIPT_NAME"                   \
       "\nError: Client list not found at ${HOME_DIR}/clients/active_clients.ref" > $MAILFILE
  export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
  $SCRIPT_DIR/mailto_IS_group.ksh
  exit 1
fi

#create and clear out MAILFILE to hold status listings
touch $MAILFILE
print "Client Name : Run Status\n" > $CLIENTSTATUS

#main client status processing loop
cat ${HOME_DIR}/clients/active_clients.ref | while read CLIENT_NAME 
 do 
 
  CLIENT_DIR="${HOME_DIR}/clients/${CLIENT_NAME}"
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


  
done

