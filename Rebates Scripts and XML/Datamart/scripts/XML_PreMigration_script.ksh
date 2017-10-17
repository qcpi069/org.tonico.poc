#!/bin/ksh
# Parameters    :
#                1 Region  --  DEV/SIT/PROD
#                2 Stage Directory 
#                3 File Type -- XML in lower case
# DEV1 /cm/software/appl/env_dev1/staging/AZ_REBATES_APPS_DATAMART ksh

env=$1
stg_dir=$2
trg_dir="$stg_dir/scripts/xml"

mkdir $trg_dir


if [[ $3 = 'xml' ]] then 

for file in `find $stg_dir  -name '*.xml'`
do
  mv $file $trg_dir
done
fi

if [[ $? != 0 ]]; then
 print "Error while moving xml file to live directory" 
fi