#!/usr/bin/ksh

echo "CLEAN-UP PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."

if [[ ("$1" = "") || ("$1" = "Y") ]] then
   TO_DATA_DIR="$PROCESSED_DIR"
else
   TO_DATA_DIR="$FAILED_DIR"
fi

if [[ ! -d $TO_DATA_DIR ]] then

   mkdir -p $TO_DATA_DIR/dat
  
fi

THIS_DIR="$PWD"
cd $TEMP_DATA_DIR

CLEAN_UP_FILE="clean_up_file"

ls -1 *.reject *.warn > $CLEAN_UP_FILE 2>/dev/null

while [[ -s "$CLEAN_UP_FILE" ]]
do

  FROM_FILE_NAME=`head -1 $CLEAN_UP_FILE`

  if [[ ! -s "$FROM_FILE_NAME" ]] then
     
     rm -f $FROM_FILE_NAME

  else

    LAST_TWO_SUFFIX=`echo $FROM_FILE_NAME | cut -f3-4 -d "."`
    TO_FILE_NAME="$OLD_DATAFILE.$LAST_TWO_SUFFIX"

    echo "Moving " $PWD/$FROM_FILE_NAME "to " $TO_DATA_DIR "......"

    mv $FROM_FILE_NAME $TO_DATA_DIR/$TO_FILE_NAME

  fi

  ls -1 *.reject *.warn > $CLEAN_UP_FILE 2>/dev/null

done

cd $THIS_DIR

echo "moving data file $OLD_DATAFILE from"  \
     "$STAGING_DIR to client($CLIENT_NAME) directory $TO_DATA_DIR.."
mv $STAGING_DIR/$OLD_DATAFILE $TO_DATA_DIR/dat

echo "File was moved.."

echo "Compressing file $TO_DATA_DIR/dat/$OLD_DATAFILE......"
compress $TO_DATA_DIR/dat/$OLD_DATAFILE
echo "File was Compressed.."

echo "Deleting temporary files and directory.."
rm -rf $TEMP_DIR
echo "Temporary directory and files were deleted.."

  echo "Process Successful."
  echo "CLEAN-UP PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
