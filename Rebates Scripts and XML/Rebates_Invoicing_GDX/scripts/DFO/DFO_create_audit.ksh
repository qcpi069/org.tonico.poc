#!/usr/bin/ksh

  echo "Creating Audit file from contract database..."

  $SCRIPT_DIR/DFO_create_audit.pl      \
          $CONTRACT_FILE               \
          $CONTRACT_AUDIT_FILE

  echo "Done......"
