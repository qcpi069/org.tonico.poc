#!/usr/bin/ksh

CLIENT_NAME=`echo $1 | tr '[A-Z]' '[a-z]'`
QUARTER_NO="$2"
YEAR="$3"
CLAIMS_COUNT="$4"
REJECTED_COUNT="$5"

HOME_DIR="/vradfo/prod"
SCRIPT_DIR="$HOME_DIR/script"
CLIENT_DIR="$HOME_DIR/clients/$CLIENT_NAME"
PROCESSED_DIR="$CLIENT_DIR/processed"

THIS_TIMESTAMP="T`date +"%Y%m%d%H%M%S"`"
THIS_PROCESS_NO="_P$$"

THIS_TIMESTAMP="T`date +"%Y%m%d%H%M%S"`"
THIS_PROCESS_NO="_P$$"

TEMP_DIR="$HOME_DIR/temp/$THIS_TIMESTAMP$THIS_PROCESS_NO"
mkdir -p $TEMP_DIR

REF_DIR="$HOME_DIR/control/reffile"
ERROR_DESC_FILE="$REF_DIR/DFO_error_desc_index.ref"

THIS_DIR="$PWD"
cd $PROCESSED_DIR

function get_message_from_code {

   IFS=":"
   set -- `grep $CODE $ERROR_DESC_FILE`

   if [[ -n "$4" ]] then
      MESSAGE="$4"
   else
      MESSAGE="Unknown reason of rejection code $CODE    "
   fi

}


function count_claims_records {
  
   TOTAL_CLAIMS=`cat dat/$CLIENT_NAME.$MONTH_YEAR.*dat* 2>/dev/null \
                 | grep -c "^4"`

   TOTAL_CLAIMS_REJECTED=`cat $CLIENT_NAME.$MONTH_YEAR.*reject \
                         2>/dev/null | wc -l`

   if [[ $TOTAL_CLAIMS != 0 ]] then
      echo "$MONTH_YEAR, $TOTAL_CLAIMS, $TOTAL_CLAIMS_REJECTED" \
           >> $TEMP_DIR/$CLAIMS_COUNT.$QUARTER_NO$YEAR
   fi

}


function create_rejected_summary {
  
   cat $CLIENT_NAME.${MONTH[1]}$YEAR.*reject \
       $CLIENT_NAME.${MONTH[2]}$YEAR.*reject \
       $CLIENT_NAME.${MONTH[3]}$YEAR.*reject \
       2>/dev/null | cut -c12-15 | sort | uniq -c > $TEMP_DIR/temp1

   while [[ -s $TEMP_DIR/temp1 ]]
   do
      set `head -1 $TEMP_DIR/temp1`

      NO="$1"
      CODE="$2"

      OLD_IFS=$IFS
      get_message_from_code
      IFS=$OLD_IFS

      echo "$MESSAGE, $NO" >> $TEMP_DIR/$REJECTED_COUNT.$QUARTER_NO$YEAR

      sed 1d $TEMP_DIR/temp1 > $TEMP_DIR/temp2

      cp $TEMP_DIR/temp2 $TEMP_DIR/temp1

   done
 
}


if [[ ! -d $PROCESSED_DIR ]] then

   echo $PROCESSED_DIR does not exist
   exit 2

fi

case $QUARTER_NO in

   "Q1")
   
     MONTH[1]="jan"
     MONTH[2]="feb"
     MONTH[3]="mar"
     ;;
   
   "Q2")
   
     MONTH[1]="apr"
     MONTH[2]="may"
     MONTH[3]="jun"
     ;;
   
   "Q3")
   
     MONTH[1]="jul"
     MONTH[2]="aug"
     MONTH[3]="sep"
     ;;
   
   "Q4")
   
     MONTH[1]="oct"
     MONTH[2]="nov"
     MONTH[3]="dec"
     ;;
   
   *)

     echo "Invalid Quarter $QUARTER_NO was entered."  \
          "Valid types are Q1, Q2, Q3 and Q4".
     ;;
esac

MONTH_YEAR="${MONTH[1]}$YEAR"
count_claims_records

MONTH_YEAR="${MONTH[2]}$YEAR"
count_claims_records

MONTH_YEAR="${MONTH[3]}$YEAR"
count_claims_records

create_rejected_summary

cd $THIS_DIR
#rm -rf $TEMP_DIR
