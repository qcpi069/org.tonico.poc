#!/usr/bin/ksh

echo "Incentive Type Code addition PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Adding ITC code field..."

#===================================================================

  dd_IVRA1="/vracobol/dwp.claimsp.trxclm_claims.p6.dat"
  dd_OVRA1="/vracobol/prod/temp/loadrec.p6"
  dd_OERR1="/vracobol/prod/temp/errrpt.p6"
  dd_ONRBT="/vracobol/nonrebtdir/p6.psvnrbt.dat.feb2004"
  export dd_IVRA1 dd_OVRA1 dd_OERR1 dd_ONRBT
   
  cobrun '/vracobol/prod/exe/dwmda002.int' 

#===================================================================
 
  RETURN_CODE=$?
  SCRIPT_NAME=`basename $0`

  /vracobol/prod/script/MDA_check_error.ksh $SCRIPT_NAME $RETURN_CODE $dd_OERR1   

#===================================================================

  echo "Claims load records were created..."
  echo "Process Successful."
  echo "ITC PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
  
  exit 0
