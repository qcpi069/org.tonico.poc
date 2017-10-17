#!/usr/bin/ksh

typeset -i Load_Return_Code=23
export Load_Return_Code   

echo "load return code: " $Load_Return_Code
      /vracobol/prod/script/MDA_load_tclaims_test.ksh >>/vracobol/prod/log/temp_rtn_cd.log 
     

      DBA_AUTOLOAD_RETURN_CD=$?
      echo "global Load_Return_Code: " $Load_Return_Code >>/vracobol/prod/log/temp_rtn_cd.log 
  
      echo "dba load ksh return code: ${DBA_AUTOLOAD_RETURN_CD} " >>/vracobol/prod/log/temp_rtn_cd.log
     
exit 
