#!/usr/bin/perl

  my $date;
  my $time;
  my $user_id;
  my $client_id;
  my $pymt_rate;
  my $pymt_type;
  my $contract_id;
  my $row_boundary;
  my $contract_eff_date;
  my $contract_exp_date;
  my $processing_client;
  my $rebate_max_days;
  my $contract_ref_file;
  my $contract_audit_file;

  $contract_ref_file  = shift @ARGV;
  $contract_audit_file   = shift @ARGV;

  @ARGV = $contract_audit_file;

  $row_boundary = "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 10;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 10;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 9;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 10;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 10;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 9;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 15;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 4;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 4;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 8;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 10;
  $row_boundary = $row_boundary . "|";
  $row_boundary = $row_boundary . sprintf "%s", "-" x 8;
  $row_boundary = $row_boundary . "|";

  $^I = ".bak";

  while (<>) {
     if ( s/^\s*(=+)/$row_boundary/ ) {
        chomp;
     }
    print;
  }

  open CONTRACT_AUDIT_FILE, ">>$contract_audit_file" or
    die "ERROR: Cannot open file $contract_audit_file ($!)\n";

  chomp($today = `date +"%Y-%m-%d"`);

  $record = `head -1 $contract_ref_file`  ;
  @fields = split ":", $record;
    
  $processing_client = sprintf "%10s", "meijer";
  $client_id         = sprintf "%9d", $fields[1];
  $contract_eff_date = $fields[3];
  $contract_exp_date = $fields[4];
  $contract_id       = sprintf "%9d", $fields[6];
  $pymt_rate         = sprintf "%15.5f", $fields[7];
  $pymt_type         = sprintf "%4d", $fields[8];
  $rebate_max_days   = sprintf "%4d", $fields[2];
  $user_id           = sprintf "%8s", $fields[9];
  $date              = sprintf "%10s", $fields[10];
  $time              = sprintf "%8s", $fields[11];
  
  $data = "|$today|$processing_client|$client_id|$contract_eff_date|$contract_exp_date|$contract_id|$pymt_rate|$pymt_type|$rebate_max_days|$user_id|$date|$time|";
  print CONTRACT_AUDIT_FILE "\n$data";

  $data = sprintf "%s", "=" x 118;
 
  print CONTRACT_AUDIT_FILE "\n $data";
