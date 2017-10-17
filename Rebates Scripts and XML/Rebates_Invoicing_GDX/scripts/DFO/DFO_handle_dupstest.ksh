#!/usr/bin/ksh

#########################################################################
#SCRIPT NAME : DFO_handle_duplicates.ksh                                #
#                                                                       #
#PURPOSE     :                                                          #
#                                                                       #
#INSTRUCTIONS: This script takes a command line argument for the        #
#              CLIENT-NAME.  It then processes the duplicates, if they  #
#              exist. These duplicates are read from the                #
#              TCLAIM_EXT_EXCP table.  A report of the duplicates are   #
#              then stored in the $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.  #
#              An email of these rejects are sent to the current Client #
#              Once completed, the duplicates are inserted to the BILL  #
#              table.  Next, delete the duplicate rows from the         #
#              TCLAIM_EXT_EXCP table for the next run.  The count rows  #     
#              in the table to confirm the "delete" worked.             #
#                                                                       #
#                                                                       #
#CALLS       :                                                          #
#                                                                       #
#RETURNS VALUES: 
# 
#  return code values and meanings for "DFO_handle_duplicates.ksh"
#  
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        Jim Frieling   08/27/2003  Initial Release                    #
#                                                                           #
#############################################################################

# These are variables to be removed after testing

  export HOME_DIR="/vradfo/test"
  export REF_DIR="$HOME_DIR/control/reffile"
  export TEMP_DIR="/vradfo/test/temp/testing"
  export CLIENT_DIR="/vradfo/test/clients/frsthlth" 
  export LOG_FILE="$CLIENT_DIR/dupsexcp.log"
  export UNIQUE_RUN_ID="P0919"   
  export REPORT_FILE="$CLIENT_DIR/rejected/$UNIQUE_RUN_ID.duplicates"
  export PROCESS_MONTH="SEPT"
  export PROCESS_YEAR="2003"
  export MAILFILE="$TEMP_DIR/jimmailfile"
  export UNIQUE_RUN_ID="P0919"

  export MAIL_SUBJECT="Duplicate Exceptions in Subject Line"
  export SCRIPT_DIR="$HOME_DIR/script"

#
#   These are the declared variables
#
INSERTSQL=$CLIENT_DIR/insertsql.log
COUNT_FILE=$CLIENT_DIR/countsql.log
DB_NAME="udbmdap" 
CLAIMS_USER="claims3"
CLAIMS_PASSWORD_FILE="$REF_DIR/claims3_password.ref"
CLAIMS_PASSWORD=$(< $CLAIMS_PASSWORD_FILE)
EXCEPTION_TABLE=vrap.tclaim_ext_excp
EXCEPTION_DUP_TABLE=claims3.tclaim_ext_excp_bill 
#
#     This is the SQL to select any duplicates rows from the 
#     exception table.
#
SELECT_EXCP="select NABP_ID, FILL_DT, RX_NB, REFILL_NB, SEQ_NB, VOID_IN, BILLG_END_DT, CLT_ID, DRUG_NDC_ID, NHU_TYP_CD, DSPNSD_QTY, DAY_SPLY_QTY, DLVRY_SYS_CD, ITEM_COUNT_QY, DRUG_AWP_PRC, PROV_ZIP_CD, VNDR_REBT_LOAD_DT, CLT_MNEMNC_CD, PROV_DEA_NB, PB_ID, NET_COST_AT, MEMBER_COST_AT, FORMULARY_ID, PRIM_SECD_COV_CD, INCENTIVE_TYPE_CD, TYP_FIL_CD, CLT_PLAN_TYPE, CLT_PLAN_ID_TX from vrap.tclaim_ext_excp"
#
#     This is the SQL to count if any rows exist after a "Delete"
#
   SELCOUNT_EXCP="select count (*) from vrap.tclaim_ext_excp"
#
#     This code removes the insert sql and the select count 
#     sql response files.
#
   rm $INSERTSQL $COUNT_FILE
# 
#     This code verifies that the Client Name has been passed
#     to the program.
#

if [[ $1 != " " ]]          
   then
     export CLIENT_NAME=$1
     echo $CLIENT_NAME >> $LOG_FILE

#
#      This is the logic to connect to the database
#

    db2 "connect to $DB_NAME user " $CLAIMS_USER " using " $CLAIMS_PASSWORD  >> $LOG_FILE 2>>$LOG_FILE

#
#      Store exceptions in report $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.duplicates 
#
   db2 $SELECT_EXCP >$REPORT_FILE 2>>$LOG_FILE
#
#     This code is confusing.  It checks if any records were selected.
#     If "DUPCOUNT" equals 0 the grep did not find "0 record(s) selected.
#     This means records were found as duplicates and should be inserted
#     into the "Bill" table.
#

   DUPCOUNT=`grep -c '0 record(s) selected' $REPORT_FILE` 
   if [ $DUPCOUNT -eq 0 ]                   
     then                                   
       echo "ATTEMPTING INSERT TO THE BILL TABLE `date`" >> $LOG_FILE
#
#            Insert SQL for retrieval of Duplicates in Exception Table
#
       db2 "insert into $EXCEPTION_DUP_TABLE ($SELECT_EXCP)" >>$INSERTSQL 2>>$INSERTSQL
#
#            This code checks for a successful return code from the insert
#
       INSERTCNT=`grep -c 'DB20000I  The SQL command completed successfully' $INSERTSQL`
#
#            If this count is greater than zero, the successful return
#            was found and processing should continue
#
       if [ $INSERTCNT -gt 0 ]
         then
           cat $INSERTSQL >> $LOG_FILE
           echo "INSERT WAS SUCCESSFUL TO THE BILL TABLE `date`" >> $LOG_FILE

#
#             Create email of duplicates for firsthealth or current client
#
           echo "Emailing duplicate claims from TCLAIM_EXT_ECXP to $CLIENT_NAME on `date`"  >> $LOG_FILE

           echo "Below you will find the duplicate records for "        \
             "$PROCESS_MONTH $PROCESS_YEAR claims data."               \
             "\nPlease let us know if you have any questions or "      \
             "concerns by emailing William.Price@Caremark.com or "     \
             "Susan.Garfield@Caremark.com "                            \
             "\n\n\n"                                                  \
             "\n`cat $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.duplicates` " > $MAILFILE
            MAIL_SUBJECT="DUPLICATE EXCEPTIONS file for $PROCESS_MONTH $PROCESS_YEAR"
            $SCRIPT_DIR/mailto_CLIENT_group.ksh $CLIENT_NAME

#
#              Delete the duplicate rows from TCLAIM_EXT_EXCP
#
            db2 "delete from " $EXCEPTION_TABLE >>$LOG_FILE 2>>$LOG_FILE
#
#              Perform an SQL count to determine if delete worked
#
            db2 $SELCOUNT_EXCP >>$COUNT_FILE 2>>$COUNT_FILE
#
#              This code verifies that no rows were returned from the count
#  
            DELCOUNT=`grep -c '\ 0' $COUNT_FILE`              
            if [ $DELCOUNT -eq 1 ]                                              
               then 
                  echo "The COUNT returned no rows" >> $LOG_FILE  
                  RETURN_CODE=0
            else
                  echo "The COUNT returned rows and should not" >> $LOG_FILE
                  RETURN_CODE=-1
            fi  
      else
         echo "INSERT TO THE BILL TABLE WAS NOT SUCCESSFUL" >>$LOG_FILE 
         RETURN_CODE=-1
      fi
   else
        echo "No duplicate exception records found in TCLAIM_EXT_ECXP for $CLIENT_NAME on `date`"  >>$LOG_FILE
#
#             End the if statement "Records were found in the Duplicate Table"
#
        RETURN_CODE=-1 
   fi
#
#             Disconnect from the Database
#
   db2 connect reset>/dev/null 2>/dev/null

else                                                         
   echo "No Client Parameter Exists on `date`" >> $LOG_FILE 
   RETURN_CODE=-1
fi                                                           
echo "Return Code = " $RETURN_CODE >>$LOG_FILE
return $RETURN_CODE 
