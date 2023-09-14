#!/usr/bin/perl

use lib "./../lib/";	# Custom functions
use Data::Dumper;
use JSON::XS;
use OpenInnovations::GeoJSON;
require "lib.pl";

my $outputfile = "../../src/_data/sources/transport/active-travel.csv";
my $lookupfile = "../../lookups/lookup-LAD22CD-PCON22CD.json";
my $datafile = "../../raw-data/cw0307-all-walking-and-cycling-data-in-tables-cw0301-to-cw0303.csv";
@columns = (
	{'name'=>'onepm_cycall','title'=>'Cycle once a month'},
	{'name'=>'onepw_cycall','title'=>'Cycle once a week'},
	{'name'=>'threepw_cycall','title'=>'Cycle three times a week'},
	{'name'=>'fivepw_cycall','title'=>'Cycle five times a week'},
	{'name'=>'onepm_walkall','title'=>'Walk once a month'},
	{'name'=>'onepw_walkall','title'=>'Walk once a week'},
	{'name'=>'threepw_walkall','title'=>'Walk three times a week'},
	{'name'=>'fivepw_walkall','title'=>'Walk five times a week'}
);

$lookup = LoadJSON($lookupfile);
@rows = LoadCSV($datafile,{'startrow'=>3});

#print Dumper $lookup;
$data = {};
$years = {};
for($r = 0; $r < @rows; $r++){
	$lad = $rows[$r]->{'Geography_code'};
	$year = $rows[$r]->{'Year'};
	if(!$years->{$year}){ $years->{$year} = 1; }
	if($lookup->{$lad}){
		#print "LAD: $lad ($year)\n";
		@people = ();

		# Work out the number of people from the percentage and the `Weighted_sample`
		for($c = 0; $c < @columns; $c++){
			#print "\t$rows[$r]->{$columns[$c]} * $rows[$r]->{'Weighted_sample'}\n";
			$people[$c] = $rows[$r]->{'Weighted_sample'}*$rows[$r]->{$columns[$c]{'name'}}/100;
		}
		#print Dumper @people;

		$n = 0;
		foreach $pcon (keys(%{$lookup->{$lad}})){
			if(!$data->{$pcon}){ $data->{$pcon} = {}; }
			for($c = 0; $c < @columns; $c++){
				$col = $columns[$c]{'name'};
				if(!$data->{$pcon}{$col}){ $data->{$pcon}{$col} = {}; }
				if(!$data->{$pcon}{$col}{$year}){ $data->{$pcon}{$col}{$year} = {'n'=>0,'sample'=>0}; }
				# Add the constituency fraction * sample size * % / 100
				$data->{$pcon}{$col}{$year}{'n'} += $lookup->{$lad}{$pcon} * $rows[$r]->{'Weighted_sample'} * $rows[$r]->{$col}/100;
				$data->{$pcon}{$col}{$year}{'sample'} += $lookup->{$lad}{$pcon} * $rows[$r]->{'Weighted_sample'};
			}

			# Add the people to the
			#print "\t$pcon: $lookup->{$lad}{$pcon}\n";
		}
	}
}


open(FILE,">",$outputfile);
print FILE "PCON22CD";
for($c = 0; $c < @columns; $c++){
	$col = $columns[$c]{'title'};
	foreach $y (sort(keys(%{$years}))){
		print FILE ",".$col." ".$y;
	}
}
print FILE "\n";
foreach $pcon (sort(keys(%{$data}))){
	print FILE $pcon;
	for($c = 0; $c < @columns; $c++){
		$col = $columns[$c]{'name'};
		foreach $year (sort(keys(%{$years}))){
			$f = 0;
			if($data->{$pcon}{$col}{$year}{'sample'} > 0){
				$f = $data->{$pcon}{$col}{$year}{'n'} / $data->{$pcon}{$col}{$year}{'sample'};
			}else{
				warning("Bad sample size for $pcon / $col / $y: $data->{$pcon}{$col}{$year}{'sample'}\n");
			}
			print FILE ",".sprintf("%0.1f",$f*100);
		}
	}
	print FILE "\n";
}
close(FILE);


