#!/usr/bin/perl

use lib "./../lib/";	# Custom functions
use Data::Dumper;
require "lib.pl";

my $popfile = "../../raw-data/Population_all.csv";
my $outfile = "../../src/_data/sources/society/population-2020.csv";


my @rows = LoadCSV($popfile);


my $ages = {};
my $totals = {};

for($r = 0; $r < @rows; $r++){
	$pcon = $rows[$r]->{'PCON11CD'};
	$age = $rows[$r]->{'Age_year'};
	$n = $rows[$r]->{'Age_pop'};
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
print FILE "PCON11CD";
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

