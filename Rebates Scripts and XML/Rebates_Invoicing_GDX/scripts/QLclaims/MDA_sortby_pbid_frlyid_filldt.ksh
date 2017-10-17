#!/usr/bin/ksh

#############################################################################
#SCRIPT NAME : MDA_sortby_pbid_frlyid_filldt.ksh                            #
#                                                                           #
#PURPOSE     : Put claims into control break order for program dwmda002.cbl #
#                                                                           #
#INSTRUCTIONS: This script takes two          #
#                                             #
#CALLS       : This script calls              #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        William Price  04/01/2004  Initial Release                    #
#                                                                           #
#############################################################################

echo "PB_ID/FRL_ID/FILL_DT SORT PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Sorting claims records by PB_ID/FRL_ID/FILL_DT..."

>$MAILFILE

#===================================================================

  if [[ ! -f "$IN_DATA_FILE" ]] then
   
     echo "Error: Input file $IN_DATA_FILE does not exist..."
     echo "Script: 'MDA_sortby_sortby_pbid_frlyid_filldt.ksh'"    \
          "\nProcessing for $RUN_MODE claims intake"              \
          "\nError: Input file $IN_DATA_FILE does not exist"      \
          "\nLook for Log file $LOG_FILE" > $MAILFILE
  
     MAIL_SUBJECT="MDA claims intake PROCESS"
  
     $SCRIPT_DIR/mailto_IS_group.ksh
  
     exit 100
  
  fi
  
#===================================================================

  if [[ ! -s "$IN_DATA_FILE" ]] then
  
     echo "Error: Input file $IN_DATA_FILE is empty..."
  
     echo "Script: 'MDA_sortby_sortby_pbid_frlyid_filldt.ksh'"    \
          "\nProcessing for $RUN_MODE claims intake"              \
          "\nError: Input file $IN_DATA_FILE is empty"            \
          "\nLook for Log file $LOG_FILE" > $MAILFILE
  
     MAIL_SUBJECT="MDA claims intake PROCESS"
  
     $SCRIPT_DIR/mailto_IS_group.ksh
  
     exit 200
  
  fi
  
  >$OUT_DATA_FILE
  
#===================================================================

  sort -t"^" -T /GDX/prod/tmp -k1.265,1.273 -k2.300,2.308 -k3.146,2.155 $IN_DATA_FILE -o $OUT_DATA_FILE
  
  if [[ $? != 0 ]] then
  
     MAIL_SUBJECT="MDA claims intake sort SCRIPT EXECUTION ERROR"

     echo "Script: 'MDA_sortby_sortby_pbid_frlyid_filldt.ksh'"    \
          "\nProcessing for $RUN_MODE claims intake"              \
          "\nclaims records could not be sorted" > $MAILFILE
  
     $SCRIPT_DIR/mailto_IS_group.ksh
  
     exit 300
  else  
#    no longer need claims intake file
     rm $IN_DATA_FILE
  fi
  
  echo "Claims records were sorted by pb_id/frly_id/fill_dt key.."
  echo "Process Successful."
  echo "PB_ID/FRL_ID/FILL_DT SORT PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
  
  exit 0
