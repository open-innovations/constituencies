#!/usr/bin/perl

use lib "./../lib/";	# Custom functions
use Data::Dumper;
use JSON::XS;
use YAML::XS;
use OpenInnovations::GeoJSON;

my %colours = (
	'black'=>"\033[0;30m",
	'red'=>"\033[0;31m",
	'green'=>"\033[0;32m",
	'yellow'=>"\033[0;33m",
	'blue'=>"\033[0;34m",
	'magenta'=>"\033[0;35m",
	'cyan'=>"\033[0;36m",
	'white'=>"\033[0;37m",
	'none'=>"\033[0m"
);

$types = {};
$connections = {};
$key = "PCON22CD";

# Load in the GeoJSON structure and work out bounding boxes for each feature
$geo = OpenInnovations::GeoJSON->new('file'=>"../../src/_data/geojson/constituencies-2022.geojson");

$n = @{$geo->{'features'}};
for($f = 0; $f < $n ; $f++){
	$area = $geo->{'features'}[$f]{'properties'}{$key};
	if(!$connections->{$area}){ $connections->{$area} = {'total'=>0,'slow'=>0,'fast'=>0,'rapid'=>0,'ultra'=>0}; }
	
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
open(FILE,">","../../src/_data/sources/transport/national_charge_point_registry_by_constituency.csv");
print FILE "$key,all,slow (3-6 KW),fast (7-22 KW),rapid (25-100 KW),ultra (>100 KW)\n";
foreach $area (sort(keys(%{$connections}))){
	print FILE ($area =~ /,/ ? "\"$area\"": $area).",$connections->{$area}{'total'},$connections->{$area}{'slow'},$connections->{$area}{'fast'},$connections->{$area}{'rapid'},$connections->{$area}{'ultra'}\n";
}
close(FILE);
print "$bad unidentified chargepoint locations ($badconnections chargepoints)\n";



################
# Subroutines

sub msg {
	my $str = $_[0];
	my $dest = $_[1]||STDOUT;
	foreach my $c (keys(%colours)){ $str =~ s/\< ?$c ?\>/$colours{$c}/g; }
	print $dest $str;
}

sub error {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<red>ERROR:<none> /;
	msg($str,STDERR);
}

sub warning {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1$colours{'yellow'}WARNING:$colours{'none'} /;
	print STDERR $str;
}


sub LoadCSV {
	my $file = shift;
	my $col = shift;
	my $compact = shift;

	my (@lines,$str,@rows,@cols,@header,$r,$c,@features,$data,$key,$k,$f);

	msg("Processing CSV from <cyan>$file<none>\n");
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);
	$str =~ s/\r\n/\\n/g;
	
	@rows = split(/[\n]/,$str);

	for($r = 0; $r < @rows; $r++){
		@cols = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$rows[$r]);
		if($r < 1){
			# Header
			if(!@header){
				@header = @cols;
			}else{
				for($c = 0; $c < @cols; $c++){
					$header[$c] .= "\n".$cols[$c];
				}
			}
		}else{
			$data = {};
			for($c = 0; $c < @cols; $c++){
				$cols[$c] =~ s/(^\"|\"$)//g;
				$data->{$header[$c]} = $cols[$c];
			}
			push(@features,$data);
		}
	}
	if($col){
		$data = {};
		for($r = 0; $r < @features; $r++){
			$f = $features[$r]->{$col};
			if($compact){ $f =~ s/ //g; }
			$data->{$f} = $features[$r];
		}
		return $data;
	}else{
		return @features;
	}
}
