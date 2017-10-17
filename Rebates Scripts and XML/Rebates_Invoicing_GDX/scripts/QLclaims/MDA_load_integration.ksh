#!/usr/bin/ksh

echo "LOAD STAGING PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Copying load file $TEMP_DATA_DIR/crteload.load to $DATA_LOAD_DIR/$DATA_LOAD_FILE..."

cp -p $TEMP_DATA_DIR/crteload.load $DATA_LOAD_DIR/$DATA_LOAD_FILE

echo "Load file was copied.."

## old style trigger
## new trigger contains data about the load file

## echo "Creating OK file $DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE.ok.."
## touch $DATA_LOAD_DIR/$DATA_LOAD_FILE.ok
 echo "`cat $LOAD_TRIGGER_FILE` $DATA_LOAD_FILE" > $DATA_LOAD_DIR/$DATA_LOAD_TRIGGER_FILE.ok
 echo "trigger file was created.."

echo "Process Successful."
echo "LOAD STAGING PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
