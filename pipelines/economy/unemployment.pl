#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Data::Dumper;
use Cwd qw(abs_path);
use POSIX qw(strftime);
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."../lib/";	# Custom functions
require "lib.pl";


my $odir = $basedir."data/";

my ($url,$syear,$eyear,$y,$file,$dl,@files,$i,@rows,$r,$data,$dates,@dts,$csv,$pcon,$ofile,$json,$cfile,$lbl,$months,$vfile,$conlookup);

$ofile = $basedir."../../src/themes/economy/unemployment/_data/release/unemployment_rate.csv";
$cfile = $basedir."../../src/themes/economy/unemployment/_data/unemployment.json";
$vfile = $basedir."../../src/themes/economy/unemployment/index.vto";
$months = {'01'=>'Jan','02'=>'Feb','03'=>'Mar','04'=>'Apr','05'=>'May','06'=>'Jun','07'=>'Jul','08'=>'Aug','09'=>'Sep','10'=>'Oct','11'=>'Nov','12'=>'Dec'};
$conlookup = {
	'S14000006'=>'S14000107',
	'S14000008'=>'S14000108',
	'S14000010'=>'S14000109',
	'S14000040'=>'S14000110',
	'S14000058'=>'S14000111'
};
$syear = "2014";
$eyear = strftime "%Y", gmtime;

$dl = 0;
for($y = $syear; $y <= $eyear; $y++){
	$file = $odir."NM_162_1-unemployment-$y.csv";
	if(!-e $file){
		if($dl > 0){
			sleep 4;
		}
		msg("Downloading data for <yellow>$y<none>\n");
		# Get the remote data
		SaveFromURL("https://www.nomisweb.co.uk/api/v01/dataset/NM_162_1.data.csv?geography=TYPE172&date=$y-01,$y-02,$y-03,$y-04,$y-05,$y-06,$y-07,$y-08,$y-09,$y-10,$y-11,$y-12,&gender=0&age=0&select=DATE_CODE,GEOGRAPHY_CODE,MEASURE_CODE,OBS_VALUE,OBS_STATUS&measure=1,2&measures=20100",$file);
		$dl++;
	}
	push(@files,$file);
}


# Need to construct the results
for($i = 0; $i < @files; $i++){
	@rows = LoadCSV($files[$i]);
	for($r = 0; $r < @rows; $r++){
		if($rows[$r]{'MEASURE_CODE'} eq "2" && $rows[$r]{'DATE_CODE'} =~ /-(03|06|09|12)$/){
			$dates->{$rows[$r]{'DATE_CODE'}} = 1;
			$pcon = $rows[$r]{'GEOGRAPHY_CODE'};
			if(defined($conlookup->{$pcon})){ $pcon = $conlookup->{$pcon}; }
			if(!defined($data->{$pcon})){
				$data->{$pcon} = {};
			}
			$data->{$pcon}{$rows[$r]{'DATE_CODE'}} = $rows[$r]{'OBS_VALUE'};
		}
	}
}
@dts = sort(keys(%{$dates}));
$csv = "PCON24CD";
for($i = 0; $i < @dts; $i++){ $csv .= ",".$dts[$i]; }
$csv .= "\n";
for $pcon (sort(keys(%{$data}))){
	$csv .= $pcon;
	for($i = 0; $i < @dts; $i++){ $csv .= ",".($data->{$pcon}{$dts[$i]}||""); }
	$csv .= "\n";
}
msg("Save to <cyan>$ofile<none>\n");
open(FILE,">:utf8",$ofile);
print FILE $csv;
close(FILE);

if(-e $cfile){
	$json = LoadJSON($cfile);
	$json->{'units'} = {};
	$json->{'config'}{'value'} = $dts[@dts-1];
	for($i = 0; $i < @dts; $i++){
		$json->{'units'}{$dts[$i]} = {"value"=>"percent","precision"=>0.1};
		$lbl = $dts[$i];
		if($lbl =~ /([0-9]{4})-([0-9]{2})/){
			$lbl = $months->{$2}." ".$1;
		}
		$dts[$i] = {'label'=>$lbl,'value'=>$dts[$i]};
	}
	$json->{'config'}{'tools'}{'slider'}{'columns'} = \@dts;
	SaveJSON($json,$cfile,3);
	updateCreationTimestamp($cfile,$json->{'config'}{'value'});
	updateCreationTimestamp($vfile,(strftime "%Y-%m-%dT%H:%M", localtime));
}else{
	warning("No config file exists at <cyan>$cfile<none>\n");
}



sub saveSheet {
	my $file = shift;
	my $data = shift;
	my @headers = @{$data->{'headers'}{'columns'}};
	my @rows = @{$data->{'rows'}};
	my ($r,$c,$fh,$v);
	
	msg("Saving to <cyan>$file<none>\n");
	open($fh,">",$file);
	# Create header row
	for($c = 0; $c < @headers; $c++){
		$v = $headers[$c]{'title'}||"";
		print $fh ($c == 0 ? "":",").($v =~ /,/ ? "\"":"").($v).($v =~ /,/ ? "\"":"");
	}
	print $fh "\n";
	for($r = 0; $r < @rows; $r++){
		for($c = 0; $c < @headers; $c++){
			$v = $rows[$r]{$headers[$c]{'title'}}||"";
			print $fh ($c == 0 ? "":",").($v =~ /,/ ? "\"":"").($v).($v =~ /,/ ? "\"":"");
		}
		print $fh "\n";
	}
	close($fh);
}

