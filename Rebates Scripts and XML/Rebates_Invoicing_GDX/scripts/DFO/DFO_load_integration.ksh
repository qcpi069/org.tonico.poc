#!/usr/bin/ksh

##SCHEMA="vrap"
##THIS_TIMESTAMP="T200506150452"
##TEMP_DATA_DIR="/vradfo/prod/temp/T20050506150052_P60024/dat"
##DATA_LOAD_DIR="/vradfo/prod/control/dataload"
##DATA_LOAD_FILE="mda.vrap.tclaims.dat.T20050506150052"
##DATAFILE="PHARMASSESS.mar2005"

 echo "LOAD STAGING PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."

 echo "Copying load file $TEMP_DATA_DIR/$DATAFILE.crteload.load" \
      "to $DATA_LOAD_DIR/$DATA_LOAD_FILE.."

 cp -p $TEMP_DATA_DIR/$DATAFILE.crteload.load $DATA_LOAD_DIR/$DATA_LOAD_FILE
## cp $DATA_LOAD_DIR/$DATA_LOAD_FILE $DBA_DATA_LOAD_DIR

 echo "Load file was copied.."

##echo "word count $TEMP_DATA_DIR/$DATAFILE.sortby.inveligdt"
 typeset -i  NUMBER_OF_RECS
 echo "`wc -l<$TEMP_DATA_DIR/$DATAFILE.sortby.inveligdt|cut -f1`"
 print "`wc -l<$TEMP_DATA_DIR/$DATAFILE.sortby.inveligdt|cut -f1`" > $TEMP_DATA_DIR/HOLD 
 NUMBER_OF_RECS=`cat $TEMP_DATA_DIR/HOLD`
 echo "NUM of Recs $NUMBER_OF_RECS"

 MAX_INV_ELIG_DT=`head -1 $TEMP_DATA_DIR/$DATAFILE.sortby.inveligdt | cut -c 122-131`
 MIN_INV_ELIG_DT=`tail -1 $TEMP_DATA_DIR/$DATAFILE.sortby.inveligdt | cut -c 122-131`

 echo "$NUMBER_OF_RECS D $MIN_INV_ELIG_DT $MAX_INV_ELIG_DT $DATA_LOAD_FILE" > $DATA_LOAD_DIR/$DATA_LOAD_TRIGGER_FILE.ok
 echo "trigger file was created.."

##done with this file, delete it
##  rm $TEMP_DATA_DIR/$DATAFILE.sortby.inveligdt

 echo "Process Successful."
 echo "LOAD STAGING PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
