#-------------------------------------------------------------------------#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02-20-05   qcpi768     Initial Creation.
#
#-------------------------------------------------------------------------#

function CME_ucase
#  usage: CME_ucase $var, returns uppercase value of $var without changing $var
{
  return `echo $1 |tr [a-z] [A-Z]`
}

function CME_Get_File_Linecount
#   usage: CME_Get_File_Linecount |filename|, returns CME_WCCOUNT and return code 
{
  print `date` ' Getting linecount for file ' $1  >> $LOG_FILE
  export CME_WCCOUNT=0
  if [[ $1 = "" ]] ; then
      print `date` ' !!! ERROR calling function CME_Get_File_Linecount - no file name passed by caller ' >> $LOG_FILE
      return $CME_FATAL_ERROR
  fi
  typeset RC
  CME_WCCOUNT=$(wc -l < $1)
  RC=$?
  if [[ $RC != 0 ]] ; then
      print `date` ' !!! ERROR calling function CME_Get_File_Linecount - wc command returned code ' $RC ' for file ' $1  >> $LOG_FILE
      return $CME_FATAL_ERROR
  fi
  return $CME_SUCCESS
}


function CME_Get_db2_Import_Results
#   usage: CME_Get_db2_Import_Results |filename|, returns DB_ROWS_* and return code
{
  print `date` ' Checking db2 import results from file ' $1  >> $LOG_FILE
  DB_ROWS_READ=0
  DB_ROWS_SKIPPED=0
  DB_ROWS_INSERTED=0
  DB_ROWS_UPDATED=0
  DB_ROWS_REJECTED=0 
  DB_ROWS_COMMITTED=0
  typeset T1 T2 T3 T4 T5 T6
  if [[ $1 = "" ]] ; then
      print `date` ' !!! ERROR calling function CME_Get_db2_Import_Results - result file name not passed by caller ' >> $LOG_FILE
      return $CME_FATAL_ERROR
  fi
  if [[ ! -r $1 ]] ; then
      print `date` ' !!! ERROR calling function CME_Get_db2_Import_Results - result file ' $1 ' does not exist or is unreadable ' >> $LOG_FILE
      return $CME_FATAL_ERROR
  fi
  while read T1 T2 T3 T4 T5 T6 ; do
    if [[ $T1 = "Number" ]] ; then
       case $T4 in 
          "read") export DB_ROWS_READ=$T6 ;;
          "skipped") export DB_ROWS_SKIPPED=$T6 ;;
          "inserted") export DB_ROWS_INSERTED=$T6 ;;
          "updated") export DB_ROWS_UPDATED=$T6 ;;
          "rejected") export DB_ROWS_REJECTED=$T6 ;;
          "committed") export DB_ROWS_COMMITTED=$T6 ;;
       esac
    fi
  done < $1
  return $CME_SUCCESS
}

function CME_Get_sqlldr_Import_Results
#   usage: CME_Get_sqlldr_Import_Results |filename|, returns DB_ROWS_* and return code
{
  print `date` ' Checking sqlldr import results from file ' $1  >> $LOG_FILE
  DB_ROWS_READ=0
  DB_ROWS_SKIPPED=0
  DB_ROWS_INSERTED=0
  DB_ROWS_UPDATED=0
  DB_ROWS_REJECTED=0 
  DB_ROWS_COMMITTED=0
  typeset T1 T2 T3 T4
  if [[ $1 = "" ]] ; then
      print `date` ' !!! ERROR calling function CME_Get_sqlldr_Import_Results - result file name not passed by caller ' >> $LOG_FILE
      return $CME_FATAL_ERROR
  fi
  if [[ ! -r $1 ]] ; then
      print `date` ' !!! ERROR calling function CME_Get_sqlldr_Import_Results - result file ' $1 ' does not exist or is unreadable ' >> $LOG_FILE
      return $CME_FATAL_ERROR
  fi
  while read T1 T2 T3 T4 ; do
    if [[ $T2 = "Rows" &&  $T3 = "successfully" && $T4 = "loaded." ]] ; then
      export DB_ROWS_INSERTED=$T1 ;
    fi
  done < $1
  return $CME_SUCCESS
} 

