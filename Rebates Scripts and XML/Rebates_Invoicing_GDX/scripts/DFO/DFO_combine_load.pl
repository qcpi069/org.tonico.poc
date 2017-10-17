#!/usr/bin/perl

my $error_ref_file        = shift @ARGV;
my $in_reject_count_file  = shift @ARGV;
my $in_reject_file        = shift @ARGV;
my $out_reject_file       = shift @ARGV;
my $in_warn_file          = shift @ARGV;
my $out_warn_file         = shift @ARGV;
my $out_log_file          = shift @ARGV;
my $out_reject_count_file = shift @ARGV;

open IN_REJECT_COUNT_FILE, "$in_reject_count_file" or
    die "\n Cannot open input reject count file $in_reject_count_file ($!)\n";

open IN_REJECT_FILE, "$in_reject_file" or
    die "\n Cannot open input reject file $in_reject_file ($!)\n";

open OUT_REJECT_FILE, ">$out_reject_file" or
    die "\n Cannot open output reject file $out_reject_file ($!)\n";

open IN_WARN_FILE, "$in_warn_file" or
    die "\n Cannot open input warn file $in_warn_file ($!)\n";

open OUT_WARN_FILE, ">$out_warn_file" or
    die "\n Cannot open output warn file $out_reject_file ($!)\n";

open OUT_LOG_FILE, ">$out_log_file" or
    die "\n Cannot open log file $out_log_file ($!)\n";

open OUT_REJECT_COUNT_FILE, ">$out_reject_count_file" or
    die "\n Cannot open out reject count $out_reject_count_file ($!)\n";

my $reject_count_file_record;
my $two_percent_error_count;
my $previous_rejected_record_count;
my $total_rejected_record_count;
my $total_warned_record_count = 0;
my $error_message;

while (<IN_REJECT_COUNT_FILE>) {

   if (/(TWO PERCENT=)(\d+.\d+)(\s+)(REJECTED SO FAR=)(.*)/) {

      $reject_count_file_record = $_;
      $two_percent_error_count = $2;
      $previous_rejected_record_count = $5;
      $total_rejected_record_count = $previous_rejected_record_count;
      
   }

}


while (<IN_WARN_FILE>) { #Beginning of Loop

   $total_warned_record_count = sprintf "%07d", ++$total_warned_record_count;

   substr($_, 3, 7)  = $total_warned_record_count;

   print OUT_WARN_FILE "$_";

} #End of Loop


while (<IN_REJECT_FILE>) { #Beginning of Loop

   $total_rejected_record_count = sprintf "%07d", ++$total_rejected_record_count;

   substr($_, 3, 7)  = $total_rejected_record_count;

   print OUT_REJECT_FILE "$_";

   if ($total_rejected_record_count > $two_percent_error_count) {

      $error_message = "ERROR: more than 2% records rejected";
      print OUT_LOG_FILE "$error_message";
      last;

   }

} #End of Loop

$total_rejected_record_count = sprintf "%07d", $total_rejected_record_count;
$reject_count_file_record =~ s/(REJECTED SO FAR=)(.*)/$1$total_rejected_record_count/;

print OUT_REJECT_COUNT_FILE "$reject_count_file_record";
