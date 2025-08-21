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
use Getopt::Long;
use Text::CSV;
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."../../lib/";	# Custom functions
use OpenInnovations::Postcodes;
use OpenInnovations::GeoJSON;
require "lib.pl";


my ($pcds,$pcd,@files,$file,$geojson,$geo,$i,$r,$f,$y,$bad,$count,$pcon,$pnam,$pid,$totals,$price,$date,$newest,$json);
my $dir = $basedir."../../../";
my $rawdir = $dir."raw-data/";
my $pcdurl = "https://www.arcgis.com/sharing/rest/content/items/6f2f35a9a0b94e7e949eeba7785911d4/data";
my $csvfile = $dir."src/themes/economy/house-prices/_data/release/land_registry_sold.csv";
my $jsonfile = $dir."src/themes/economy/house-prices/_data/high_value_sold.json";
my $syear = 2018;
my $eyear = ((localtime())[5]+1900)+0;




# Set the yearly data
for(my $y = $syear; $y <= $eyear; $y++){
	$file = $rawdir."economy/landregistry-ppd-$y.csv";
	push(@files,{'file'=>$file,'year'=>$y});
}


# Build the postcode lookup
my $zipfile = $rawdir."PCDtoPCON.zip";
my $zipdir = $rawdir."PCDtoPCON/";
my $pcdfile = $zipdir."pcd_pcon_uk_lu_may_24.csv";
if(!-e $zipfile){
	# Download lookup from geoportal
	SaveFromURL($pcdurl,$zipfile);
	# Unzip the file
	`unzip $zipfile -d $zipdir`;
}
msg("Loading postcode lookup\n");
open(my $fh,$pcdfile);
while(<$fh>){
	if($_ =~ /\"([^\"]*)\",[0-9]+,[0-9]+,\"([^\"]*)\",\"([^\"]*)\"/s){
		$pcd = $1;
		$pcon = $2||"";
		$pnam = $3||"";
		$pcd =~ s/ //g;
		$pcds->{$pcd} = {'cd'=>$pcon,'nm'=>$pnam};
	}
}
close($fh);


$bad = 0;
$count = 0;
$pid = "PCON24CD";
$totals = {};
$newest = "";


msg("Processing Land Registry data\n");
for($f = 0; $f < @files; $f++){

	msg("Get data from <cyan>$files[$f]{'file'}<none>\n");
	CacheDownload("http://prod.publicdata.landregistry.gov.uk.s3-website-eu-west-1.amazonaws.com/pp-$files[$f]{'year'}.csv",$files[$f]{'file'},30*86400);

	if(-e $files[$f]{'file'}){
		open($fh,$files[$f]{'file'});
		while(<$fh>){
			if($_ =~ /\"([^\"]*)\",\"([^\"]*)\",\"([^\"]*)\",\"([^\"]*)\"/s){
				$pid = $1;
				$price = $2;
				$date = $3;
				$pcd = $4;
				$pcd =~ s/ //g;

				if($date gt $newest){ $newest = $date; }

				if($date =~ /^([0-9]{4})/){
					$y = $1;
				}else{
					$y = "";
				}

				if(defined($pcds->{$pcd})){
					$pcon = $pcds->{$pcd}{'cd'};
					$pnam = $pcds->{$pcd}{'nm'};

					# We now want to keep a record of this
					if(!defined($totals->{$pcon})){
						$totals->{$pcon} = {'name'=>$pnam,'years'=>{}};
					}
					if(!defined($totals->{$pcon}{'years'}{$y})){
						$totals->{$pcon}{'years'}{$y} = {'total'=>0,'1.5M'=>0,'1M'=>0,'500k'=>0};
					}
					$totals->{$pcon}{'years'}{$y}{'total'}++;
					if($price > 1500000){
						$totals->{$pcon}{'years'}{$y}{'1.5M'}++;
					}
					if($price > 1000000){
						$totals->{$pcon}{'years'}{$y}{'1M'}++;
					}
					if($price > 500000){
						$totals->{$pcon}{'years'}{$y}{'500k'}++;
					}
					$count++;
				}else{
					$bad++;
					#warning("Bad postcode <green>$pcd<none> ($pid)\n");
				}
			}
		}
		close($fh);
	}else{
		warning("Bad file <cyan>$files[$f]{'file'}<none>\n");
	}
}
msg("Bad: <red>$bad<none> / $count\n");
msg("Most recent: <green>$newest<none> ".getDateFromISO($newest)."\n");


msg("Update JSON file at <cyan>$jsonfile<none>\n");
$json = LoadJSON($jsonfile);
$json->{'date'} = strftime("%Y-%m-%d", localtime());
$json->{'config'}{'value'} = "1.5M_UP→$eyear";
$json->{'config'}{'tools'}{'slider'}{'columns'} = ();
for(my $y = $syear; $y <= $eyear; $y++){
	push(@{$json->{'config'}{'tools'}{'slider'}{'columns'}},{'label'=>$y.($y==$eyear ? " (".getDateFromISO($newest).")":""),'value'=>"1.5M_UP→$y"});
}
$json->{'config'}{'tooltip'} = "<strong>{{ n }}</strong><br />Homes over £1.5 million sold:";
for(my $y = $eyear; $y >= $syear; $y--){
	$json->{'config'}{'tooltip'} .= "<br />$y".($y==$eyear ? " (".getDateFromISO($newest).")":"").": {{ 1.5M_UP→$y | toLocaleString() }} / {{ Total→$y | toLocaleString() }}</strong>";
}
for(my $y = $syear; $y <= $eyear; $y++){
	$json->{'units'}{'1.5M_UP→'.$y} = {"value"=>"number"};
	if($y == $eyear){
		$json->{'units'}{'1.5M_UP→'.$y}{'notes'} = "".getDateFromISO($newest);
	}
}
SaveJSON($json,$jsonfile,3);


my $csv = "PCON24CD,PCON24NM";
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",Total"; }
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",500K_UP"; }
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",1M_UP"; }
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",1.5M_UP"; }
$csv .= "\n";
$csv .= ",";
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",$y"; }
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",$y"; }
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",$y"; }
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",$y"; }
$csv .= "\n";
$csv .= "---,---";
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",---"; }
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",---"; }
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",---"; }
for(my $y = $syear; $y <= $eyear; $y++){ $csv .= ",---"; }
$csv .= "\n";
# Each constituency
foreach $pcon (sort(keys(%{$totals}))){
	$csv .= "$pcon,".($totals->{$pcon}{'name'} =~ /,/ ? "\"":"").$totals->{$pcon}{'name'}.($totals->{$pcon}{'name'} =~ /,/ ? "\"":"");
	for(my $y = $syear; $y <= $eyear; $y++){
		$csv .= ",$totals->{$pcon}{'years'}{$y}{'total'}";
	}
	for(my $y = $syear; $y <= $eyear; $y++){
		$csv .= ",$totals->{$pcon}{'years'}{$y}{'500k'}";
	}
	for(my $y = $syear; $y <= $eyear; $y++){
		$csv .= ",$totals->{$pcon}{'years'}{$y}{'1M'}";
	}
	for(my $y = $syear; $y <= $eyear; $y++){
		$csv .= ",$totals->{$pcon}{'years'}{$y}{'1.5M'}";
	}
	$csv .= "\n";
}

msg("Saving to <cyan>$csvfile<none>\n");
open($fh,">",$csvfile);
print $fh $csv;
close($fh);


###################
sub getDateFromISO {
	my $dt = shift;
	my $d;
	my $nth = "th";
	my @months = ("January","February","March","April","May","June","July","August","September","October","November","December");
	if($dt =~ /[0-9]{4}-([0-9]{2})-([0-9]{2})/){
		$d = $2;
		if($d%10==1 && $d!=11){ $nth = "st"; }
		if($d%10==2 && $d!=12){ $nth = "nd"; }
		if($d%10==3 && $d!=13){ $nth = "rd"; }
		return $d.$nth." ".$months[$1-1];
	}
	return "";
}
