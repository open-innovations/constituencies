#!/usr/bin/perl

use strict;
use warnings;
use utf8;
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';
use JSON::XS;
use Data::Dumper;
use POSIX qw(strftime);
use Cwd qw(abs_path);
my ($basedir, $path);
BEGIN { ($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$}; push @INC, $basedir; }
use lib $basedir."../lib/";	# Custom functions
require "lib.pl";


my ($hfile,$gfile,$pfile,$ofile,$fh,$hexjson,$geojson,$data,$csv,$id,$y,$total,$lookup,$i,$f);

$hfile = $basedir."../../src/_data/hexjson/uk-constituencies-2024.hexjson";
$gfile = $basedir."../../raw-data/society/osm-playgrounds-by-constituency.geojson";
$pfile = $basedir."../../src/themes/society/population/_data/population_2022.csv";
$ofile = $basedir."../../src/themes/society/playgrounds/_data/release/playgrounds.csv";

# Get hexes
$hexjson = LoadJSON($hfile);

# Get GeoJSON with overlaps
# osmium tags-filter --overwrite -o raw-data/osm/uk-playgrounds.osm.pbf raw-data/osm/united-kingdom-latest.osm.pbf leisure=playground
# Open raw-data/osm/uk-playgrounds.osm.pbf in QGIS
# Use the "Overlap analysis" tool to find the overlap between the constituencies and the multipolygons from OSM playgrounds
$geojson = LoadJSON($gfile);

# Get the population figures per age
$data = LoadCSV($pfile,{'key'=>'PCON24CD'});

# Build a lookup
for($i = 0; $i < @{$geojson->{'features'}}; $i++){
	$lookup->{$geojson->{'features'}[$i]{'properties'}{'PCON24CD'}} = $i;
}

$csv = "PCON24CD,PCON24NM,Population under 16,Playground (% area),Playground (m^2/child)\n";
foreach $id (sort(keys(%{$hexjson->{'hexes'}}))){
	$csv .= "$id,\"$hexjson->{'hexes'}{$id}{'n'}\"";
	$total = 0;
	for($y = 0; $y < 16; $y++){
		$total += $data->{$id}{$y};
	}
	$csv .= ",$total";
	$f = $geojson->{'features'}[$lookup->{$id}]{'properties'};
	$csv .= ",".sprintf("%0.4f",$f->{'Fixed playgrounds_pc'});
	$csv .= ",".sprintf("%0.4f",$f->{'Fixed playgrounds_area'}/$total);
	$csv .= "\n";
}
open($fh,">:utf8",$ofile);
print $fh $csv;
close($fh);