#!/usr/bin/ksh

###############################################
#SCRIPT NAME :                                #
#                                             #
#PURPOSE     : Does preliminary validations on#
#                                             #
#INSTRUCTIONS: This script takes two          #
#                                             #
#CALLS       : This script calls              #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        Bhabani Dash   01/15/2002  Initial Release                    #
#                                                                           #
#############################################################################

echo "VALIDATE SORT PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Sorting claims records by CLIENT/Fill Date/frly id."

>$MAILFILE

#===================================================================

  if [[ ! -f "$IN_DATA_FILE" ]] then
   
     echo "Error: Input file $IN_DATA_FILE does not exist..."
  
     echo "Script: 'DFO_sortby_cltfildt.ksh'"                    \
          "\nProcessing for $CLIENT_NAME"                   \
          "\nError: Input file $IN_DATA_FILE does not exist"   \
          "\nLook for Log file $LOG_FILE" > $MAILFILE
  
     MAIL_SUBJECT="DFO PROCESS"
  
     $SCRIPT_DIR/mailto_IS_group.ksh
  
     exit 100
  
  fi
  
#===================================================================

  if [[ ! -s "$IN_DATA_FILE" ]] then
  
     echo "Error: Input file $IN_DATA_FILE is empty..."
  
     echo "Script: 'DFO_sortby_cltfildt.ksh'"                    \
          "\nProcessing for $CLIENT_NAME"                   \
          "\nError: Input file $IN_DATA_FILE is empty"         \
          "\nLook for Log file $LOG_FILE" > $MAILFILE
  
     MAIL_SUBJECT="DFO PROCESS"
  
     $SCRIPT_DIR/mailto_IS_group.ksh
  
     exit 200
  
  fi
  
  >$OUT_DATA_FILE
  
#===================================================================
# Sort claims records by CLIENT (processor nbr, group nbr), fill date and frly_id

  sort -t"^" -T /GDX/prod/tmp -k1.2,1.11 -k1.180,1.194 -k1.19,1.33 -k1.34,1.41r -k1.227,1.243 $IN_DATA_FILE -o $OUT_DATA_FILE
  
  if [[ $? != 0 ]] then
  
     MAIL_SUBJECT="DFO SCRIPT EXECUTION ERROR"
     echo "DFO script 'DFO_sortby_cltfildt.ksh'"  \
          "\nProcessing for $CLIENT_NAME"    \
          "\nclaims records could not be sorted" > $MAILFILE
  
     $SCRIPT_DIR/mailto_IS_group.ksh
  
     exit 300
  
  fi
  
  echo "Claims records were sorted by client id, fill date and frly id."
  echo "Process Successful."
  echo "VALIDATE SORT PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
  
  exit 0
