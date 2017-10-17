#!/usr/bin/ksh

echo "Incentive Type Code addition PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Adding ITC code field..."

#===================================================================

  dd_IVRA1="/vracobol/prod/weekly/claims/int/wkly.clms.20040614013322"
##  dd_IVRA1="/vracobol/prod/weekly/claims/int/test.claims" 
  dd_IDATE="/vracobol/prod/control/reffile/override/billg_end_dt.ref"
  dd_OVRA1="/vracobol/prod/temp/testing/load_file"
  dd_OERR1="/vracobol/prod/temp/testing/error_file"
  dd_ONRBT="/vracobol/prod/temp/testing/nonrebate_claims"
  export dd_IVRA1 dd_IDATE dd_OVRA1 dd_OERR1 dd_ONRBT
   
  cobrun '/vracobol/prod/exe/dwmda002.int' > /vracobol/prod/log/try.logging

  grep times /vracobol/prod/log/try.logging > /vracobol/prod/log/SBO_audit

  echo "Claims load records were created..."
  echo "Process Successful."
  echo "ITC PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
  
