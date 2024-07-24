#!/usr/bin/perl
# Process population figures

use utf8;
use warnings;
use strict;
use Data::Dumper;
use Cwd qw(abs_path);
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."../lib/";	# Custom functions
require "lib.pl";
use OpenInnovations::XLSX;


my $url = "https://data.parliament.uk/resources/constituencystatistics/PowerBIData/ConstituencyDashboards/population_by_age.xlsx";
my $file = $basedir."../../raw-data/population_by_age.xlsx";
my $outfile = $basedir."../../src/themes/society/_data/population_2022.csv";


# Get the remote data
SaveFromURL($url,$file);

# Load in the Excel file
my $xlsx = OpenInnovations::XLSX->new()->load($file);

# Load the specific sheet
my $number = $xlsx->loadSheet('Single year of age',{
	'header'=>[0],
	'startrow'=>1,
	'rename'=>sub {
		my $str = shift;
		if($str eq "con_code"){
			return "PCON24CD";
		}elsif($str eq "con_name"){
			return "PCON24NM";
		}
		return $str;
	}
});

# Get the rows
my @rows = @{$number->{'rows'}};

my ($r,$n,$pcon,$age,$categories,$cat,$i);
my $ages = {};
my $totals = {};

for($r = 0; $r < @rows; $r++){
	$pcon = $rows[$r]->{'PCON24CD'};
	$age = $rows[$r]->{'age'};
	$n = $rows[$r]->{'con_number'};
	if(!$ages->{$pcon}){ $ages->{$pcon} = {}; }
	if(!$ages->{$pcon}{$age}){ $ages->{$pcon}{$age} = 0; }
	if(!$totals->{$pcon}){ $totals->{$pcon} = {}; }
	if(!$totals->{$pcon}{$age}){ $totals->{$pcon}{$age} = 0; }
	$ages->{$pcon}{$age} = $n;
	$totals->{$pcon}{$age} = $n;
}

$categories = {
	'total'=>{'min'=>0,'max'=>200},
	'<18'=>{'min'=>0,'max'=>17},
	'16+'=>{'min'=>16,'max'=>200},
	'17+'=>{'min'=>17,'max'=>200},
	'18+'=>{'min'=>18,'max'=>200},
	'18-64'=>{'min'=>18,'max'=>64},
	'65+'=>{'min'=>65,'max'=>200},
	'67+'=>{'min'=>67,'max'=>200},
	'70+'=>{'min'=>70,'max'=>200}
};
msg("Calculating age category totals\n");
foreach $pcon (keys(%{$ages})){
	foreach $cat (sort(keys(%{$categories}))){
		$totals->{$pcon}{$cat} = 0;
		foreach $age (keys(%{$ages->{$pcon}})){
			if($age >= $categories->{$cat}{'min'} && $age <= $categories->{$cat}{'max'}){
				$totals->{$pcon}{$cat} += $ages->{$pcon}{$age};
			}
		}
		
	}
}


msg("Saving to <cyan>$outfile<none>\n");
open(FILE,">",$outfile);
print FILE "PCON24CD";
for($i = 0; $i <= 90; $i++){
	print FILE ",".$i;
	if($i == 90){ print FILE "+"; }
}
foreach $cat (sort(keys(%{$categories}))){
	print FILE ",".$cat;
}
print FILE "\n";
foreach $pcon (sort(keys(%{$totals}))){
	print FILE "$pcon";
	for($i = 0; $i <= 90; $i++){
		print FILE ",".$totals->{$pcon}{$i};
	}
	foreach $cat (sort(keys(%{$categories}))){
		print FILE ",".$totals->{$pcon}{$cat};
	}
	print FILE "\n";
}

