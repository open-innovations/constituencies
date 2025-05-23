#!/usr/bin/perl
# Process police.uk data
# First download police data from https://data.police.uk/data/archive/ and extract it into raw-data/society/police/
# perl police-data.pl <dir>

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
use OpenInnovations::GeoJSON;

my ($match,$r,@rows,@fields,$datadir,$dir,$geo,$dh,$fh,$filename,$coordlookup,$c,@dirs,$d,@files,$f,$nocoord,$nomatch,$matched,$dist,$i,$crimes,$pcon,$typ,$yy,$mm,$types,@years,$year,@ctypes,$t,@ys,$y,$lastmonth);


# Set some variables
my $ofile = $basedir."../../src/themes/society/crime/_data/release/crime-data.csv";
my $tempdir = $basedir."../../raw-data/society/police/";
my $hexjson = $basedir.'../../src/_data/hexjson/uk-constituencies-2024.hexjson';
my $geojson = $basedir."../../raw-data/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC.geojson";
my $popdata = $basedir."../../src/themes/society/population/_data/population_2022.csv";	# Derived from https://www.ons.gov.uk/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/parliamentaryconstituencymidyearpopulationestimates


# Find all the month directories
$datadir = $ARGV[0];

# Create the temporary directory if it doesn't exist
makeDir($tempdir);

# Load some population data
$popdata = LoadCSV($popdata,{'key'=>'PCON24CD'});

# Load the hexes
$hexjson = LoadJSON($hexjson);

# Load the constituency GeoJSON file
$geo = new OpenInnovations::GeoJSON;
$geo->load($geojson);

# Empty values
$crimes = {};
$types = {'All'=>0};
$year = {};
$lastmonth = "";


if(!$datadir || !-d $datadir){

	error("No directory for source data has been provided so loading from <cyan>$tempdir<none>.\n");
	# Read from tempdir
	opendir($dh,$tempdir);
	while( ($filename = readdir($dh))) {
		if($filename =~ /([0-9]{4})-([0-9]{2})/){
			if($filename =~ /\.csv$/){
				push(@files,{'dir'=>$tempdir,'file'=>$filename});
			}
		}
	}
	closedir($dh);

}else{

	# Open the source directory
	opendir($dh,$datadir);
	while( ($filename = readdir($dh))) {
		if($filename =~ /([0-9]{4})-([0-9]{2})/ && -d $datadir.$filename){
			$dir = $datadir.$filename."/";
			push(@dirs,$dir);
		}
	}
	closedir($dh);

	# For each month directory find all the police force files
	for($d = 0; $d < @dirs; $d++){
		opendir($dh,$dirs[$d]);
		while( ($filename = readdir($dh))) {
			if($filename =~ /\.csv$/ && $filename =~ /\-street\./){
				push(@files,{'dir'=>$dirs[$d],'file'=>$filename});
			}
		}
		closedir($dh);
	}

	$nocoord = 0;
	$nomatch = 0;
	$matched = 0;

	@fields = ('CID','PCON24CD','Crime type');

	# Loop over files
	msg("Processing files\n");
	for($f = 0; $f < @files; $f++){
		if(!-e $tempdir.$files[$f]{'file'}){
			@rows = LoadCSV($files[$f]{'dir'}.$files[$f]{'file'});
			# Add PCON24CD to each row
			for($r = 0; $r < @rows; $r++){
				if($rows[$r]->{'Latitude'} && $rows[$r]->{'Longitude'}){
					$c = $rows[$r]->{'Latitude'}."/".$rows[$r]->{'Longitude'};
					# Use any previously found results
					if(!$coordlookup->{$c}){
						$match = $geo->getFeatureAt($rows[$r]->{'Latitude'},$rows[$r]->{'Longitude'});
						# Keep a copy of the lookup
						$coordlookup->{$c} = $match->{'properties'};
					}
					if(!defined($coordlookup->{$c})){
						# Get nearest feature
						($i,$dist) = $geo->closestFeature($rows[$r]->{'Longitude'},$rows[$r]->{'Latitude'});
						if($dist < 200){
							msg("\tRow <green>$r<none> ($rows[$r]->{'Latitude'}/$rows[$r]->{'Longitude'}) is not in a polygon but ".($geo->{'features'}[$i]{'properties'}{'PCON24NM'}||"")." is <cyan>".int($dist)."m<none> away.\n");
							$coordlookup->{$c} = $geo->{'features'}[$i]{'properties'};
						}else{
							warning("\tRow <green>$r<none> ($rows[$r]->{'Latitude'}/$rows[$r]->{'Longitude'}) is too far from $geo->{'features'}[$i]{'properties'}{'PCON24NM'} (<cyan>".int($dist)."m<none> away) $nomatch/$matched.\n");
							$coordlookup->{$c} = {};
						}
					}
					if($coordlookup->{$c}{'PCON24CD'} && $coordlookup->{$c}{'PCON24NM'}){
						$rows[$r]->{'PCON24CD'} = $coordlookup->{$c}{'PCON24CD'};
						$matched++;
					}else{
						$nomatch++;
					}
				}else{
					$nocoord++;
				}
				$rows[$r]->{'CID'} = substr($rows[$r]->{'Crime ID'}||"",0,8);
			}
			# Create a new file
			msg("Save processed version to <cyan>$tempdir$files[$f]{'file'}<none>\n");
			open($fh,">:utf8",$tempdir.$files[$f]{'file'});
			print $fh join(",",@fields)."\n";
			for($r = 0; $r < @rows; $r++){
				for($i = 0; $i < @fields; $i++){
					print $fh ($i > 0 ? ",":"").($rows[$r]->{$fields[$i]}||"");
				}
				print $fh "\n";
			}
			close($fh);
		}
	}
}

for($f = 0; $f < @files; $f++){
	$files[$f]{'file'} =~ /([0-9]{4})-([0-9]{2})/;
	$yy = $1;
	$mm = $2;
	if($yy."-".$mm gt $lastmonth){
		$lastmonth = $yy."-".$mm;
	}
}

$nocoord = 0;
# Now process the data
for($f = 0; $f < @files; $f++){
	$files[$f]{'file'} =~ /([0-9]{4})-([0-9]{2})/;
	$yy = $1;
	$mm = $2;
	$year->{$yy} = 1;
	@rows = LoadCSV($tempdir.$files[$f]{'file'});
	for($r = 0; $r < @rows; $r++){
		if($rows[$r]->{'PCON24CD'} && $rows[$r]->{'Crime type'}){
			$pcon = $rows[$r]->{'PCON24CD'};
			$typ = $rows[$r]->{'Crime type'};
			if($typ && $pcon =~ /[ENSW][0-9]{8}/){
				if(!$types->{$typ}){ $types->{$typ} = 0; }
				$types->{$typ}++;
				$types->{'All'}++;
				if(!$crimes->{$pcon}){ $crimes->{$pcon} = {'All'=>{}}; }
				if(!$crimes->{$pcon}{$typ}){ $crimes->{$pcon}{$typ} = {}; }
				if(!$crimes->{$pcon}{$typ}{$yy}){ $crimes->{$pcon}{$typ}{$yy} = 0; }
				if(!$crimes->{$pcon}{'All'}{$yy}){ $crimes->{$pcon}{'All'}{$yy} = 0; }
				$crimes->{$pcon}{$typ}{$yy}++;
				$crimes->{$pcon}{'All'}{$yy}++;
			}else{
				warning("No type given for row <green>$r<none>.\n");
			}
		}else{
			$nocoord++;
		}
	}
	if($f%50==0){
		saveData();
	}
}
saveData();


updateCreationTimestamp($basedir."../../src/themes/society/crime/index.vto");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/all.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/anti_social_behaviour.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/bicycle_theft.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/burglary.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/criminal_damage.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/drugs.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/other.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/public_order.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/robbery.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/shoplifting.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/theft_from_the_person.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/vehicle.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/violence.json");
updateCreationTimestamp($basedir."../../src/themes/society/crime/_data/weapons.json");




############################################

sub saveData {
	my ($t,$y,$csv,$pcon,$v,@ctypes,@ys,@pcons);
	@ctypes = sort(keys(%{$types}));
	@ys = sort(keys(%{$year}));

	$csv = "PCON24CD,PCON24NM,Population (2022)";
	for($t=0;$t < @ctypes;$t++){
		for($y=0;$y < @ys;$y++){
			$csv .= ",$ctypes[$t]";
	#		$csv .= ",$ctypes[$t]";
		}
	}
	$csv .= "\n,,";
	for($t=0;$t < @ctypes;$t++){
		for($y=0;$y < @ys;$y++){
			$csv .= ",$ys[$y]";
	#		$csv .= ",$ys[$y]";
		}
	}
	#$csv .= "\n,";
	#for($t=0;$t < @ctypes;$t++){
	#	for($y=0;$y < @ys;$y++){
	#		$csv .= ",Value";
	#		$csv .= ",100k";
	#	}
	#}
	$csv .= "\n---,---,---";
	for($t=0;$t < @ctypes;$t++){
		for($y=0;$y < @ys;$y++){
			$csv .= ",---";
	#		$csv .= ",---";
		}
	}

	$csv .= "\n";

	@pcons = sort(keys(%{$hexjson->{'hexes'}}));

	foreach $pcon (@pcons){
		$csv .= $pcon;
		$csv .= ",\"".($hexjson->{'hexes'}{$pcon}{'n'}||"")."\"";
		if(!defined($popdata->{$pcon}{'total'})){
			warning("No population data for $pcon.\n");
			$csv .= ",0";
		}else{
			$csv .= ",".$popdata->{$pcon}{'total'};
		}
		for($t = 0 ; $t < @ctypes ; $t++){
			for($y = 0 ; $y < @ys ; $y++){
				$v = 0;
				if(defined($crimes->{$pcon}{$ctypes[$t]}) && defined($crimes->{$pcon}{$ctypes[$t]}{$ys[$y]})){
					$v = $crimes->{$pcon}{$ctypes[$t]}{$ys[$y]};
				}
				if(!defined($v)){ $v = 0; }
				$csv .= ",".$v;
				#if(defined($popdata->{$pcon}{'Mid 2022'})){
				#	$csv .= ",".sprintf("%0.1f",($v > 0 && $popdata->{$pcon}{'Mid 2022'} > 0 ? $v*100000/$popdata->{$pcon}{'Mid 2022'} : "0"));
				#}else{
				#	$csv .= ",";
				#}
			}
		}
		$csv .= "\n";
	}


	msg("Saving to <cyan>$ofile<none>\n");
	open($fh,">:utf8",$ofile);
	print $fh $csv;
	close($fh);

}

