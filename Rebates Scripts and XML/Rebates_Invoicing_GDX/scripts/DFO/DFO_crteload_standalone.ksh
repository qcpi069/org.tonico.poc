#!/usr/bin/ksh
echo "Creating Load Jan2005 file suffix ......"
  
#===================================================================
#echo "input crteload file name WJPWJP: "
#echo $IN_DATA_FILE.$SPLIT_SUFFIX
#echo "output crteload file name : "
#echo $OUT_DATA_FILE.$SPLIT_SUFFIX
#echo $LOAD_FILE.$SPLIT_SUFFIX

###  dd_ICLMS="/vradfo/prod/temp/T20050204004210_P23444/dat/FIRSTHEALTH.JAN2005.getnhutp.sortbygrp"
  dd_ICLMS="/vradfo/prod/temp/T20050204004210_P23444/dat/GETNHUTP.SRTBYGRP.short"
  dd_IREJC="/vradfo/prod/temp/T20050204004210_P23444/dat/DFO_reject_count.getnhutp.ref"
  dd_IPRCMTH="/vradfo/prod/temp/T20050204004210_P23444/dat/DFO_process_month_parm.ref"
  dd_IEREF="/vradfo/prod/control/reffile/DFO_error_desc_index.ref"
  dd_ICCON="/vradfo/prod/temp/T20050204004210_P23444/dat/DFO_client_contract_info.ref"
  dd_OCLMS="/vradfo/prod/temp/T20050204004210_P23444/dat/Jan2005_crteload.good"
  dd_OLOAD="/vradfo/prod/temp/T20050204004210_P23444/dat/Jan2005_crteload.load"
  dd_OREJ="/vradfo/prod/temp/T20050204004210_P23444/dat/Jan2005_crteload.rejects"
  dd_OWARN="/vradfo/prod/temp/T20050204004210_P23444/dat/Jan2005_crteload.warn"
  dd_OLOG="/vradfo/prod/temp/T20050204004210_P23444/dat/Jan2005_crteload.log"
  dd_OREJC="/vradfo/prod/temp/T20050204004210_P23444/dat/DFO_reject_count.crteload.ref"
  
  export dd_ICLMS dd_IREJC dd_IPRCMTH dd_IEREF dd_ICCON dd_OCLMS dd_OLOAD dd_OREJ dd_OWARN dd_OLOG dd_OREJC
  
  cobrun '/vradfo/prod/exe/crteload.int' 
  
#===================================================================

  echo "`date +'%b %d, %Y %H:%M:%S'`:Load file Jan2005 1st health re-entered claims "  \
       "successfully created......."
