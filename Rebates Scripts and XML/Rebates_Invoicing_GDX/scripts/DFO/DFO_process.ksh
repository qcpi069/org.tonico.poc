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


#================================================
#ACCEPTS ONE COMMAND LINE PARAMETER.
#================================================

  if [[ $# != 1 ]] then
     echo "Usage DFO_process.ksh <CLIENT NAME>"
     exit 1
  fi

  export CLIENT_NAME=`echo $1 | tr '[A-Z]' '[a-z]'`

#================================================
#EXECUTE DFO TEST PROFILE.
#THIS PROFILE DEFINES VARIOUS REQUIRED VARIABLES
#AND EXPORTS THEM FOR CHILD PROCESSES TO USE.
#================================================

  . /vradfo/test/script/DFO_test_profile

#================================================
#CHECKS IF CLIENT DIRECTORY EXISTS.
#IF NOT, CREATES IT.
#================================================

  echo "***********************************************"   >> $LOG_FILE
  echo "DFO VALIDATION STARTS FOR CLIENT: $CLIENT_NAME"    \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE

  if [[ ! -d $CLIENT_DIR ]] then

     echo "Client directory has not been created for $CLIENT_NAME." \
          "Creating directories for it." >> $LOG_FILE

     mkdir -p $CLIENT_DIR
   
  fi

#=================================================================
#GETS FILE NAME FROM FTP STAGING DIRECTORY
#FILE NAME FORMAT IS (in lower case):
#      <client name>.<monyyyy>.<mmddyyyy>.dat.<yyyymmddhhmmss>
#=================================================================

  $SCRIPT_DIR/DFO_get_datafile.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 1
  fi

  export OLD_DATAFILE=`head -1 $DATA_FILE_NAME_FILE`

  export DATAFILE="`echo $OLD_DATAFILE | cut -f1-2 -d "."`"

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
#VALIDATE CLAIMS FIELDS
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$OUT_DATA_FILE"
  export IN_REJ_COUNT_REF="$OUT_REJ_COUNT_REF"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/$DATAFILE.validate.good"
  export BAD_FILE="$TEMP_DATA_DIR/$DATAFILE.validate.reject"
  export DATA_LOG_FILE="$TEMP_DATA_DIR/$DATAFILE.validate.log"
  export OUT_REJ_COUNT_REF="$TEMP_DATA_DIR/DFO_reject_count.validate.ref"

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

exit 0
  $SCRIPT_DIR/clean_up.ksh >>$LOG_FILE 2>&1

  $SCRIPT_DIR/DFO_create_audit.ksh >>$LOG_FILE 2>&1

  echo "\n***********************************************"   >> $LOG_FILE
  echo "VALIDATION FOR CLIENT $CLIENT_NAME ENDED."           \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE

  cat $LOG_FILE >> $MASTER_LOG

#  if [[ $? = 0 ]] then
#     rm -f $LOG_FILE
#  fi
