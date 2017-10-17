#!/bin/ksh
  . /GDX/prod/scripts/Common_GDX_Environment.ksh
export MDAALLOCATION_PATH=/GDX/$REGION/scripts/Allocation
export INPUT_PATH=$INPUT_PATH/Allocation
export OUTPUT_PATH=$OUTPUT_PATH/Allocation
export SCRIPT_PATH=$SCRIPT_PATH/Allocation
export SQL_PATH=$SQL_PATH/Allocation 
export LOG_PATH=$LOG_PATH/Allocation
export LOG_ARCH_PATH=$LOG_PATH/archive
export TMP_PATH=$TMP_PATH/Allocation
export LOG_FATAL="FATAL"
export LOG_HARMLESS="HARMLESS"
export LOG_CRITICAL="CRITICAL"
export LOG_WARNING="WARNING"
export LOG_MINOR="MINOR"