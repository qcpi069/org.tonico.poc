#!/usr/bin/perl

my $in_data_file  = shift @ARGV;
my $out_parm_file = shift @ARGV;

open OUT_FILE, ">$out_parm_file" or
   die "\n Cannot open file $out_parm_file ($!)\n";

my %month_no_for = ( 
     "jan" => "1", "feb" => "2", "mar" => "3", "apr" => "4",
     "may" => "5", "jun" => "6", "jul" => "7", "aug" => "8",
     "sep" => "9", "oct" => "10", "nov" => "11", "dec" => "12"
                   );

my $process_month_year = `echo "$in_data_file" | cut -f2 -d "."`;
chomp($process_month_year);

my $process_month = substr($process_month_year,0,3);
my $process_year  = substr($process_month_year,3,4);

my $process_month_digit = $month_no_for{"\L$process_month"};

if ($process_month_digit eq ""){

   die "\nInvalid month '$process_month' mentioned as part of file name \n";

}

if ( ! `cal $process_year 2> /dev/null`) {

   die "\nInvalid year '$process_year' supplied\n";

}

printf OUT_FILE "%4d-%02d-01", $process_year, $process_month_digit;
