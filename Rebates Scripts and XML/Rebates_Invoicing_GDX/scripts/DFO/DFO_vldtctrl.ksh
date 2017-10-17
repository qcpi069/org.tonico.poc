#!/usr/bin/ksh

###############################################
#SCRIPT NAME : DFO_validate_control_records   #
#                                             #
#PURPOSE     : Does preliminary validations on#
#              claims and control records.    #
#              First it makes sure that the   #
#              input is a file and then checks#
#              for its size. Empty file stops #
#              further processing and causes  #
#              contract administrators to be  #
#              e-mailed. Non-empty file is    #
#              checked for presence of 0-, 2-,#
#              4-, 6- and 8- records.         #    
#              Presence of all records        #
#              validates it. Next validation  #
#              requires total count of        #
#              4-records to match with        #
#              6-record counts. Final         #
#              validation checks for dollar   #
#              amounts of 4- and 6-records.   #
#              If they match it passes        #
#              validation-I.                  #
#                                             #
#INSTRUCTIONS: This script takes two          #
#              command-line arguments. First  #
#              is the processor Name and the  #
#              second is input file name with #
#              absolute path                  #
#                                             #
#CALLS       : This script calls              #
#              (1) sum_it_up.exe --- A C      #
#                  program to calculate the   #
#                  sum of                     #
#                  total nos in 6-records.    #
#              (2) conv.scr      --- A shell  #
#                  script, which in turn calls#
#                  a microfocus cobol program #
#                  to convert sign fields from#
#                  ebcdic to ascii. The input #
#                  file used by the program is#
#                  read and updated with      #
#                  converted values.          #
#              (3) addamt.scr    --- A shell  #
#                  script, which in turn calls#
#                  a microfocus cobol program #
#                  to read the converted file #
#                  produced by conv.scr and   #
#                  produce the output file    #
#                  containing the summation of#
#                  records that are nothing   #
#                  but dollar amounts.        #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        Bhabani Dash   01/15/2002  Initial Release                    #
#                                                                           #
#############################################################################

echo "VALIDATION-I PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Validating control records.."

PROCESSOR_NO_FILE="$TEMP_DIR/processor_no"

>$MAILFILE

#===================================================================

  function clean_up {
  
     rm -f $MAILFILE
     rm -f $PROCESSOR_NO_FILE
  
  }
  
#===================================================================

  if [[ ! -f "$IN_DATA_FILE" ]] then
   
     echo "Error: Input file $IN_DATA_FILE does not exist.."
     echo "Input file $IN_DATA_FILE does not exist" >> $MAILFILE
     MAIL_SUBJECT="File error "
     $SCRIPT_DIR/mailto_IS_group.ksh

     exit 1
  
  fi
  
  if [[ ! -s "$IN_DATA_FILE" ]] then
  
     echo "Error: Input file $IN_DATA_FILE is empty.."
     echo "Input file $IN_DATA_FILE is empty " >> $MAILFILE
     MAIL_SUBJECT="File error "
     $SCRIPT_DIR/mailto_IS_group.ksh

     exit 1
  
  fi
  
  ###################################################################
  #Find how many 0, 2, 4, 6 and 8 records are present
  ###################################################################
  
  NO_OF_ZERO_RECORDS=`grep  -c "^0" $IN_DATA_FILE`
  NO_OF_TWO_RECORDS=`grep   -c "^2" $IN_DATA_FILE`
  NO_OF_FOUR_RECORDS=`grep  -c "^4" $IN_DATA_FILE`
  NO_OF_SIX_RECORDS=`grep   -c "^6" $IN_DATA_FILE`
  NO_OF_EIGHT_RECORDS=`grep -c "^8" $IN_DATA_FILE`
  
  ###################################################################
  #
  ###################################################################
  
  if [[ -z `head -1 $IN_DATA_FILE | grep "^0"` ]] then
  
     echo "Error: First record is not a Zero Record..."
     echo "First record is not a Zero Record" >> $MAILFILE
  
  fi
  
  if [[ $NO_OF_ZERO_RECORDS  = 0 ]] then
  
      echo "Error: Zero Records missing..."
      echo "No Zero Records Found" >> $MAILFILE
  
  fi
  
  if [[ $NO_OF_ZERO_RECORDS  > 1 ]] then
  
      echo "Error: $NO_OF_ZERO_RECORDS Zero Records Found..."
      echo "$NO_OF_ZERO_RECORDS Zero Records Found" >> $MAILFILE
  
  fi
  
  if [[ $NO_OF_TWO_RECORDS  = 0 ]] then
  
      echo "Error: Two Records missing..."
      echo "No Two Records Found" >> $MAILFILE
  
  fi
  
  if [[ $NO_OF_FOUR_RECORDS  = 0 ]] then
  
      echo "Error: Four Records missing..."
      echo "No Four Records Found" >> $MAILFILE
  
  fi
  
  if [[ $NO_OF_SIX_RECORDS  = 0 ]] then
  
      echo "Error: Six Records missing..."
      echo "No SIX Records Found" >> $MAILFILE
  
  fi
  
  if [[ $NO_OF_EIGHT_RECORDS  = 0 ]] then
  
      echo "Error: Eight Records missing..."
      echo "No Eight records Found" >> $MAILFILE
  
  fi
  
  if [[ $NO_OF_EIGHT_RECORDS  > 1 ]] then
  
      echo "Error: $NO_OF_EIGHT_RECORDS Eight Records Found..."
      echo "$NO_OF_EIGHT_RECORDS Eight records Found" >> $MAILFILE
  
  fi
  
  if [[ -z `tail -1 $IN_DATA_FILE | grep "^8"` ]] then
  
     echo "Error: Last record is not an Eight Record..."
     echo "Last record is not a Eight Record" >> $MAILFILE
  
  fi
  
  cat $IN_DATA_FILE | cut -c2-11 | sort | uniq > $PROCESSOR_NO_FILE
  
  #echo `wc -l $PROCESSOR_NO_FILE | cut -f1 -d "/"`
  PROCESSOR_NO_COUNT=`wc -l $PROCESSOR_NO_FILE | cut -f1 -d "/"`
  
  if [[ "$PROCESSOR_NO_COUNT" -ne "1" ]] then
  
      echo "Error: File does not contain\n" \
            "Unique processor numbers and processor numbers are"
      cat $PROCESSOR_NO_FILE
  
      echo "File does not contain unique processor number" >> $MAILFILE
  
  fi
  
  if [[ -s "$MAILFILE" ]] then
  
     MAIL_SUBJECT="Corrupted file for $CLIENT_NAME"
     $SCRIPT_DIR/mailto_IS_group.ksh

     exit 1
  
  fi
  
  clean_up
  
  echo "Control records were Validated.."
  echo "Process Successful."
  echo "VALIDATION-I PROCESS ended - `date +'%b %d, %Y %H:%M:%S'`......."

  exit 0
