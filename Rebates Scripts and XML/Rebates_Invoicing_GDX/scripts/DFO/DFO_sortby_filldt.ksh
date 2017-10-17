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

echo "SORT PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Sorting claims records by FILL DATE.."

MAIL_SUBJECT=""

>$MAILFILE
  
#===================================================================

  if [[ ! -f "$IN_DATA_FILE" ]] then
  
     echo "Error: Input file $IN_DATA_FILE does not exist..."
  
     echo "Script: 'DFO_sortby_filldt.ksh'"                 \
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
  
     echo "Script: 'DFO_sortby_filldt.ksh'"                 \
          "\nProcessing for $CLIENT_NAME"                   \
          "\nError: Input file $IN_DATA_FILE is empty"         \
          "\nLook for Log file $LOG_FILE" > $MAILFILE
  
     MAIL_SUBJECT="DFO PROCESS"
  
     $SCRIPT_DIR/mailto_IS_group.ksh
  
     exit 200
  
  fi
  
#===================================================================

  >$OUT_DATA_FILE
  
  sort -t"^" -T /GDX/prod/tmp -k1.34,1.41 $IN_DATA_FILE -o $OUT_DATA_FILE
  
  if [[ $? != 0 ]] then
  
     MAIL_SUBJECT="DFO SCRIPT EXECUTION ERROR"
     echo "DFO script 'DFO_sortby_filldt.ksh'"  \
          "\nProcessing for $CLIENT_NAME"       \
          "\nclaims records could not be sorted" > $MAILFILE
  
     $SCRIPT_DIR/mailto_IS_group.ksh
  
     exit 300
  
  fi
  
  echo "Claims records were sorted by FILL DATE.."
  echo "Process Successful."
  echo "SORT PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
  
  exit 0
