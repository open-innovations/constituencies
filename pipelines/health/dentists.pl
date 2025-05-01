#!/usr/bin/perl
# Script to process dentist data from NHS England

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
use OpenInnovations::Postcodes;
use OpenInnovations::GeoJSON;
require "lib.pl";

my $hexfile = $basedir."../../src/_data/hexjson/uk-constituencies-2024.hexjson";
my $rawdir = $basedir."../../raw-data/health/";
my $pcdfile = $rawdir."pcd.csv";
my $denfile = $rawdir."dentists.zip";
my $csvfile = "egdpprac.csv";
my $outfile = $basedir."../../src/themes/health/dentists/_data/release/dentists.csv";
my $geojson = $basedir."../../src/_data/geojson/constituencies-2024.geojson";


my (@items,$i,$lookup,$pcon,$totals,$name,$namesafe,$fbkfile,$pcds,@rows,$ll,$geo,$match,$code,$constituencies,$n);

# Read in the HexJSON and build the lookup
my $hexjson = LoadJSON($hexfile);


# Load the constituency GeoJSON file
$geo = new OpenInnovations::GeoJSON;
$geo->load($geojson);


# Load the postcode data
$pcds = new OpenInnovations::Postcodes;
$pcds->setFile($pcdfile);


# Read in the NHS England dentists file
SaveFromURL("https://files.digital.nhs.uk/assets/ods/current/egdpprac.zip",$denfile);
`unzip -o $denfile -d $rawdir`;
@rows = LoadCSV($rawdir.$csvfile,{
	"header"=>{
		"columns"=>["Organisation Code","Name","National Grouping","High Level Health Geography","Address Line 1","Address Line 2","Address Line 3","Address Line 4","Address Line 5","Postcode","Open Date","Close Date","Status Code","Organisation Sub-Type Code","Parent Organisation Code","Join Parent Date","Left Parent Date","Contact Telephone Number","Column 19","Column 20","Column 21","Amended Record Indicator","Column 23","Column 24","Column 25","Column 26","Column 27"]
	},
	"startrow"=>0
});


for($i = 0; $i < @rows; $i++){
	if($rows[$i]->{'Status Code'} eq "A" && defined($rows[$i]->{'Postcode'})){
		$ll = $pcds->getPostcode($rows[$i]->{'Postcode'});
		if(defined($ll) && defined($ll->{'lat'}) && defined($ll->{'lon'})){
			$rows[$i]->{'lat'} = $ll->{'lat'};
			$rows[$i]->{'lon'} = $ll->{'lon'};
			$match = $geo->getFeatureAt($rows[$i]->{'lat'},$rows[$i]->{'lon'});
			$code = $match->{'properties'}{'PCON24CD'};
			if(defined($code)){
				if(!(defined($constituencies->{$code}))){
					$constituencies->{$code} = {'NHS'=>0,'Private'=>0};
				}
				if($rows[$i]->{'Organisation Sub-Type Code'} eq "D"){
					$constituencies->{$code}{'NHS'}++;
				}elsif($rows[$i]->{'Organisation Sub-Type Code'} eq "P"){
					$constituencies->{$code}{'Private'}++;
				}else{
					warning("Bad sub-type code <green>".$rows[$i]->{'Organisation Sub-Type Code'}."<none>\n");
				}
			}else{
				warning("No match for $rows[$i]->{'lat'},$rows[$i]->{'lon'}\n");
			}
		}else{
			warning("Bad coordinates row $i\n");
		}
	}else{
		warning("No postcode for row $i\n");
	}
}

$pcds->save();


open(my $fh,">:utf8",$outfile) || error("Unable to save to <cyan>$outfile<none>\n");
print $fh "PCON24CD,PCON24NM,All dentists,NHS dentists,Private dentists\n";
foreach $code (sort(keys(%{$constituencies}))){
	$name = $hexjson->{'hexes'}{$code}{'n'}||"";
	$n = 0;
	if(defined($constituencies->{$code}{'NHS'})){ $n += $constituencies->{$code}{'NHS'}; }
	if(defined($constituencies->{$code}{'Private'})){ $n += $constituencies->{$code}{'Private'}; }
	print $fh ($code).",".($name =~ /\,/ ? "\"$name\"" : $name).",".($n).",".($constituencies->{$code}{'NHS'}||"0").",".($constituencies->{$code}{'Private'}||"0")."\n";
}
close($fh);
msg("Saved to <cyan>$outfile<none>\n");


updateCreationTimestamp($basedir."../../src/themes/health/dentists/index.vto");
updateCreationTimestamp($basedir."../../src/themes/health/dentists/_data/map-1.json");





