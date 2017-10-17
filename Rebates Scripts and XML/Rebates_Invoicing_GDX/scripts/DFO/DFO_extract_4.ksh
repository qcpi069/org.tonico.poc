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

echo "EXTRACTION PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Extracting claims records.."

>$MAILFILE

#===================================================================

  if [[ ! -f "$IN_DATA_FILE" ]] then
 
     echo "Error: Input file $IN_DATA_FILE does not exist..."

     echo "Script: 'DFO_extract_4.ksh'"                   \
          "\nProcessing for $CLIENT_NAME"                 \
          "\nError: Input file $IN_DATA_FILE does not exist"  \
          "\nLook for Log file $LOG_FILE" > $MAILFILE

     MAIL_SUBJECT="DFO PROCESS"
  
     $SCRIPT_DIR/mailto_IS_group.ksh

     exit 100

  fi

#===================================================================

  if [[ ! -s "$IN_DATA_FILE" ]] then
  
     echo "Error: Input file $IN_DATA_FILE is empty..."

     echo "Script: 'DFO_extract_4.ksh'"                   \
          "\nProcessing for $CLIENT_NAME"                 \
          "\nError: Input file $IN_DATA_FILE is empty"        \
          "\nLook for Log file $LOG_FILE" > $MAILFILE

     MAIL_SUBJECT="DFO PROCESS"

     $SCRIPT_DIR/mailto_IS_group.ksh

     exit 200

  fi

#===================================================================

  >$OUT_DATA_FILE

  grep "^4" $IN_DATA_FILE > $OUT_DATA_FILE

  if [[ $? != 0 ]] then

     MAIL_SUBJECT="DFO SCRIPT EXECUTION ERROR"
     echo "DFO script 'DFO_extract_4.ksh'"   \
          "\nProcessing for $CLIENT_NAME"    \
          "\nclaims records could not be extracted" > $MAILFILE

     $SCRIPT_DIR/mailto_IS_group.ksh

     exit 300

  fi
 
  echo "Claims records were extracted.."
  echo "Process Successful."
  echo "EXTRACTION PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."

  exit 0
