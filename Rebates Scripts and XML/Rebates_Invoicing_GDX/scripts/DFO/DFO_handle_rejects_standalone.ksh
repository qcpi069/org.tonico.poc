#!/usr/bin/ksh

 export SUPPORT_MAIL_LIST_FILE="/vradfo/prod/control/reffile/DFO_support_maillist.ref"
  export HOME_DIR="/vradfo/prod"
  export PROCESS_YEAR=2003
  export PROCESS_MONTH=dec
  export REF_DIR="$HOME_DIR/control/reffile"
  export TEMP_DIR="/vradfo/prod/temp/T20040113134704_P101692"
  export CLIENT_NAME="FIRSTHEALTH"
  export LOG_FILE="$TEMP_DIR/log_file.log"
  export MAILFILE="$TEMP_DIR/mailfile"
  export MAIL_SUBJECT="DFO process email subject"
#    export DBA_DATA_LOAD_DIR="/vradfo/prodload"
  export MAILFILE_TEST="$TEMP_DIR/mailfile_test"
# export DATA_LOAD_FILE="dfo.vrap.tclaim_ext.dat.20030701162156"
  export CLIENT_DIR="/vradfo/prod/clients/FIRSTHEALTH"
#   export DATA_LOAD_FILE="dfo.vrap.tclaim_ext.dat.20030804172557"
  export SCRIPT_DIR="$HOME_DIR/script"
  export TEMP_DATA_DIR="/vradfo/test/temp/T20040113134704_P101692/dat"
  export UNIQUE_RUN_ID=T20040113134704_P101692
  
echo "Process begins - `date +'%b %d, %Y %H:%M:%S'`......."
SCRIPT_NAME=`basename $0`

#export

#================================================
# ACCEPTS TWO COMMAND LINE PARAMETERS: 
# CLIENT NAME AND TEMPORARY DIRECTORY NAME
# WHERE REJECT FILE(s) RESIDE
#================================================

  if [[ $# != 2 ]] then
     echo "Usage DFO_handle_rejects.ksh <CLIENT NAME> <TEMP_DIR>"
     exit 1
  fi

#------------------------------------------------------------------
# CHECK FOR EXISTANCE OF ANY REJECT FILES WITH DATA.
# E-MAIL ONLY IF THERE'S SOMETHING TO EMAIL
#------------------------------------------------------------------
  
  CLIENT_NAME=$1
  TEMP_DATA_DIR=$2
 
  echo "Getting rejects for $CLIENT_NAME from temp directory" \
     "$TEMP_DATA_DIR..."

  cat $TEMP_DATA_DIR/*.reject > $TEMP_DATA_DIR/all.rejects
  typeset -i NO_OF_REJECTED_CHARS
  NO_OF_REJECTED_CHARS=`wc -c < $TEMP_DATA_DIR/all.rejects`
  cp $TEMP_DATA_DIR/all.rejects $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.rejects
  
  if (( $NO_OF_REJECTED_CHARS>=0 )) then
  
#       There are some rejects to be emailed to the client
#       sort them by error number

        sort -t"^" -T /vradfo/srttmp -k1.4,1.10 $TEMP_DATA_DIR/all.rejects -o $TEMP_DATA_DIR/rejected_files.txt
  
        if [[ $? != 0 ]] then
  
            MAIL_SUBJECT="DFO SCRIPT EXECUTION ERROR"
            echo "Sorting issues in DFO_handle_rejects" >> $LOG_FILE
            echo "DFO script 'DFO_handle_rejects.ksh'" \
                 "\nProcessing for $CLIENT_NAME"       \
                 "\nrejected records could not be sorted" > $MAILFILE
         
## don't exit but continue to process           return 150
            cp $TEMP_DATA_DIR/all.rejects $TEMP_DATA_DIR/rejected_files.txt

        else
          cp $TEMP_DATA_DIR/all.rejects $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.rejects 
        fi

        echo "FTP'ing data in $CLIENT_NAME.rejected_files.txt file to $CLIENT_NAME via prodftp(ecommerce)"  >> $LOG_FILE

        mv $TEMP_DATA_DIR/rejected_files.txt $TEMP_DATA_DIR/$CLIENT_NAME.rejected_files.txt
 
       $SCRIPT_DIR/DFO_ftp_to_prodftp.ksh $CLIENT_NAME.rejected_files.txt $TEMP_DATA_DIR $CLIENT_NAME              
       if [[ $? != 0 ]] then
          echo "problems sending rejected records to prodftp"        \
              "for $CLIENT_NAME.  reference $LOG_FILE" > $MAILFILE 

#             "\nPlease let us know if you have any questions or"   \
#             "concerns by emailing William.Price@Caremark.com or"  \
#             "Susan.Garfield@Caremark.com "                        \
#             "\n\n\n" > $MAILFILE

#             cat $TEMP_DATA_DIR/rejected_files.txt  >> $MAILFILE

              MAIL_SUBJECT="problem ftping REJECTED file for " \
               "$PROCESS_MONTH $PROCESS_YEAR for $CLIENT_NAME" \
              $SCRIPT_DIR/mailto_IS_group.ksh $CLIENT_NAME
 
       fi  
  else
        echo "NO REJECTS to be sent for $CLIENT_NAME !!"  >> $LOG_FILE
  
        echo "No rejects to sent for "                             \
             "$CLIENT_NAME.  For those non-believers, look in "     \
             "$TEMP_DATA_DIR for *.reject" > $MAILFILE

        MAIL_SUBJECT="DFO reject processing - for $PROCESS_MONTH $PROCESS_YEAR"
        $SCRIPT_DIR/mailto_IS_group.ksh
        
  fi
  
#------------------------------------------------------------------

  echo "\n***********************************************" >> $LOG_FILE
  echo "DFO email reporting of processing for $CLIENT_NAME ended." >>$LOG_FILE 
  echo "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE  
  echo "***********************************************\n" >> $LOG_FILE
  
  echo "Process return code: $Load_Return_Code"
  echo "Process ended - `date +'%b %d, %Y %H:%M:%S'`......."

  return $Load_Return_Code
