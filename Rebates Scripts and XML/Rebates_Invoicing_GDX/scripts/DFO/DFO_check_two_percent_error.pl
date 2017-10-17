#!/usr/bin/perl

$in_rej_count_ref     = shift @ARGV;
$total_rejected_count = shift @ARGV;

$data = `head -1 $in_rej_count_ref`;

if ($data =~ /(TWO PERCENT=)(\d+.\d+)(\s+)(REJECTED SO FAR=)(.*)/) {

  $two_percent = $2;

} else {

   print "\n Error encountered in two percent check";
   print "\nin DFO_check_two_percent_error.pl  script";

   exit 2;

}

if ($total_rejected_count > $two_percent) {

      print "\nin PL 2% error";
      exit 1;

}
