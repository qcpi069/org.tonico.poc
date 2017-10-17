#!/usr/bin/ksh

echo "LOAD STAGING PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Copying load file $TEMP_DATA_DIR/$DATAFILE.crteload.load" \
     "\nto $DATA_LOAD_DIR/$DATA_LOAD_FILE.."

cp -p $TEMP_DATA_DIR/$DATAFILE.crteload.load $DATA_LOAD_DIR/$DATA_LOAD_FILE
cp $DATA_LOAD_DIR/$DATA_LOAD_FILE $DBA_DATA_LOAD_DIR

echo "Load file was copied.."

echo "Creating OK file $DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE.ok.."
touch $DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE.ok
echo "OK file was created.."

echo "Process Successful."
echo "LOAD STAGING PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
