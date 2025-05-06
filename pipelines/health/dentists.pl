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
my $geojson = $basedir."../../raw-data/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC.geojson";


my (@items,$i,$lookup,$pcon,$totals,$name,$namesafe,$fbkfile,$pcds,@rows,$ll,$geo,$match,$code,$constituencies,$n,@alldentists,$dentist,$json,$url);

# Read in the HexJSON and build the lookup
my $hexjson = LoadJSON($hexfile);


# Load the constituency GeoJSON file
$geo = new OpenInnovations::GeoJSON;
if(!-e $geojson){
	SaveFromURL("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson",$geojson);
}
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
		$dentist = {
			'postcode'=>$rows[$i]->{'Postcode'}
		};
		if($rows[$i]->{'Organisation Sub-Type Code'} eq "D"){
			$dentist->{'type'} = "NHS";
		}elsif($rows[$i]->{'Organisation Sub-Type Code'} eq "P"){
			$dentist->{'type'} = "Private";
		}else{
			warning("Bad sub-type code <green>".$rows[$i]->{'Organisation Sub-Type Code'}."<none>\n");
		}
		push(@alldentists,$dentist);
	}else{
		warning("No postcode for row $i of <cyan>$csvfile<none>\n");
	}
}

# Read in the OpenDataNI dentists https://admin.opendatani.gov.uk/dataset/general-dental-services-statistics
SaveFromURL("https://admin.opendatani.gov.uk/api/3/action/package_show?id=general-dental-services-statistics",$rawdir."dentists-ni.json");
$json = LoadJSON($rawdir."dentists-ni.json");
my @resources = reverse(sort{ $a->{'created'} cmp $b->{'created'} }(@{$json->{'result'}{'resources'}}));
$url = "";
for($i = 0; $i < @resources; $i++){
	if($resources[$i]->{'name'} =~ /Dental Surgery List/i){
		$url = $resources[$i]->{'url'};
		last;
	}
}
if($url){
	$csvfile = "dentists-ni.csv";
	SaveFromURL($url,$rawdir.$csvfile);
	@rows = LoadCSV($rawdir.$csvfile,{
		'ANSI'=>1
	});
	for($i = 0; $i < @rows; $i++){
		if(defined($rows[$i]->{'POSTCODE'})){
			$dentist = {
				'postcode'=>$rows[$i]->{'POSTCODE'},
				'type'=>$rows[$i]->{'DENTIST_TYPE'}
			};
			push(@alldentists,$dentist);
		}else{
			warning("No postcode for row $i of <cyan>$csvfile<none>\n");
		}
	}
}else{
	warning("Couldn't find a dental surgery list in https://admin.opendatani.gov.uk/dataset/general-dental-services-statistics\n");
}


# Read in the Scottish dentists https://www.opendata.nhs.scot/dataset/dental-practices-and-patient-registrations
SaveFromURL("https://www.opendata.nhs.scot/api/3/action/package_show?id=dental-practices-and-patient-registrations",$rawdir."dentists-scot.json");
$json = LoadJSON($rawdir."dentists-scot.json");
my @resources = reverse(sort{ $a->{'created'} cmp $b->{'created'} }(@{$json->{'result'}{'resources'}}));
$url = "";
for($i = 0; $i < @resources; $i++){
	if($resources[$i]->{'name'} =~ /Dental Practices/i){
		$url = $resources[$i]->{'url'};
		last;
	}
}
if($url){
	$csvfile = "dentists-scot.csv";
	SaveFromURL($url,$rawdir.$csvfile);
	@rows = LoadCSV($rawdir.$csvfile,{});
	for($i = 0; $i < @rows; $i++){
		if(defined($rows[$i]->{'pc7'})){
			$dentist = {
				'postcode'=>$rows[$i]->{'pc7'},
				'type'=>'NHS'
			};
			push(@alldentists,$dentist);
		}else{
			warning("No postcode for row $i of <cyan>$csvfile<none>\n");
		}
	}
}else{
	warning("Couldn't find a dental surgery list in https://www.opendata.nhs.scot/dataset/dental-practices-and-patient-registrations\n");
}






# Process the big, simple, list of dentists
for($i = 0; $i < @alldentists; $i++){
	$ll = $pcds->getPostcode($alldentists[$i]->{'postcode'});
	if(defined($ll) && defined($ll->{'lat'}) && defined($ll->{'lon'})){
		$alldentists[$i]->{'lat'} = $ll->{'lat'};
		$alldentists[$i]->{'lon'} = $ll->{'lon'};
		$match = $geo->getFeatureAt($alldentists[$i]->{'lat'},$alldentists[$i]->{'lon'});
		$code = $match->{'properties'}{'PCON24CD'};
		if(defined($code)){
			if(!(defined($constituencies->{$code}))){
				$constituencies->{$code} = {'NHS'=>0,'Private'=>0};
			}
			if($alldentists[$i]->{'type'} eq "NHS"){
				$constituencies->{$code}{'NHS'}++;
				$constituencies->{$code}{'all'}++;
			}elsif($alldentists[$i]->{'type'} eq "Private"){
				$constituencies->{$code}{'Private'}++;
				$constituencies->{$code}{'all'}++;
			}elsif($alldentists[$i]->{'type'} eq "GDS"){
				$constituencies->{$code}{'all'}++;
				$constituencies->{$code}{'NHS'}++;
			}else{
				warning("Bad sub-type code <green>".$alldentists[$i]->{'type'}."<none>\n");
			}
		}else{
			warning("No match for $alldentists[$i]->{'lat'}/$alldentists[$i]->{'lon'}\n");
		}
	}else{
		warning("Bad coordinates row $i\n");
	}
}

$pcds->save();


open(my $fh,">:utf8",$outfile) || error("Unable to save to <cyan>$outfile<none>\n");
print $fh "PCON24CD,PCON24NM,All dentists,NHS dentists,Private dentists\n";
foreach $code (sort(keys(%{$constituencies}))){
	$name = $hexjson->{'hexes'}{$code}{'n'}||"";
	print $fh ($code).",".($name =~ /\,/ ? "\"$name\"" : $name).",".($constituencies->{$code}{'all'}||0).",".($constituencies->{$code}{'NHS'}||"0").",".($constituencies->{$code}{'Private'}||"0")."\n";
}
close($fh);
msg("Saved to <cyan>$outfile<none>\n");


updateCreationTimestamp($basedir."../../src/themes/health/dentists/index.vto");
updateCreationTimestamp($basedir."../../src/themes/health/dentists/_data/map-1.json");





