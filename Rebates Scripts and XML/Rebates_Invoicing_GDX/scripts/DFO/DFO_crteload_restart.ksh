#!/usr/bin/ksh

###############################################
#SCRIPT NAME : DFO_process                    #
#                                             #
#PURPOSE     :                                #
#                                             #
#INSTRUCTIONS: This script takes two          #
#              command-line arguments. First  #
#              is the processor Name and the  #
#              second is input file name with #
#              absolute path                  #
#                                             #
#CALLS       :                                #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        Bhabani Dash   01/15/2002  Initial Release                    #
#                                                                           #
#############################################################################

#=================================================================
#GETS FILE NAME FROM FTP STAGING DIRECTORY
#FILE NAME FORMAT IS (in lower case):
#      <client name>.<monyyyy>.<mmddyyyy>.dat.<yyyymmddhhmmss>
#=================================================================

  export OLD_DATAFILE=`head -1 $DATA_FILE_NAME_FILE`
  echo "old_datafile " $OLD_DATAFILE >>$LOG_FILE
  
  export DATAFILE="`echo $OLD_DATAFILE | cut -f1-2 -d "."`"
  echo "datafile " $DATAFILE >>$LOG_FILE

#===================================================================
#EXTRACTS PROCESS MONTH AND YEAR FROM INPUT FILE NAME
#===================================================================
 
  echo "\n" >> $LOG_FILE

  export PROCESS_MONTH_PARM_FILE="$TEMP_DATA_DIR/DFO_process_month_parm.ref"

  $SCRIPT_DIR/DFO_extract_procmth.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally.." >>$LOG_FILE
     exit 1
  fi

  export PROCESS_MONTH="`echo $OLD_DATAFILE |  \
                         cut -f2-2 -d "."   |  \
                         cut -c1-3`"
 
  export PROCESS_YEAR="`echo $OLD_DATAFILE |  \
                         cut -f2-2 -d "."  |  \
                         cut -c4-`"
 
#===================================================================
#SINCE THE FILE NAME IS BIG AND BECOMES BIGGER AND BIGGER AS
#PROCESS CONTINUES, A SOFT LINK WITH SHORT NAME IS CREATED IN
#TEMPORARY DIRECTORY AND IS REMOVED ALONG WITH IT AFTER PROCESS
#IS DONE.
#===================================================================

  echo "\n" >> $LOG_FILE

  echo "Process begins - `date +'%b %d, %Y %H:%M:%S'`......." >>$LOG_FILE
  echo "Creating link.." >>$LOG_FILE

  echo " old data file ... " $OLD_DATAFILE >> $LOG_FILE
  echo "link temp file ... " $TEMP_DATA_DIR/$DATAFILE >> $LOG_FILE
  ln -s -f $STAGING_DIR/$OLD_DATAFILE $TEMP_DATA_DIR/$DATAFILE

  if [[ $? != 0 ]] then
     echo "Link cannot not be created\n"  \
          "Process terminated abnormally..." >>$LOG_FILE
     exit 1
  fi
 
  echo "$TEMP_DATA_DIR/$DATAFILE was linked to" \
       "$STAGING_DIR/$OLD_DATAFILE.." >> $LOG_FILE

  echo "Process Successful."                   >> $LOG_FILE
  echo "Process ended - `date +'%b %d, %Y %H:%M:%S'`......." >>$LOG_FILE

#===================================================================
#VALIDATE LENGTH OF EACH RECORD
#===================================================================

  export IN_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE"
  export BAD_FILE="$TEMP_DATA_DIR/$DATAFILE.chkrecl.reject"

 # $SCRIPT_DIR/DFO_check_record_length.ksh >>$LOG_FILE 2>&1

 # if [[ $? != 0 ]] then
 #    echo "Process terminated abnormally..." >>$LOG_FILE
 #    exit 1
 # fi

#===================================================================
#VALIDATE CONTROL RECORDS 
#===================================================================

  echo "\n" >> $LOG_FILE

  $SCRIPT_DIR/DFO_vldtctrl.ksh >> $LOG_FILE

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 1
  fi

#===================================================================
#CREATE COUNT FILE CONTAINING TOTAL CLAIMS RECORD,
#TWO PERCENT OF IT AND 0 (AS SO FAR REJECTED COUNT)
#===================================================================

  echo "\n" >> $LOG_FILE

  export OUT_REJ_COUNT_REF="$TEMP_DATA_DIR/DFO_reject_count.ref"

  $SCRIPT_DIR/DFO_crtecount.pl         \
           $IN_DATA_FILE               \
           $OUT_REJ_COUNT_REF          \
        >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 2
  fi

#===================================================================
#CONVERT REQUIRED SIGN FIELDS FROM EBCDIC TO ASCII
#POPULATE ZEROES FOR NON-REQUIRED NUMERIC FIELDS
#POPULATE SPACES FOR NON-REQUIRED ALPHA-NUMERIC FIELDS
#===================================================================

  echo "\n" >> $LOG_FILE
  echo "convert ref file used:" >>$LOG_FILE
  echo $REF_DIR/DFO_convert_${CLIENT_NAME}.ref >>$LOG_FILE


  export CONV_REF="$REF_DIR/DFO_convert_${CLIENT_NAME}.ref"
  export IN_REJ_COUNT_REF="$OUT_REJ_COUNT_REF"
  export CONV_CONV="$TEMP_DATA_DIR/$DATAFILE.convert.convert"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.convert.good"
  export BAD_FILE="$TEMP_DATA_DIR/$DATAFILE.convert.reject"
  export DATA_LOG_FILE="$TEMP_DATA_DIR/$DATAFILE.convert.log"
  export OUT_REJ_COUNT_REF="$TEMP_DATA_DIR/DFO_reject_count.convert.ref"

  $SCRIPT_DIR/DFO_convert.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then

     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 3

  fi

#===================================================================
#VALIDATES BATCH OF 2, 4 AND 6 RECORDS.
#MATCHES TOTAL 4s WITH CLAIMS COUNT ON 6 PER BATCH
#MATCHES TOTAL AMOUNT BILLED ON 4s WITH DOLLARS AMOUNT ON 
#6s PER BATCH
#MATCHES TOTAL PHARMACY COUNT WITH PHARMACY COUNT ON 8 RECORD
#===================================================================

  echo "\n" >> $LOG_FILE
  echo "Process moving to set DD cards for vldtctrl_batch..." >>$LOG_FILE
  echo $CONV_CONV >> $LOG_FILE
  export IN_DATA_FILE="$CONV_CONV"
  export PARM_FILE="$REF_DIR/DFO_bothparm.ref"
  export BAD_FILE="$TEMP_DATA_DIR/$DATAFILE.vldtctrl_batch.reject"
  export DATA_LOG_FILE="$TEMP_DATA_DIR/$DATAFILE.vldtctrl_batch.log"

  $SCRIPT_DIR/DFO_vldtctrl_batch.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 4
  fi

#===================================================================
#COMPRESS PREVIOUSLY USED FILES
#===================================================================

  $SCRIPT_DIR/DFO_compress_file $TEMP_DATA_DIR/$DATAFILE.convert.convert \
       >$LOG_FILE.compression.log1 2>&1 &

  $SCRIPT_DIR/DFO_compress_file $TEMP_DATA_DIR/$DATAFILE.convert.good    \
       >$LOG_FILE.compression.log1 2>&1 &

#===================================================================
#EXTRACT CLAIMS RECORDS FROM INPUT FILE
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.claims"

  $SCRIPT_DIR/DFO_extract_4.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 5
  fi

#===================================================================
# identify voids and reformat for sort sequencing
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export IN_REJ_COUNT_REF="$OUT_REJ_COUNT_REF"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.srtformt.good"
  export BAD_FILE="$TEMP_DATA_DIR/$DATAFILE.srtformt.reject"
  export DATA_LOG_FILE="$TEMP_DATA_DIR/$DATAFILE.srtformt.log"
  export OUT_REJ_COUNT_REF="$TEMP_DATA_DIR/DFO_reject_count.srtformt.ref"


  $SCRIPT_DIR/DFO_srtformt.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 7
  fi


#===================================================================
#SORT CLAIMS RECORD BY NABP ID/FILL DATE/NEW REFILL CODE/RX NUMBER
#IN ASCENDING ORDER
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.claims.srtbykey"

  echo "sort file "  >> $LOG_FILE
  echo OUT_DATA_FILE >> $LOG_FILE

  $SCRIPT_DIR/DFO_sortby_voidkey.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 6
  fi


#===================================================================
#ELIMINATE RECORDS WHICH HAVE MORE THAN ONE RECORD FOR KEY
#(NABP ID/FILL DATE/NEW REFILL CODE/RX NUMBER), ALSO
#REMOVE VOIDED PAIRS FROM INPUT CLAIMS FILE (WHERE APPLICABLE)
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export IN_REJ_COUNT_REF="$OUT_REJ_COUNT_REF"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.elimdupl.good"
  export BAD_FILE="$TEMP_DATA_DIR/$DATAFILE.elimdupl.reject"
  export DATA_LOG_FILE="$TEMP_DATA_DIR/$DATAFILE.elimdupl.log"
  export OUT_REJ_COUNT_REF="$TEMP_DATA_DIR/DFO_reject_count.elimdupl.ref"

  $SCRIPT_DIR/DFO_elimdupl.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 7
  fi

#===================================================================
#COMPRESS PREVIOUSLY USED FILES
#===================================================================

  $SCRIPT_DIR/DFO_compress_file $TEMP_DATA_DIR/$DATAFILE.srtformt.good    \
       >$LOG_FILE.compression.log2 2>&1 &

  $SCRIPT_DIR/DFO_compress_file $TEMP_DATA_DIR/$DATAFILE.claims.srtbykey  \
       >$LOG_FILE.compression.log3 2>&1 &

#===================================================================
#ELIMINATE RECORDS WHICH HAVE MORE THAN ONE RECORD FOR KEY
#(NABP ID/FILL DATE/NEW REFILL CODE/RX NUMBER)
#FOR CLAIMS OR DUPLICATES (WHERE APPLICABLE)
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export IN_REJ_COUNT_REF="$OUT_REJ_COUNT_REF"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.elimdup1.good"
  export BAD_FILE="$TEMP_DATA_DIR/$DATAFILE.elimdup1.reject"
  export DATA_LOG_FILE="$TEMP_DATA_DIR/$DATAFILE.elimdup1.log"
  export OUT_REJ_COUNT_REF="$TEMP_DATA_DIR/DFO_reject_count.elimdup1.ref"

  $SCRIPT_DIR/DFO_elimdup1.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 7
  fi


#===================================================================
#SORT CLAIMS RECORD BY CLIENT ID (processor nbr & group nbr)/FILL DATE
#IN ASCENDING ORDER
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.claims.srtbycltFilldt"

  echo "sort file "  >> $LOG_FILE
  echo OUT_DATA_FILE >> $LOG_FILE

  $SCRIPT_DIR/DFO_sortby_cltfildt.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 6
  fi

#===================================================================
#COMPRESS PREVIOUSLY USED FILES
#===================================================================

  $SCRIPT_DIR/DFO_compress_file.ksh $TEMP_DATA_DIR/$DATAFILE.elimdupl.good    \
       >$LOG_FILE.compression.log4 2>&1 &

  $SCRIPT_DIR/DFO_compress_file.ksh $TEMP_DATA_DIR/$DATAFILE.elimdup1.good    \
       >$LOG_FILE.compression.log5 2>&1 &

#===================================================================
#VALIDATE CLAIMS FIELDS
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export IN_REJ_COUNT_REF="$OUT_REJ_COUNT_REF"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.validate.good"
  export BAD_FILE="$TEMP_DATA_DIR/$DATAFILE.validate.reject"
  export DATA_LOG_FILE="$TEMP_DATA_DIR/$DATAFILE.validate.log"
  export OUT_REJ_COUNT_REF="$TEMP_DATA_DIR/DFO_reject_count.validate.ref"
  export OBADCLT_FILE="$TEMP_DATA_DIR/$DATAFILE.badcltid.recs"


  $SCRIPT_DIR/DFO_validate.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 7
  fi

#===================================================================
#SORT CLAIMS RECORDS BY NDC ID/FILL DATE IN ASCENDING ORDER
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.validate.sortbyndc"

  $SCRIPT_DIR/DFO_sortby_ndc.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 8
  fi

#===================================================================
#VALIDATE NDC ID AND OBTAIN NHU TYPE CODE AND AWP PRICE    
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export IN_REJ_COUNT_REF="$OUT_REJ_COUNT_REF"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.getnhutp.good"
  export BAD_FILE="$TEMP_DATA_DIR/$DATAFILE.getnhutp.reject"
  export DATA_LOG_FILE="$TEMP_DATA_DIR/$DATAFILE.getnhutp.log"
  export OUT_REJ_COUNT_REF="$TEMP_DATA_DIR/DFO_reject_count.getnhutp.ref"

  $SCRIPT_DIR/DFO_getnhutp.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 
  fi

#===================================================================
#SORT BY GROUP NUMBER/FILL DATE IN ASCENDING ORDER IF THE CLIENT
#BEING PROCESSED HAS SUB-CLIENT(S)
#SORT BY FILL DATE IN ASCENDING ORDER IF THE CLIENT BEING PROCESSED
#HAS NO SUB-CLIENT
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  
  if [[ -n `head -1 $CONTRACT_FILE | grep "^N"` ]] then

     OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.getnhutp.sortbyfilldt"

     $SCRIPT_DIR/DFO_sortby_filldt.ksh >>$LOG_FILE 2>&1

     if [[ $? != 0 ]] then
        echo "Process terminated abnormally..." >>$LOG_FILE
        exit 10
     fi

  else

     OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.getnhutp.sortbygrp"

     $SCRIPT_DIR/DFO_sortby_grp_nb.ksh >>$LOG_FILE 2>&1

     if [[ $? != 0 ]] then
        echo "Process terminated abnormally..." >>$LOG_FILE
        exit 10
     fi

  fi

#===================================================================
#COMPRESS PREVIOUSLY USED FILES
#===================================================================

  $SCRIPT_DIR/DFO_compress_file.ksh                           \
       $TEMP_DATA_DIR/$DATAFILE.claims.srtbycltFilldt         \
       >$LOG_FILE.compression.log6 2>&1 &

  $SCRIPT_DIR/DFO_compress_file.ksh                           \
       $TEMP_DATA_DIR/$DATAFILE.validate.sortbyndc            \
       >$LOG_FILE.compression.log7 2>&1 &

  $SCRIPT_DIR/DFO_compress_file.ksh                           \
       $TEMP_DATA_DIR/$DATAFILE.validate.good                 \
       >$LOG_FILE.compression.log8 2>&1 &

  $SCRIPT_DIR/DFO_compress_file.ksh                           \
       $TEMP_DATA_DIR/$DATAFILE.getnhutp.good                 \
       >$LOG_FILE.compression.log9 2>&1 &

#===================================================================
#FINAL VALIDATION AND CREATE LOAD FILE TO BE LOADED INTO
#EXTERNAL CLAIMS TABLE
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export IN_REJ_COUNT_REF="$OUT_REJ_COUNT_REF"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.crteload.good"
  export LOAD_FILE="$TEMP_DATA_DIR/$DATAFILE.crteload.load"
  export BAD_FILE="$TEMP_DATA_DIR/$DATAFILE.crteload.reject"
  export WARN_FILE="$TEMP_DATA_DIR/$DATAFILE.crteload.warn"
  export DATA_LOG_FILE="$TEMP_DATA_DIR/$DATAFILE.crteload.log"
  export OUT_REJ_COUNT_REF="$TEMP_DATA_DIR/DFO_reject_count.crteload.ref"

  $SCRIPT_DIR/DFO_crteload_parallel.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally" >>$LOG_FILE
     exit 9
  fi

#===================================================================

  echo "\n" >> $LOG_FILE

  TIMESTAMP=`date +"%Y%m%d%H%M%S"`
  export DATA_LOAD_FILE="dfo.$SCHEMA.tclaim_ext.dat.$TIMESTAMP"

  $SCRIPT_DIR/DFO_load.ksh

# store dir for this run for monthly cleanup before next run
  print "${TEMP_DIR}"> $CLIENT_DIR/last_temp_dir

  $SCRIPT_DIR/DFO_ftp_to_tsmnim1.ksh >>$LOG_FILE 2>&1

  FTP_STATUS=$?

# 222 is a good return from FTP kornshell... test for dba load script status
  if (($FTP_STATUS==222)); then

      #   informative email to track progress
      echo    "Load Processing for $CLIENT_NAME is starting:"   \
              "\nftp of load file to tsmnim1 was good."         \
              "\nfollow progress in $LOG_FILE" > $MAILFILE
 
      MAIL_SUBJECT="DFO db load PROCESS"
      $SCRIPT_DIR/mailto_IS_group.ksh

      $SCRIPT_DIR/DFO_load_tclaim_ext.ksh >>$LOG_FILE 
     
      DBA_AUTOLOAD_RETURN_CD=$?
      echo "global Load_Return_Code: " $Load_Return_Code >>$LOG_FILE 
  
      echo "dba load ksh return code: ${DBA_AUTOLOAD_RETURN_CD} " >>$LOG_FILE
      
      #  return code values and meanings for "DFO_load_tclaim_ext.ksh"
      #  
      #  140 series are 'good' return codes
      #
      #  140 = claims loaded successfully without any duplicates
      #  142 = claims loaded but with duplicates in TCLAIM_EXT_EXCP table
      #
      #  150 series are 'bad' return codes
      #
      #  150 = non-zero return code on DBA.LOADS table for given load data set
      #  152 = SQL error of some sort  
      #  154 = Multiple rows in DBA.LOADS for given load data set, further
      #        manual investigation is needed to determine if there are problems
      #  156 = We never got a row in DBA.LOADS for the load of the given 
      #        load data set.  Manual investigation needed
      #  

      if (($DBA_AUTOLOAD_RETURN_CD<150)); then

#        only if DBA load process has no errors will we get here

#        notify the DFO support pager that processing complete for client

         echo "email notifying DFO support that processing completed" >> $LOG_FILE               
         print "LOAD Processing for $CLIENT_NAME has finished. " > $MAILFILE

         MAIL_SUBJECT="DFO PROCESS TCLAIM_EXT TABLE LOAD ended"
         $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1
                     
#        clean up the staging area since we're done, we no longer need the input
#        file, anyways it's in $CLIENT_DIR/compressed_ftp_claims
         rm $STAGING_DIR/*$CLIENT_NAME*
         if [[ $? != 0 ]] then
            echo "problems removing $STAGING_DIR " >> $LOG_FILE
         fi

#        update the status for the client for this current process run
         print "completed" > $RUN_STATUS
                    
#        run the kornshell to check if all DFO clients are 'done'... then MDA 
#        processing can be initiated for this time frame
         $SCRIPT_DIR/DFO_chk_all_clts_complete.ksh $CLIENT_NAME >>$LOG_FILE 2>&1

#        run the kornshell to send a trigger to analytics 
#        indicating that the current client is done for this month
         $SCRIPT_DIR/DFO_ftp_to_dalcdcp.ksh $CLIENT_NAME >>$LOG_FILE 2>&1

         if (($DBA_AUTOLOAD_RETURN_CD==142)); then

            #  This kornshell will send the rejected duplicates
            #  (in TCLAIM_EXT_EXCP) to the client via email
            #  no need to send a client name since the DBA load script
            #  will only load 1 load data set at a time and will not run
            #  if there are rows in TCLAIM_EXT_EXCP.  Handle duplicates will
            #  place the duplicate rows in 
            #  $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.duplicates
            #  
         
            $SCRIPT_DIR/DFO_handle_duplicates.ksh $CLIENT_NAME >>$LOG_FILE 
         fi         

         #  This kornshell will sent the rejects to the client,
         #  store this concatenated rejected file in 
         #  $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.rejects
         #  and send out a summary for this client to internal
         #  Caremark personel with intake/rejected/accepted counts
         
         $SCRIPT_DIR/DFO_handle_rejects.ksh $CLIENT_NAME $TEMP_DATA_DIR >>$LOG_FILE 
     else 
         echo "problems in DBA loading of claims " >> $LOG_FILE
         print "investigate dba load process... problems" \
               "for client $CLIENT_NAME " > $MAILFILE
         
         MAIL_SUBJECT="DBA autoloader has problems"
         $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>$1  
   
     fi
   fi      

####################exit 0
#  $SCRIPT_DIR/clean_up.ksh >>$LOG_FILE 2>&1

#  $SCRIPT_DIR/DFO_create_audit.ksh >>$LOG_FILE 2>&1

# compress backed up load file in local directory 

  $SCRIPT_DIR/DFO_compress_file.ksh         \
       $DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE   \
       >$LOG_FILE.compression.log7 2>&1 &


  echo "\n***********************************************"   >> $LOG_FILE
  echo "VALIDATION FOR CLIENT $CLIENT_NAME ENDED."           \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE

#  cat $LOG_FILE >> $MASTER_LOG

#  if [[ $? = 0 ]] then
#     rm -f $LOG_FILE
#  fi
   return
