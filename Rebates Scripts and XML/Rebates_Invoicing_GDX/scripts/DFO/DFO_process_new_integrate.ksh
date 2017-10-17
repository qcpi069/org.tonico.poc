#!/usr/bin/ksh

###############################################
#SCRIPT NAME : DFO_process_new_integrate      #
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
# 6014329      qcpi733       08/21/2006  Corrected issue with addition of 
#                                        RETCODE value under the DFO_load..
#                                        script; removed call to 
#                                        DFO_chk_all_clts_complete.ksh and 
#                                        also DFO_ftp_to_dalcdcp.ksh.
# 6013450      qcpi733       07/14/2006  moved ECHOs that say the script call
#                                        is done, down below the capturing of
#                                        the return code.
#  1.0        Bhabani Dash   01/15/2002  Initial Release                    #
#             R Redus        04/27/2006  Replaced DFO_elimdupl.ksh with     #
#                                        DFO_elimdups.ksh.                  #
#                                                                           #
#############################################################################

#=================================================================
#GETS FILE NAME FROM FTP STAGING DIRECTORY
#FILE NAME FORMAT IS (in lower case):
#      <client name>.<monyyyy>.<mmddyyyy>.dat.<yyyymmddhhmmss>
#=================================================================
RETCODE=0

echo " "
echo " "
echo "Starting $(basename $0) - `date +'%b %d, %Y %H:%M:%S'`" 
echo " "


  export OLD_DATAFILE=`head -1 $DATA_FILE_NAME_FILE`
  echo "old_datafile " $OLD_DATAFILE >>$LOG_FILE
  
  export DATAFILE="`echo $OLD_DATAFILE | cut -f1-2 -d "."`"
  echo "datafile " $DATAFILE >>$LOG_FILE

. $SCRIPT_DIR/dbenv.ksh

#===================================================================
#EXTRACTS PROCESS MONTH AND YEAR FROM INPUT FILE NAME
#===================================================================

  echo "\n" >> $LOG_FILE

  export PROCESS_MONTH_PARM_FILE="$TEMP_DATA_DIR/DFO_process_month_parm.ref"

  echo " "
  echo " "
  echo "Starting DFO_extract_procmth.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_extract_procmth.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally.." >>$LOG_FILE
     exit 1
  fi

  echo " "
  echo " "
  echo "Completing DFO_extract_procmth.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
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

  echo " "
  echo " "
  echo "Starting DFO_vldtctrl.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_vldtctrl.ksh >> $LOG_FILE

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 1
  fi

  echo " "
  echo " "
  echo "Completing DFO_vldtctrl.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
#===================================================================
#CREATE COUNT FILE CONTAINING TOTAL CLAIMS RECORD,
#TWO PERCENT OF IT AND 0 (AS SO FAR REJECTED COUNT)
#===================================================================

  echo "\n" >> $LOG_FILE

  export OUT_REJ_COUNT_REF="$TEMP_DATA_DIR/DFO_reject_count.ref"

  echo " "
  echo " "
  echo "Starting DFO_crtecount.pl - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_crtecount.pl         \
           $IN_DATA_FILE               \
           $OUT_REJ_COUNT_REF          \
        >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 2
  fi

  echo " "
  echo " "
  echo "Completing DFO_crtecount.pl - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
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

  echo " "
  echo " "
  echo "Starting DFO_convert.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_convert.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then

     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 3

  fi

  echo " "
  echo " "
  echo "Completing DFO_convert.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
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

  echo " "
  echo " "
  echo "Starting DFO_vldtctrl_batch.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_vldtctrl_batch.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 4
  fi

  echo " "
  echo " "
  echo "Completing DFO_vldtctrl_batch.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"


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

  echo " "
  echo " "
  echo "Starting DFO_extract_4.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_extract_4.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 5
  fi
  echo " "
  echo " "
  echo "Completing DFO_extract_4.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"

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


  echo " "
  echo " "
  echo "Starting DFO_srtformt.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_srtformt.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 7
  fi

  echo " "
  echo " "
  echo "Completing DFO_srtformt.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"



#===================================================================
#SORT CLAIMS RECORD BY NABP ID/FILL DATE/NEW REFILL CODE/RX NUMBER
#IN ASCENDING ORDER
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.claims.srtbykey"

  echo "sort file "  >> $LOG_FILE
  echo OUT_DATA_FILE >> $LOG_FILE

  echo " "
  echo " "
  echo "Starting DFO_sortby_voidkey.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_sortby_voidkey.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 6
  fi

  echo " "
  echo " "
  echo "Completing DFO_sortby_voidkey.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"

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

  $SCRIPT_DIR/DFO_eliminate_duplicates.ksh >>$LOG_FILE 2>&1

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

  echo " "
  echo " "
  echo "Starting DFO_elimdup1.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_elimdup1.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 7
  fi

  echo " "
  echo " "
  echo "Completing DFO_elimdup1.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"

#===================================================================
#SORT CLAIMS RECORD BY CLIENT ID (processor nbr & group nbr)/FILL DATE
#IN ASCENDING ORDER
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.claims.srtbycltFilldt"

  echo "sort file "  >> $LOG_FILE
  echo OUT_DATA_FILE >> $LOG_FILE

  echo " "
  echo " "
  echo "Starting DFO_sortby_cltfildt.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_sortby_cltfildt.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 6
  fi

  echo " "
  echo " "
  echo "Completing DFO_sortby_cltfildt.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
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


  echo " "
  echo " "
  echo "Starting DFO_validate.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_validate.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 7
  fi

  echo " "
  echo " "
  echo "Completing DFO_validate.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
#===================================================================
#SORT CLAIMS RECORDS BY NDC ID/FILL DATE IN ASCENDING ORDER
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.validate.sortbyndc"

  echo " "
  echo " "
  echo "Starting DFO_sortby_ndc.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_sortby_ndc.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 8
  fi

  echo " "
  echo " "
  echo "Completing DFO_sortby_ndc.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
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

  echo " "
  echo " "
  echo "Starting DFO_getnhutp.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_getnhutp.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 
  fi

  echo " "
  echo " "
  echo "Completing DFO_getnhutp.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
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

  echo " "
  echo " "
  echo "Starting DFO_sortby_filldt.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
     $SCRIPT_DIR/DFO_sortby_filldt.ksh >>$LOG_FILE 2>&1

     if [[ $? != 0 ]] then
        echo "Process terminated abnormally..." >>$LOG_FILE
        exit 10
     fi

  echo " "
  echo " "
  echo "Completing DFO_sortby_filldt.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
  else

     OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.getnhutp.sortbygrp"

  echo " "
  echo " "
  echo "Starting DFO_sortby_grp_nb.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
     $SCRIPT_DIR/DFO_sortby_grp_nb.ksh >>$LOG_FILE 2>&1

     if [[ $? != 0 ]] then
        echo "Process terminated abnormally..." >>$LOG_FILE
        exit 10
     fi

  echo " "
  echo " "
  echo "Completing DFO_sortby_grp_nb.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
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

  echo " "
  echo " "
  echo "Starting DFO_crteload_parallel_integration.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_crteload_parallel_integration.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally" >>$LOG_FILE
     exit 9
  fi
  
  echo " "
  echo " "
  echo "Completing DFO_crteload_parallel_integration.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"

  echo "\n" >> $LOG_FILE

#===================================================================
#SORT CLAIMS RECORDS BY NDC ID/FILL DATE IN ASCENDING ORDER
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$LOAD_FILE"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.sortby.inveligdt"

  echo " "
  echo " "
  echo "Starting DFO_sortby_inv_elig_dt.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_sortby_inv_elig_dt.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 8
  fi

  echo " "
  echo " "
  echo "Completing DFO_sortby_inv_elig_dt.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"
#===================================================================
#CREATE THE load file and TRIGGER FILE
#===================================================================
##  NUMBER_OF_RECS=${`wc $TEMP_DATA_DIR/$DATAFILE.sortby.inveligdt`}
##  MIN_INV_ELIG_DT=`head -1 $TEMP_DATA_DIR/$DATAFILE.sortby.inveligdt | cut -c 119-128`
##  MAX_INV_ELIG_DT=`tail -1 $TEMP_DATA_DIR/$DATAFILE.sortby.inveligdt | cut -c 119-128`	
  TIMESTAMP=`date +"%Y%m%d%H%M%S"`
  export DATA_LOAD_FILE="mda.$SCHEMA.tclaims.dat.$THIS_TIMESTAMP$THIS_PROCESS_NO"
  export DATA_LOAD_TRIGGER_FILE="mda.$SCHEMA.tclaims.trg.$THIS_TIMESTAMP$THIS_PROCESS_NO"

  echo " "
  echo " "
  echo "Starting DFO_load_integration.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_load_integration.ksh

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 8
  fi

  echo " "
  echo " "
  echo "Completing DFO_load_integration.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"

# store dir for this run for monthly cleanup before next run
  print "${TEMP_DIR}"> $CLIENT_DIR/last_temp_dir

##  ftping is not needed since we will be running on DB server
##  left code as a place holder if process is moved off db server
##  $SCRIPT_DIR/DFO_ftp_to_dwhtest1.ksh >>$LOG_FILE 2>&1
##  $SCRIPT_DIR/DFO_ftp_to_tsmnim1.ksh >>$LOG_FILE 2>&1
##  FTP_STATUS=$?

##  copy the load file instead of FTP it since on same box
  cp -p $DATA_LOAD_DIR/$DATA_LOAD_FILE $DBA_DATA_LOAD_DIR
  COPY_STATUS=$?
  cp -p $DATA_LOAD_DIR/$DATA_LOAD_TRIGGER_FILE.ok $DBA_DATA_LOAD_DIR
  COPY_OK_STATUS=$?

  if [[ $COPY_STATUS != 0 ]]; then
     echo "problems copying load file $DATA_LOAD_DIR/$DATA_LOAD_FILE to $DBA_DATA_LOAD_DIR " >> $LOG_FILE
     RETCODE=1
#6014329     FTP_STATUS=909
  fi

  if [[ $COPY_OK_STATUS != 0 ]]; then
     echo "problems copying .OK file $DATA_LOAD_DIR/$DATA_LOAD_TRIGGER_FILE.ok to $DBA_DATA_LOAD_DIR " >> $LOG_FILE
     RETCODE=1
  else

##      all copies worked ok!
#6014329        FTP_STATUS=222
     RETCODE=0
  fi

# 222 is a good return from FTP kornshell... test for dba load script status
#6014329  
if [[ $RETCODE = 0 ]]; then

    #   informative email to track progress
    echo    "Load Processing for $CLIENT_NAME is starting:"   \
          "\nCopy of load file to DBA Dir $DBA_DATA_LOAD_DIR was good."        \
          "\nfollow progress in $LOG_FILE" > $MAILFILE

    MAIL_SUBJECT="DFO DB load PROCESS Starting"
    $SCRIPT_DIR/mailto_IS_group.ksh

    echo " "
    echo " "
    echo "Starting DFO_load_tclaims_integration.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
    echo " "
    $SCRIPT_DIR/DFO_load_tclaims_integration.ksh >>$LOG_FILE 
  
    DBA_AUTOLOAD_RETURN_CD=$?

    echo " "
    echo "Return code from DFO_load_tclaims_integration.ksh = "$DBA_AUTOLOAD_RETURN_CD >>$LOG_FILE 
    echo " "
    echo "Completing DFO_load_tclaims_integration.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
    echo "============================================================"

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

    if [[ $DBA_AUTOLOAD_RETURN_CD -lt 150 ]]; then

        #        only if DBA load process has no errors will we get here

        #        notify the DFO support pager that processing complete for client

        echo "email notifying DFO support that processing completed" >> $LOG_FILE               
        print "LOAD Processing for $CLIENT_NAME has finished. " > $MAILFILE

        MAIL_SUBJECT="DFO PROCESS TCLAIM TABLE LOAD ended"
        $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1

        #        clean up the staging area since we're done, we no longer need the input
        #        file, anyways it's in $CLIENT_DIR/compressed_ftp_claims
        
        rm $STAGING_DIR/*$CLIENT_NAME*

        if [[ $? != 0 ]]; then
            echo "problems removing $STAGING_DIR " >> $LOG_FILE
        fi

#6014329 Removed call to DFO_chk_all_clts_complete.ksh - no longer any clients other than first health, no runstatus.

#6014329 Removed call to DFO_ftp_to_dalcdcp.ksh script because the DNS used in script is no longer resolved

#6014329 Removed call to DFO_handle_duplicates.ksh

        #  This kornshell will sent the rejects to the client,
        #  store this concatenated rejected file in 
        #  $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.rejects
        #  and send out a summary for this client to internal
        #  Caremark personel with intake/rejected/accepted counts

        echo " "
        echo " "
        echo "Starting DFO_handle_rejects_integration.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
        echo " "
        $SCRIPT_DIR/DFO_handle_rejects_integration.ksh $CLIENT_NAME $TEMP_DATA_DIR >>$LOG_FILE 

        if [[ $? != 0 ]]; then
            echo "Process terminated abnormally..." >>$LOG_FILE
            exit 8
        fi

        echo " "
        echo " "
        echo "Completing DFO_handle_rejects_integration.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
        echo "============================================================"
        
    else 
        #DBA_AUTOLOAD_RETURN_CD was -ge 150, bad.
        print " " >> $LOG_FILE
        print "Error found when validating DBA.LOADS entry." >> $LOG_FILE

        print "investigate dba load process... problems" \
           "for client $CLIENT_NAME " \
           "\n\nLog File = $LOG_FILE " > $MAILFILE
 
        MAIL_SUBJECT="DBA autoloader has problems"
        $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>$1  

        print "Exiting process abnormally" >> $LOG_FILE
        print " " >> $LOG_FILE
        exit $DBA_AUTOLOAD_RETURN_CD
    fi
#6014329 added else, mail, and exit
else

    print "Copy of files to DBA load library failed." > $MAILFILE

    MAIL_SUBJECT="DFO Data file copy to DBA Dir failed"
    $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1
    exit $RETCODE
fi      

# compress backed up load file in local directory 

  echo " "
  echo " "
  echo "Starting DFO_compress_file.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo " "
  $SCRIPT_DIR/DFO_compress_file.ksh         \
       $DATA_LOAD_DIR/$DATA_LOAD_FILE   \
       >$LOG_FILE.compression.log7 2>&1 &

  if [[ $? != 0 ]]; then
     echo "Process terminated abnormally" >>$LOG_FILE
     exit 9
  fi
  
  echo " "
  echo " "
  echo "Completing DFO_compress_file.ksh - `date +'%b %d, %Y %H:%M:%S'`" 
  echo "============================================================"


  echo "\n***********************************************"   >> $LOG_FILE
  echo "VALIDATION FOR CLIENT $CLIENT_NAME ENDED."           \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE

echo " "
echo " "
echo "Completing $(basename $0) - `date +'%b %d, %Y %H:%M:%S'`" 
echo "============================================================"

#6024329 - some cleanup of logs
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log1 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log2 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log3 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log4 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log5 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log6 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log7 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log8 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log9 $LOG_DIR/DFO_claim_load_logs_old
# successful run, so can move log file
cp -f $LOG_FILE $LOG_DIR/DFO_claim_load_logs_old

if [[ $DBA_AUTOLOAD_RETURN_CD -ge 142 ]]; then
    #force abend, investigation needed.  If all was deemed OK, then at least logic since
    #  the 142 return code was run.  If not, then full rerun.
    print " "  >> $LOG_FILE
    print " "  >> $LOG_FILE
    print "There was an error in the LOAD - duplicates or rejected records.  This needs to be investigated. "  >> $LOG_FILE
    print "If deemed not to be a problem, then no rerun is necessary, rest of DFO logic ran." >> $LOG_FILE
    print "Otherwise can rerun from top by renaming the backup file in /GDX/prod/dfoftp directory as stated in email." >> $LOG_FILE
    print " "  >> $LOG_FILE
    print " "  >> $LOG_FILE
    return $DBA_AUTOLOAD_RETURN_CD
fi

#6024329 - some cleanup of logs
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log1 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log2 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log3 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log4 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log5 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log6 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log7 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log8 $LOG_DIR/DFO_claim_load_logs_old
mv -f $LOG_DIR/DFO_FIRSTHEALTH_*.log.compression.log9 $LOG_DIR/DFO_claim_load_logs_old
# successful run, so can move log file
mv -f $LOG_FILE $LOG_DIR/DFO_claim_load_logs_old


   return 
