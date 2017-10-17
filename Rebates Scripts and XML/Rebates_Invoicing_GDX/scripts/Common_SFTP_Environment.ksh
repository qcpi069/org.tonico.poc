
#!/bin/ksh
#-------------------------------------------------------------------------#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-27-2017 qcpvg80a    Variables for Gateway Health
# 04-03-14   qcpi733     Removed GDX_ENV_SETTING to determine REGION;
#                        ITPR005898-modified variable SECURE_PATH and put
#                        it inside the AETNA case logic, changed from /
#                        to /client/ant591.
# 12-20-12   qcpue98u    Initial Creation.
#
#-------------------------------------------------------------------------#

CORP=$1

export GDX_PATH=/GDX/$REGION
export SCRIPT_PATH=$GDX_PATH/scripts
export LOG_PATH=$GDX_PATH/log
export OUT_PATH=$GDX_PATH/log

export REBATE_PATH="/GDXReports/Rebates"
export SECURE_PATH="/"


case $CORP in

AETNA)

export REBATE_PATH="$REBATE_PATH/Aetna"
export SECURE_PATH="/client/ant591"

### PLAN SPONSOR REPORTS DIRECTORY
export PLN_SP_DEST=$SECURE_PATH/Plan_Sponsor
export PLN_SP_STG=$REBATE_PATH/PlanSponsor
export PLN_SP_ARCH=$PLN_SP_STG/archive

### MANUFACTURER NCPDP DIRECTORY
export MAN_NCPDP_DEST=$SECURE_PATH/Manufacturer_NCPDP
export MAN_NCPDP_STG=$REBATE_PATH/Manufacturer_NCPDP
export MAN_NCPDP_ARCH=$MAN_NCPDP_STG/archive


### MANUFACTURER REBATE DIRECTORY
export MAN_REB_DEST=$SECURE_PATH/Manufacturer_Rebate
export MAN_REB_STG=$REBATE_PATH/Manufacturer_Rebate
export MAN_REB_ARCH=$MAN_REB_STG/archive


### Business TEAM REPORTS DIRECTORY
export BUS_RPT_DEST=$SECURE_PATH/Business_Team
export BUS_RPT_STG=$REBATE_PATH/Business_Team
export BUS_RPT_ARCH=$BUS_RPT_STG/archive


### INVOICE TEAM REPORTS DIRECTORY
export INV_RPT_DEST=$SECURE_PATH/Invoicing_Team
export INV_RPT_STG=$REBATE_PATH/Invoicing_Team
export INV_RPT_ARCH=$INV_RPT_STG/archive

### Standard REPORTS DIRECTORY
export STD_RPT_DEST=$SECURE_PATH/Standard_Reports
export STD_RPT_STG=$REBATE_PATH/Standard_Reports
export STD_RPT_ARCH=$STD_RPT_STG/archive

### Invoice Extract DIRECTORY
export IEX_RPT_DEST=$SECURE_PATH/Invoice_Extract
export IEX_RPT_STG=$REBATE_PATH/Invoice_Extract
export IEX_RPT_ARCH=$IEX_RPT_STG/archive

;;

GHP)

export REBATE_PATH="$REBATE_PATH/GHP"
export SECURE_PATH="/client/jnt404/IT_TradeRelations"

### Gateway Destination DIRECTORY
export GHP_RPT_DEST=$SECURE_PATH/Outbound
export GHP_RPT_STG=$REBATE_PATH/Frm_CVS_To_GHP
export GHP_RPT_ARCH=$GHP_RPT_STG/archive
;;

esac

