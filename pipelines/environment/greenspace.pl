#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Data::Dumper;
use Cwd qw(abs_path);
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';
use JSON::XS;
use POSIX qw(strftime);
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."../lib/";	# Custom functions
require "lib.pl";


my (@rows,$rdir,$oas,$oa,$r,$s,$oafile,$data,$pcon,$csv,$scenarios,$ofile,$dir,$fh);

$rdir = $basedir."../../raw-data/";
$ofile = $basedir."../../src/themes/environment/green-space/_data/release/access_to_greenspace.csv";
$scenarios = 7;

# Load in the OA to PCON lookup
$oafile = $rdir."OA_(2021)_to_Westminster_Parliamentary_Constituencies_(July_2024)_Best_Fit_Lookup_in_EW.csv";
if(!-e $oafile){
	msg("Download a CSV file from <cyan>https://geoportal.statistics.gov.uk/datasets/5968b5b2c0f14dd29ba277beaae6dec3_0/explore<none> to <cyan>$oafile<none>\n");
}
$oas = LoadCSV($oafile,{'key'=>'OA21CD'});


# Process scenario files
for($s = 1; $s <= $scenarios; $s++){
	# Load the data
	@rows = LoadCSV($rdir."environment/Access_to_greenspace_England_2024_scenario$s.csv",{'startrow'=>6,'header'=>{'start'=>5}});
	for($r = 0; $r < @rows; $r++){
		$oa = $rows[$r]->{'OA21'};
		$pcon = $oas->{$oa}{'PCON25CD'};
		if(!defined($data->{$pcon})){
			$data->{$pcon} = {'name'=>$oas->{$oa}{'PCON25NM'}};
		}
		if(!defined($data->{$pcon}{'scenario'.$s})){
			$data->{$pcon}{'scenario'.$s} = {'access'=>0,'total'=>0};
		}
		
		$data->{$pcon}{'scenario'.$s}{'access'} += $rows[$r]->{'Household with access count'};
		$data->{$pcon}{'scenario'.$s}{'total'} += $rows[$r]->{'Household count'};
	}
}

$csv = "PCON24CD,PCON24NM";
for($s = 1; $s <= $scenarios; $s++){
	for($r = 0; $r < 3; $r++){
		$csv .= ",Scenario $s";
	}
}
$csv .= "\n";
$csv .= ",";
for($s = 1; $s <= $scenarios; $s++){
	$csv .= ",Households,Households with access,Percentage with access";
}
$csv .= "\n";
$csv .= "---,---";
for($s = 1; $s <= $scenarios; $s++){
	for($r = 0; $r < 3; $r++){
		$csv .= ",---";
	}
}
$csv .= "\n";
foreach $pcon (sort(keys(%{$data}))){
	$csv .= $pcon;
	$csv .= ",".($data->{$pcon}{'name'} =~ /,/ ? "\"":"").$data->{$pcon}{'name'}.($data->{$pcon}{'name'} =~ /,/ ? "\"":"");
	for($s = 1; $s <= $scenarios; $s++){
		$csv .= ",".$data->{$pcon}{'scenario'.$s}{'total'};
		$csv .= ",".$data->{$pcon}{'scenario'.$s}{'access'};
		$csv .= ",".sprintf("%0.1f",(100*$data->{$pcon}{'scenario'.$s}{'access'}/$data->{$pcon}{'scenario'.$s}{'total'}));
	}
	$csv .= "\n";
}


# Make the output directory if it doesn't exist
$dir = $ofile;
$dir =~ s/[^\/]+$//;
makeDir($dir);

msg("Saving output to <cyan>$ofile<none>\n");
open($fh,">:utf8",$ofile);
print $fh $csv;
close($fh);
