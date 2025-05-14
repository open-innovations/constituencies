#!/usr/bin/perl
# Process STATS-19 data
# First download data from https://www.data.gov.uk/dataset/cb7ae6f0-4be6-4935-9277-47e5ce24a11f/road-accidents-safety-data and extract it somewhere like raw-data/transport/stats-19/
# perl stats-19.pl raw-data/transport/stats-19/

use utf8;
use warnings;
use strict;
use Data::Dumper;
use Cwd qw(abs_path);
use Geo::Coordinates::OSGB qw(grid_to_ll ll_to_grid);
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."../lib/";	# Custom functions
require "lib.pl";
use OpenInnovations::GeoJSON;

my ($match,$r,@rows,@cols,$odir,$datum,@fields,$header,$datadir,$dir,$geo,$dh,$fh,$filename,$coordlookup,$c,@dirs,$d,$files,$f,$nocoord,$nomatch,$matched,$dist,$i,$crimes,$pcon,$typ,$yy,$mm,$types,@years,$year,@ctypes,$t,@ys,$y,$lastmonth);


# Set some variables
#my $ofile = $basedir."../../src/themes/society/crime/_data/release/crime-data.csv";
my $hexjson = $basedir.'../../src/_data/hexjson/uk-constituencies-2024.hexjson';
my $geojson = $basedir."../../raw-data/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC.geojson";
my $ofile = $ARGV[1]||($basedir."../../src/themes/transport/road-traffic-accidents/_data/release/stats19.csv");


# Find the data directory if not provided
$datadir = $ARGV[0]||($basedir."../../raw-data/transport/stats-19/");
if($datadir !~ /\/$/){ $datadir .= "/"; }

$odir = $ofile;
$odir =~ s/([^\/]+)$//g;

# Create the temporary directory if it doesn't exist
makeDir($odir);

# Load some population data
#$popdata = LoadCSV($popdata,{'key'=>'PCON24CD'});

# Load the hexes
$hexjson = LoadJSON($hexjson);

# Load the constituency GeoJSON file
$geo = new OpenInnovations::GeoJSON;
$geo->load($geojson);



# Open the source directory
opendir($dh,$datadir);
while( ($filename = readdir($dh))) {
	if($filename =~ /\-(casualty|collision|vehicle)\-1979-latest-published-year.csv/){
		push(@{$files->{$1}},$filename);
	}elsif($filename =~ /(casualty|collision|vehicle)\-([0-9]{4}).csv/){
		if($2 > 2023){
			push(@{$files->{$1}},$filename);
		}
	}
}
closedir($dh);





$nocoord = 0;
$nomatch = 0;
$matched = 0;
@fields = ('CID','PCON24CD','Crime type');

my ($oldy,$lat,$lon,$e,$n,$idx,$results,$ok,$severity,$bad,$good,$years,$csv,@types);
$oldy = 1900;
$bad = 0;
$good = 0;
$results = {};
$years = {};
@types = ('Fatal','Serious','Slight');

# Create empty results
foreach $pcon (keys(%{$hexjson->{'hexes'}})){
	$results->{$pcon} = {};
}


# Loop over files
msg("Processing collision files\n");

for($f = 0; $f < @{$files->{'collision'}}; $f++){
	msg("Reading <cyan>$datadir$files->{'collision'}[$f]<none>\n");
	open(my $fh,"<:utf8",$datadir.$files->{'collision'}[$f]);
	$i = 0;
	while(my $line = <$fh>){
		if($i == 0){
			$line =~ s/[\n\r]//g;
			$line =~ s/^\x{FEFF}//;
			$line =~ s/^\x{FEFF}//;
			$line =~ s/^\N{U+FEFF}//;
			$line =~ s/^\N{ZERO WIDTH NO-BREAK SPACE}//;
			$line =~ s/^\N{BOM}//; 
			@cols = split(/\,/,$line);
			for($c = 0; $c < @cols; $c++){
				$header->{$cols[$c]} = $c;
			}
			$i++;
		}else{
			#if($i > 200000){ last; }
			if($line =~ /([^\,]+),([0-9]{4}),/){
				$y = $2;
				if($y ne $oldy){
					msg("\tProcessing <yellow>$y<none>\n");
				}
				if($y > 1999){
					$line =~ s/[\n\r]//g;
					if($y ne $oldy){
						msg("\tProcessing <yellow>$y<none>\n");
						$years->{$y} = 1;
						saveFile();
					}
					@cols = split(/\,/,$line);
					$idx = $header->{'accident_index'};
					if($y ne $oldy){
						foreach $pcon (keys(%{$hexjson->{'hexes'}})){
							if(!defined($results->{$pcon}{$y})){
								$results->{$pcon}{$y} = {'Slight'=>0,'Serious'=>0,'Fatal'=>0};
							}
						}
						if($i > 1){
							msg("$bad/$good matches\n");
						}
					}
					$lat = $cols[$header->{'latitude'}];
					$lon = $cols[$header->{'longitude'}];
					$e = $cols[$header->{'location_easting_osgr'}];
					$n = $cols[$header->{'location_northing_osgr'}];
					$ok = 0;
					if($lat eq "NULL" || $lon eq "NULL"){
						if($e ne "NULL" && $n ne "NULL"){
							($lat, $lon) = grid_to_ll($cols[$header->{'location_easting_osgr'}], $cols[$header->{'location_northing_osgr'}]);
							$lat = sprintf("%.5f",$lat);
							$lon = sprintf("%.5f",$lon);
							$ok = 1;
						}else{
							#warning("Bad easting/northing for ".($cols[$idx]||$i)."\n");
						}
					}else{
						$ok = 1;
					}
					if($ok){
						$c = $lat."/".$lon;

						# Use any previously found results
						if(!$coordlookup->{$c}){
							$match = $geo->getFeatureAt($lat,$lon);
							# Keep a copy of the lookup
							$coordlookup->{$c} = $match->{'properties'};
						}
						$pcon = $coordlookup->{$c}{'PCON24CD'}||"";
						if($pcon && defined($results->{$pcon})){
							$severity = $cols[$header->{'accident_severity'}];
							if($severity==1){ $severity = "Fatal"; }
							elsif($severity==2){ $severity = "Serious"; }
							elsif($severity==3){ $severity = "Slight"; }
							$results->{$pcon}{$y}{$severity}++;
							$good++;
						}else{
							$bad++;
							warning("\t\tNo constituency for $cols[$idx] at $c ($bad/$good)\n");
						}
					}else{
						$bad++;
						warning("\t\tBad coordinates for $cols[$idx] ($bad/$good)\n");
					}
					$i++;
				}
				$oldy = $y;
			}
		}
	}
	close($fh);
	saveFile();
}


#updateCreationTimestamp($basedir."../../src/themes/society/crime/index.vto");
#updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/all.json");


sub saveFile {
	
	# Build output with rows for constituencies, columns by year and severity
	my (@ys,$i,$c,$pcon,$fh);
	
	$csv = "PCON24CD,PCON24NM";
	@ys = sort(keys(%{$years}));

	for($i = 0; $i < @ys; $i++){
		for($c = 0; $c < @types; $c++){
			$csv .= ",$ys[$i]";
		}
	}
	$csv .= "\n,";
	for($i = 0; $i < @ys; $i++){
		for($c = 0; $c < @types; $c++){
			$csv .= ",$types[$c]";
		}
	}
	$csv .= "\n---,---";
	for($i = 0; $i < @ys; $i++){
		for($c = 0; $c < @types; $c++){
			$csv .= ",---";
		}
	}
	$csv .= "\n";
	for $pcon (sort(keys(%{$results}))){
		$csv .= "$pcon,\"$hexjson->{'hexes'}{$pcon}{'n'}\"";
		for($i = 0; $i < @ys; $i++){
			for($c = 0; $c < @types; $c++){
				$csv .= ",".($results->{$pcon}{$ys[$i]}{$types[$c]}||"0");
			}
		}
		$csv .= "\n";
	}
	
	msg("Saving to <cyan>$ofile<none>\n");
	open($fh,">:utf8",$ofile);
	print $fh $csv;
	close($fh);
}
