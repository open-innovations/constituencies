#!/usr/bin/perl
# Script to process optician data from NHS England

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
use OpenInnovations::Postcodes;
use OpenInnovations::GeoJSON;
require "lib.pl";

my $hexfile = $basedir."../../src/_data/hexjson/uk-constituencies-2024.hexjson";
my $rawdir = $basedir."../../raw-data/health/";
my $pcdfile = $rawdir."pcd.csv";
my $optfile = $rawdir."opticians.zip";
my $csvfile = "egdpprac.csv";
my $outfile = $basedir."../../src/themes/health/opticians/_data/release/opticians.csv";
my $geojson = $basedir."../../raw-data/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC.geojson";


my ($hexjson,@items,$i,$lookup,$pcon,$totals,$name,$namesafe,$fbkfile,$pcds,@rows,$ll,$geo,$match,$code,$constituencies,$n,@allopticians,$optician,$json,$url,$now);

# Read in the HexJSON and build the lookup
$hexjson = LoadJSON($hexfile);

$now = strftime("%Y%M%d", localtime());


# Load the constituency GeoJSON file
$geo = new OpenInnovations::GeoJSON;
if(!-e $geojson){
	SaveFromURL("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson",$geojson);
}
$geo->load($geojson);


# Load the postcode data
$pcds = new OpenInnovations::Postcodes;
$pcds->setFile($pcdfile);


# Read in the NHS England opticians file
SaveFromURL("https://files.digital.nhs.uk/assets/ods/current/eoptsite.zip",$optfile);
`unzip -o $optfile -d $rawdir`;
@rows = LoadCSV($rawdir.$csvfile,{
	"header"=>{
		"columns"=>["Organisation Code","Name","National Grouping","High Level Health Geography","Address Line 1","Address Line 2","Address Line 3","Address Line 4","Address Line 5","Postcode","Open Date","Close Date","Column 13","Column 14","Parent Organisation Code","Join Parent Date","Left Parent Date","Contact Telephone Number","Contact Name","Column 20","Column 21","Amended Record Indicator","Column 23","Current Care Organisation","Column 25","Column 26","Column 27"]
	},
	"startrow"=>0
});

for($i = 0; $i < @rows; $i++){
	if($rows[$i]->{'Close Date'} eq "" || $rows[$i]->{'Close Date'} gt $now){
		if(defined($rows[$i]->{'Postcode'})){
			$optician = {
				'postcode'=>$rows[$i]->{'Postcode'}
			};
			push(@allopticians,$optician);
		}else{
			warning("No postcode for row $i of <cyan>$csvfile<none>\n");
		}
	}
}




# Process the big, simple, list of dentists
for($i = 0; $i < @allopticians; $i++){
	$ll = $pcds->getPostcode($allopticians[$i]->{'postcode'});
	if(defined($ll) && defined($ll->{'lat'}) && defined($ll->{'lon'})){
		$allopticians[$i]->{'lat'} = $ll->{'lat'};
		$allopticians[$i]->{'lon'} = $ll->{'lon'};
		$match = $geo->getFeatureAt($allopticians[$i]->{'lat'},$allopticians[$i]->{'lon'});
		$code = $match->{'properties'}{'PCON24CD'};
		if(defined($code)){
			if(!(defined($constituencies->{$code}))){
				$constituencies->{$code} = {'all'=>0};
			}
			$constituencies->{$code}{'all'}++;
		}else{
			warning("No match for $allopticians[$i]->{'lat'}/$allopticians[$i]->{'lon'}\n");
		}
	}else{
		warning("Bad coordinates row $i\n");
	}
}

$pcds->save();

open(my $fh,">:utf8",$outfile) || error("Unable to save to <cyan>$outfile<none>\n");
print $fh "PCON24CD,PCON24NM,Opticians\n";
foreach $code (sort(keys(%{$constituencies}))){
	$name = $hexjson->{'hexes'}{$code}{'n'}||"";
	print $fh ($code).",".($name =~ /\,/ ? "\"$name\"" : $name).",".($constituencies->{$code}{'all'}||0)."\n";
}
close($fh);
msg("Saved to <cyan>$outfile<none>\n");


updateCreationTimestamp($basedir."../../src/themes/health/opticians/index.vto");
updateCreationTimestamp($basedir."../../src/themes/health/opticians/_data/map-1.json");





