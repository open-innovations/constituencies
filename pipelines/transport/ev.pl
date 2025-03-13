#!/usr/bin/perl

use lib "./../lib/";	# Custom functions
use Data::Dumper;
use JSON::XS;
use OpenInnovations::GeoJSON;
require "lib.pl";

my $outputfile = "../../src/themes/transport/ev-charging-points/_data/release/national_charge_point_registry_by_constituency.csv";
my $geojsonfile = "../../src/_data/geojson/constituencies-2022.geojson";
my $popfile = "../../raw-data/Population.csv";
my $key = "PCON22CD";



$types = {};
$connections = {};

# Load in the GeoJSON structure and work out bounding boxes for each feature
$geo = OpenInnovations::GeoJSON->new('file'=>$geojsonfile);

$n = @{$geo->{'features'}};
for($f = 0; $f < $n ; $f++){
	$area = $geo->{'features'}[$f]{'properties'}{$key};
	if(!$connections->{$area}){ $connections->{$area} = {'total'=>0,'slow'=>0,'fast'=>0,'rapid'=>0,'ultra'=>0}; }
	
}

# Load in the population figures
@data = LoadCSV($popfile);
$ages = {};
for($i = 0; $i < @data; $i++){
	#Age group,ONSConstID,ConstituencyName,RegionID,RegionName,CountryID,CountryName,DateThisUpdate,DateOfDataset,Date,Const%,ConstLevel,Reg%,UK%
	#0-9,E14000554,Berwick-upon-Tweed,E12000001,North East,K02000001,UK,16/09/2021,30/06/2020,2020,8.20%,6183,10.90%,11.80%
	$cid = $data[$i]->{'ONSConstID'};
	if(!$ages->{$cid}){ $ages->{$cid} = 0; }
	if($data[$i]->{'Date'} eq "2020" && $data[$i]->{'Age group'} ne "0-9" && $data[$i]->{'Age group'} ne "10-19"){ $ages->{$cid} += $data[$i]->{'ConstLevel'}; }
	if($data[$i]->{'Date'} eq "2020"){ $ages->{$cid} += $data[$i]->{'ConstLevel'}; }
}



# Load the CSV into rows
# Comes from https://chargepoints.dft.gov.uk/api/retrieve/registry/format/csv
@rows = LoadCSV("../../raw-data/national-charge-point-registry.csv");
$n = @rows;
$bad = 0;
$badconnections = 0;

for($i = 0; $i < $n ; $i++){
	$lat = $rows[$i]->{'latitude'};
	$lon = $rows[$i]->{'longitude'};
	$area = $geo->findPoint($key,$lat,$lon);
	if($area){
	
		for($j = 1; $j <= 8; $j++){
			# Only include connections that are "In service"
			if($rows[$i]->{'connector'.$j.'Status'} eq "In service"){
				$typ = $rows[$i]->{'connector'.$j.'RatedOutputKW'};
				$rating = "";
				if($typ >= 3 && $typ <= 6){ $rating = "slow"; }
				if($typ >= 7 && $typ <= 22){ $rating = "fast"; }
				if($typ >= 25 && $typ <= 100){ $rating = "rapid"; }
				if($typ > 100){ $rating = "ultra"; }

				if($rating){
					if(!$types->{$rating}){ $types->{$rating} = 0; }
					$types->{$rating}++;
					if(!$connections->{$area}{$rating}){ $connections->{$area}{$rating} = 0; }
					$connections->{$area}{$rating}++;
				}else{
					warning("\tNo rating for $typ\n");
				}
				$connections->{$area}{'total'}++;
			}
		}
	}else{
		warning("\tCould not find enclosing area for $lat,$lon\n");
		$bad++;
		
		for($j = 1; $j <= 8; $j++){
			# Only include connections that are "In service"
			if($rows[$i]->{'connector'.$j.'Status'} eq "In service"){
				$badconnections++;
			}
		}
	}
}
open(FILE,">",$outputfile);
print FILE "$key,all";
print FILE ",slow (3-6 KW),fast (7-22 KW),rapid (25-100 KW),ultra (>100 KW),population (2020)";
print FILE ",all (per 100k),slow (3-6 KW per 100k),fast (7-22 KW per 100k),rapid (25-100 KW per 100k),ultra (>100 KW per 100k)";
print FILE "\n";
foreach $area (sort(keys(%{$connections}))){
	print FILE ($area =~ /,/ ? "\"$area\"": $area);
	print FILE ",$connections->{$area}{'total'},$connections->{$area}{'slow'},$connections->{$area}{'fast'},$connections->{$area}{'rapid'},$connections->{$area}{'ultra'},$ages->{$area}";
	print FILE ",".sprintf("%0d",1e5*$connections->{$area}{'total'}/$ages->{$area}).",".sprintf("%0d",1e5*$connections->{$area}{'slow'}/$ages->{$area}).",".sprintf("%0d",1e5*$connections->{$area}{'fast'}/$ages->{$area}).",".sprintf("%0d",1e5*$connections->{$area}{'rapid'}/$ages->{$area}).",".sprintf("%0d",1e5*$connections->{$area}{'ultra'}/$ages->{$area});
	print FILE "\n";
}
close(FILE);
print "$bad unidentified chargepoint locations ($badconnections chargepoints)\n";

