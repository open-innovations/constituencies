#!/usr/bin/perl
# Script to process GP data from NHS England

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
my $outfile = $basedir."../../src/themes/health/gp/_data/release/gps.csv";
my $geojson = $basedir."../Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BFE.geojson";


my (@items,$i,$lookup,$pcon,$totals,$name,$namesafe,$fbkfile,$pcds,@rows,$ll,$geo,$match,$code,$constituencies,$n,$json,$url,$gp,@all,$csvfile,@resources,$hexjson);

if(!-d $rawdir){
	makeDir($rawdir);
}


# Read in the HexJSON and build the lookup
$hexjson = LoadJSON($hexfile);


# Load the constituency GeoJSON file
$geo = new OpenInnovations::GeoJSON;
if(!-e $geojson){
	error("Need a GeoJSON file for constituencies\n");
	exit;
}
$geo->load($geojson);


# Load the postcode data
$pcds = new OpenInnovations::Postcodes;
$pcds->setFile($pcdfile);


# Read in the NHS England GP practices file
SaveFromURL("https://files.digital.nhs.uk/assets/ods/current/epraccur.zip",$rawdir."epraccur.zip");
`unzip -o $rawdir/epraccur.zip -d $rawdir`;
@rows = LoadCSV($rawdir."epraccur.csv",{
	"header"=>{
		"columns"=>["Organisation Code","Name","National Grouping","High Level Health Geography","Address Line 1","Address Line 2","Address Line 3","Address Line 4","Address Line 5","Postcode","Open Date","Close Date","Status Code","Organisation Sub-Type Code","Commissioner","Join Provider/Purchaser Date","Left Provider/Purchaser Date","Contact Telephone Number","Column 19","Column 20","Column 21","Amended Record Indicator","Column 23","Column 24","Column 25","Prescribing Setting","Column 27"]
	},
	"startrow"=>0
});
for($i = 0; $i < @rows; $i++){
	if($rows[$i]->{'Status Code'} eq "A" && defined($rows[$i]->{'Postcode'})){
		$gp = {
			'name'=>$rows[$i]->{'Name'},
			'postcode'=>$rows[$i]->{'Postcode'}
		};
		if($rows[$i]->{'Prescribing Setting'} eq "4" && $rows[$i]->{'Close Date'} eq ""){
			$gp->{'type'} = "GP Practice";
			push(@all,$gp);
		}
	}else{
		warning("No postcode for row $i of <cyan>epraccur.csv<none>\n");
	}
}


# Read in the NHS England GP branches file
SaveFromURL("https://files.digital.nhs.uk/assets/ods/current/ebranchs.zip",$rawdir."ebranchs.zip");
`unzip -o $rawdir/ebranchs.zip -d $rawdir`;
@rows = LoadCSV($rawdir."ebranchs.csv",{
	"header"=>{
		"columns"=>["Organisation Code","Name","National Grouping","High Level Health Geography","Address Line 1","Address Line 2","Address Line 3","Address Line 4","Address Line 5","Postcode","Open Date","Close Date","Column 13","Column 14","Parent Organisation Code Commissioner","Join Parent Date","Left Parent Date","Contact Telephone Number","Column 19","Column 20","Column 21","Amended Record Indicator","Column 23","GOR Code","Column 25","Column 26","Column 27"]
	},
	"startrow"=>0
});
for($i = 0; $i < @rows; $i++){
	if(defined($rows[$i]->{'Postcode'}) && $rows[$i]->{'Close Date'} eq "" && $rows[$i]->{'Name'} !~ /COVID LOCAL VACCINATION SERVICE/i){
		
		$gp = {
			'name'=>$rows[$i]->{'Name'},
			'postcode'=>$rows[$i]->{'Postcode'}
		};
		$gp->{'type'} = "GP Branch";
		push(@all,$gp);
	}else{
		warning("No postcode for row $i of <cyan>ebranchs.csv<none>\n");
	}
}


# Read in the Scottish GPs https://www.opendata.nhs.scot/dataset/gp-practice-contact-details-and-list-sizes
SaveFromURL("https://www.opendata.nhs.scot/api/3/action/package_show?id=gp-practice-contact-details-and-list-sizes",$rawdir."gps-scot.json");
$json = LoadJSON($rawdir."gps-scot.json");
@resources = reverse(sort{ $a->{'created'} cmp $b->{'created'} }(@{$json->{'result'}{'resources'}}));
$url = "";
for($i = 0; $i < @resources; $i++){
	if($resources[$i]->{'name'} =~ /GP Practices/i){
		$url = $resources[$i]->{'url'};
		last;
	}
}
if($url){
	$csvfile = "gps-scot.csv";
	SaveFromURL($url,$rawdir.$csvfile);
	@rows = LoadCSV($rawdir.$csvfile,{});
	for($i = 0; $i < @rows; $i++){
		if(defined($rows[$i]->{'Postcode'})){
			$gp = {
				'name'=>$rows[$i]->{'GPPracticeName'},
				'postcode'=>$rows[$i]->{'Postcode'},
				'type'=>'GP Practice'
			};
			push(@all,$gp);
		}else{
			warning("No postcode for row $i of <cyan>$csvfile<none>\n");
		}
	}
}else{
	warning("Couldn't find a dental surgery list in https://www.opendata.nhs.scot/dataset/gp-practice-contact-details-and-list-sizes\n");
}



# Read in the OpenDataNI dentists https://www.opendatani.gov.uk/dataset/gp-practice-list-sizes
SaveFromURL("https://admin.opendatani.gov.uk/api/3/action/package_show?id=gp-practice-list-sizes",$rawdir."gps-ni.json");
$json = LoadJSON($rawdir."gps-ni.json");
@resources = reverse(sort{ $a->{'created'} cmp $b->{'created'} }(@{$json->{'result'}{'resources'}}));
$url = "";
for($i = 0; $i < @resources; $i++){
	if($resources[$i]->{'name'} =~ /GP Practice/i){
		$url = $resources[$i]->{'url'};
		last;
	}
}
if($url){
	$csvfile = "gps-ni.csv";
	SaveFromURL($url,$rawdir.$csvfile);
	@rows = LoadCSV($rawdir.$csvfile,{
		'ANSI'=>1
	});
	for($i = 0; $i < @rows; $i++){
		if(defined($rows[$i]->{'Postcode'})){
			$gp = {
				'name'=>$rows[$i]->{'PracticeName'},
				'postcode'=>$rows[$i]->{'Postcode'},
				'type'=>'GP Practice'
			};
			push(@all,$gp);
		}else{
			warning("No postcode for row $i of <cyan>$csvfile<none>\n");
		}
	}
}else{
	warning("Couldn't find a dental surgery list in https://admin.opendatani.gov.uk/dataset/general-dental-services-statistics\n");
}






# Process the big, simple, list of GPs
for($i = 0; $i < @all; $i++){
	$ll = $pcds->getPostcode($all[$i]->{'postcode'});
	if($all[$i]->{'postcode'} eq "LS16 7QD"){
		print Dumper $all[$i];
		exit;
	}
	if(defined($ll) && defined($ll->{'lat'}) && defined($ll->{'lon'})){
		$all[$i]->{'lat'} = $ll->{'lat'};
		$all[$i]->{'lon'} = $ll->{'lon'};
		$match = $geo->getFeatureAt($all[$i]->{'lat'},$all[$i]->{'lon'});
		$code = $match->{'properties'}{'PCON24CD'};
		if(defined($code)){
			if(!(defined($constituencies->{$code}))){
				$constituencies->{$code} = {'Practice'=>0,'Branch'=>0,'all'=>0,'names'=>''};
			}
			if($all[$i]->{'type'} eq "GP Practice"){
				$constituencies->{$code}{'Practice'}++;
				$constituencies->{$code}{'all'}++;
			}elsif($all[$i]->{'type'} eq "GP Branch"){
				$constituencies->{$code}{'Branch'}++;
				$constituencies->{$code}{'all'}++;
			}else{
				warning("Bad sub-type code <green>".$all[$i]->{'type'}."<none>\n");
			}
			$constituencies->{$code}{'names'} .= ($constituencies->{$code}{'names'} ? "; ":"").$all[$i]->{'name'};
		}else{
			warning("No match for $all[$i]->{'lat'}/$all[$i]->{'lon'}\n");
		}
	}else{
		warning("Bad coordinates row $i\n");
	}
}

$pcds->save();


open(my $fh,">:utf8",$outfile) || error("Unable to save to <cyan>$outfile<none>\n");
print $fh "PCON24CD,PCON24NM,All,GP practices,GP branch surgeries\n";
foreach $code (sort(keys(%{$constituencies}))){
	$name = $hexjson->{'hexes'}{$code}{'n'}||"";
	$constituencies->{$code}{'names'} = lc($constituencies->{$code}{'names'}||"");
	$constituencies->{$code}{'names'} =~ s/\b(\w)/\U$1/g;
	print $fh ($code).",".($name =~ /\,/ ? "\"$name\"" : $name).",".($constituencies->{$code}{'all'}||0).",".($constituencies->{$code}{'Practice'}||"0").",".($constituencies->{$code}{'Branch'}||"0")."\n";#.",\"".($constituencies->{$code}{'names'})."\"\n";
}
close($fh);
msg("Saved to <cyan>$outfile<none>\n");


updateCreationTimestamp($basedir."../../src/themes/health/gp/index.vto");
updateCreationTimestamp($basedir."../../src/themes/health/gp/_data/map-1.json");





