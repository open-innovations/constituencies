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
use OpenInnovations::GeoJSON;
require "lib.pl";

my ($geo,$str,$hexfile,$outfile,$geojson,$hexjson,$match,$code,$constituencies,$lat,$lon,$name,$cname,$i,$url,$temp,$total,$period,$party,$mps,$mpfile);

$hexfile = $basedir."../../src/_data/hexjson/uk-constituencies-2024.hexjson";
$outfile = $basedir."../../src/themes/health/private-healthcare-related-donations/_data/release/donations.csv";
$geojson = $basedir."../../raw-data/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC.geojson";
$mpfile = $basedir."../../lookups/current-MPs.csv";


# Read in the HexJSON and build the lookup
$hexjson = LoadJSON($hexfile);

$mps = LoadCSV($mpfile,{'key'=>'PCON24CD'});


# Load the constituency GeoJSON file
$geo = new OpenInnovations::GeoJSON;
if(!-e $geojson){
	SaveFromURL("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson",$geojson);
}
$geo->load($geojson);

foreach $code (keys(%{$hexjson->{'hexes'}})){
	$constituencies->{$code} = {
		'Total'=>0,'Period'=>'',
		'Name'=>$hexjson->{'hexes'}{$code}{'n'},
		'MP'=>$mps->{$code}{'MP'},
		'Party'=>$mps->{$code}{'Party name'},
		'Link'=>'',
		'Link MP'=>''
	};
}

$str = GetURL("https://privatisation.everydoctor.org.uk/does-your-mp-receive-private-healthcare-related-donations/");

while($str =~ s/(<div style="display:none" class="wpv-addon-maps-marker.*?<\/div>)//s){
	$temp = $1;
	if($temp =~ /data-markerlat="([0-9\.]+)" data-markerlon="([0-9\.\-\+]+)"/){
		$lat = $1;
		$lon = $2;

		$match = $geo->getFeatureAt($lat,$lon);
		$code = $match->{'properties'}{'PCON24CD'};
		
		$cname = "";
		if($temp =~ /Constituency: <a href="([^\"]*)">([^\<]*)<\/a>/){
			$constituencies->{$code}{'Link'} = $1;
			$cname = $2;
		}

		if($temp =~ /([^\>]*?): abbreviated details/s){
			$constituencies->{$code}{'MP'} = $1;
			$url = lc($constituencies->{$code}{'MP'});
			$url =~ s/[\s\,]/\-/g;
			$url =~ s/\-+/\-/g;
			$constituencies->{$code}{'Link MP'} = "https://privatisation.everydoctor.org.uk/mp/".$url;
		}


		if($temp =~ /Political Party: <a[^\>]*>([^\<]*)<\/a>/s){
			$constituencies->{$code}{'Party'} = $1;
		}

		if($match->{'properties'}{'PCON24NM'} ne $cname){
			warning("Constituency was $cname but matches with $match->{'properties'}{'PCON24NM'}\n");
		}

		if(defined($code)){
			if(!(defined($constituencies->{$code}))){
				$constituencies->{$code} = {'Total'=>0,'Period'=>''};
			}
			if($temp =~ /Total amount received ([^\:]+): £([0-9\,]+)/){
				$period = $1;
				$total = $2;
				$total =~ s/\,//g;
				$constituencies->{$code}{'Total'} += $total;
				$constituencies->{$code}{'Period'} = $period;
			}
		}else{
			warning("No match for $lat/$lon\n");
		}

	}
}


open(my $fh,">:utf8",$outfile) || error("Unable to save to <cyan>$outfile<none>\n");
print $fh "PCON24CD,PCON24NM,MP,Party,Donations (£),Donation period,Constituency URL,MP URL\n";
foreach $code (sort(keys(%{$constituencies}))){
	$cname = $hexjson->{'hexes'}{$code}{'n'}||"";
	$name = $constituencies->{$code}{'MP'}||"";
	$party = $constituencies->{$code}{'Party'}||"";
	print $fh ($code).",".($cname =~ /\,/ ? "\"$cname\"" : $cname).",".($name =~ /\,/ ? "\"$name\"" : $name).",".($party =~ /\,/ ? "\"$party\"" : $party).",".($constituencies->{$code}{'Total'}||0).",".($constituencies->{$code}{'Period'}||"").",".($constituencies->{$code}{'Link'}||"").",".($constituencies->{$code}{'Link MP'}||"")."\n";
}
close($fh);
msg("Saved to <cyan>$outfile<none>\n");

exit;

updateCreationTimestamp($basedir."../../src/themes/health/private-healthcare-related-donations/index.vto");
updateCreationTimestamp($basedir."../../src/themes/health/private-healthcare-related-donations/_data/map-1.json");
