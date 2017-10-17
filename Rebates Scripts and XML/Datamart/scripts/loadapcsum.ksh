#!/usr/bin/ksh

#
# load a quarter of summary data from sql server into udb
#


#
# startup
#
  . `dirname $0`/Common_RPS_Environment.ksh


export PERIOD_ID=$1
export RETCODE=0 

echo $SCRIPT " start time: "`date` " for period " $PERIOD_ID  

export PERIOD_ID=2004Q1
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $PERIOD_ID $XML_PATH/dm_calc_apc_sum.xml                               
  export RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for period " $PERIOD_ID 
fi

export PERIOD_ID=2004Q2
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $PERIOD_ID $XML_PATH/dm_calc_apc_sum.xml                               
  export RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for period " $PERIOD_ID 
fi

export PERIOD_ID=2004Q3
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $PERIOD_ID $XML_PATH/dm_calc_apc_sum.xml                               
  export RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for period " $PERIOD_ID 
fi

export PERIOD_ID=2004Q4
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $PERIOD_ID $XML_PATH/dm_calc_apc_sum.xml                               
  export RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for period " $PERIOD_ID 
fi

export PERIOD_ID=2005Q1
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $PERIOD_ID $XML_PATH/dm_calc_apc_sum.xml                               
  export RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for period " $PERIOD_ID 
fi

export PERIOD_ID=2005Q2
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $PERIOD_ID $XML_PATH/dm_calc_apc_sum.xml                               
  export RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for period " $PERIOD_ID 
fi

export PERIOD_ID=2005Q3
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $PERIOD_ID $XML_PATH/dm_calc_apc_sum.xml                               
  export RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for period " $PERIOD_ID 
fi

export PERIOD_ID=2005Q4
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $PERIOD_ID $XML_PATH/dm_calc_apc_sum.xml                               
  export RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for period " $PERIOD_ID 
fi

export PERIOD_ID=2006Q1
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $PERIOD_ID $XML_PATH/dm_calc_apc_sum.xml                               
  export RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for period " $PERIOD_ID 
fi





echo $SCRIPT " end time: "`date`                                      

exit 0

