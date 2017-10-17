#!/bin/ksh
export REGION="prod"
#
export MDA_PATH=/staging/apps/rebates/$REGION
#
export INPUT_PATH=$MDA_PATH/input
export INPUT_ARCH_PATH=$INPUT_PATH/archive
#
export LOG_PATH=$MDA_PATH/log
export LOG_ARCH_PATH=$LOG_PATH/archive

export OUTPUT_PATH=$MDA_PATH/output
export OUTPUT_ARCH_PATH=$OUTPUT_PATH/archive
#
export SCRIPT_PATH=$MDA_PATH/scripts
export SCRIPT_ARCH_PATH=$SCRIPT_PATH/archive
#
export SRC_PATH=$MDA_PATH/src
export SRC_ARCH_PATH=$SRC_PATH/archive
#
export SQL_PATH=$MDA_PATH/sql 
export SQL_ARCH_PATH=$SQL_PATH/archive
#
export TMP_PATH=$MDA_PATH/tmp
#
#######################################################
#
# Phoenix MVS designations
#
#######################################################
#
export MVS_DSN=PCS.P 
export MVS_SNODE=PHXN2
#
#######################################################
#
# Generically defined Error codes
#
#######################################################
#
export CME_SUCCESS=0
export CME_MINOR=4
export CME_WARNING=8
export CME_FATAL_ERROR=12
