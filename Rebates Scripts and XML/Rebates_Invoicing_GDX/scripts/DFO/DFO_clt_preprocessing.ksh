#!/usr/bin/ksh

#############################################################################
#	SCRIPT NAME : DFO_clt_preprocessing                                 #
#	                                                                    #
#	PURPOSE     : This korn shell will determine if a client has any    #
#                     preprocessing to be done before the 'standard' DFO    #
#                     core processing kornshell.                            #
#                     The std input DFO file name will be renamed and used  #
#                     as input to the client specific pre-processing ksh.   #
#                     The output of the client specific ksh will be the     #
#                     std input DFO file name.                              #
#	                                                                    #
#	INSTRUCTIONS: This script takes one command-line argument:          #
#	              is the DFO client name.                               #
#	                                                                    #
#	CALLS       :                                                       #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        William Price  07/13/2003  Initial Release                    #
#                                                                           #
#############################################################################

  echo "DFO PRE-PROCESS DETERMINATION `date +'%b %d, %Y %H:%M:%S'`....." >> $LOG_FILE
#================================================
#ACCEPTS ONE COMMAND LINE PARAMETER.
#================================================

  if [[ $# != 1 ]] then
     echo "Usage DFO_clt_preprocess.ksh <CLIENT NAME>"
     exit 1
  fi

  export CLIENT_NAME=`echo $1 | tr '[A-Z]' '[A-Z]'`

##export

  echo "***********************************************"   >> $LOG_FILE
  echo "Looking for : $CLIENT_NAME preprocessing"    \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE

  case ${CLIENT_NAME} in
#     
         'DUMMYCLIENT'         )
#         'FIRSTHEALTH'         )
 
         echo "preprocessing starting for client: " ${CLIENT_NAME}  >> $LOG_FILE

#        first health needs to have 1 byte stripped from it's input file
#        there's data in that column that we don't want/need
#
#        running truncate.cbl program will accomplish this task, but first let's save	
#        the std DFO input file name and rename it for input into truncate korn shell.

         export OLD_DATAFILE=`head -1 $DATA_FILE_NAME_FILE`

         export SAVE_CLIENT_DFO_FILE_NAME="$STAGING_DIR/$OLD_DATAFILE"
         export IN_DATA_FILE="$STAGING_DIR/$OLD_DATAFILE"
         export OUT_DATA_FILE="$STAGING_DIR/tempfirsthealth"
         
         $SCRIPT_DIR/FIRSTHEALTH_truncate.ksh >>$LOG_FILE 2>&1
              
         TRUNCATE_STATUS=$?

#        see if we successfully truncated the frsthlth file and 
#        rename it if we did.

         if [[ $TRUNCATE_STATUS = 0 ]]; then

            mv $OUT_DATA_FILE $SAVE_CLIENT_DFO_FILE_NAME
            let MOVE_STATUS=$?

            if (($MOVE_STATUS !=0)); then
#              notify the DFO support pager that pre-processing rename had problems
               echo "pre-processing rename trouble " >> $LOG_FILE
                  
               echo "Pre-processing for $CLIENT_NAME had problems "   \
                    "the temp file is located in "                    \    
                     `$OUT_DATA_FILE` > $MAILFILE

               MAIL_SUBJECT="DFO PRE-PROCESS problems "
               $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1
            fi

         else
            echo "ERRORS in truncate_frsthlth.ksh ..." >>$LOG_FILE

            echo "Script: $SCRIPT_NAME"                                \
            "\nPre-Processing for $CLIENT_NAME had a problem:"         \
            "\ntruncate_frsthlth.ksh threw a non-zero return code: "   \
            "$TRUNCATE_STATUS "                                        \ 
            "\nLook for Log file $LOG_FILE" > $MAILFILE

             MAIL_SUBJECT="DFO TRUNCATE_FRSTHLTH error"
     	     $SCRIPT_DIR/mailto_IS_group.ksh
            exit 269
         fi   ;;
                
      'PHARMASSESS'       )          
         echo "recognize pharmasses as a client but she got no preprocessing yet!" >> $LOG_FILE
         return 0 ;;

                
         'FIRSTHEALTH'         )
         echo "recognize FIRSTHEALTH as a client with no preprocessing anymore!" >> $LOG_FILE
         return 0 ;;
                
      '*'     )
         echo "no pre-processing defined for client: $CLIENT_NAME" >> $LOG_FILE
         return 0 ;;
                      
  esac

  echo "DFO PRE-PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
  
  exit 0
