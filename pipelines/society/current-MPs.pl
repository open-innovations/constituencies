#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use JSON::XS;
use Data::Dumper;
use Cwd qw(abs_path);
use MIME::Base64 qw(encode_base64);
use IPC::Cmd qw[can_run run run_forked];
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."../lib/";	# Custom functions
require "lib.pl";

my ($baseurl,$tmpdir,$url,$page,$json,$thumbs,$makethumbs,$p,$qs,$count,$total,$txt,$file,$fh,$out,$i,$n,$dir,$csv,$mp,$hexjson,%hexlookup,$id,$code,$row,@rows,$twfyfile,$pcon,$thumbfile,$size,$args);

$tmpdir = $basedir."../../raw-data/";
$dir = $tmpdir."society/parliament/";
$makethumbs = can_run("convert");

if(!-d $dir){ makeDir($dir); }
if($makethumbs && !-d $dir."thumbs/"){ makeDir($dir."thumbs/"); }



# Get Constituency IDs from HexJSON
$hexjson = LoadJSON($basedir."../../src/_data/hexjson/uk-constituencies-2024.hexjson");
foreach $id (keys(%{$hexjson->{'hexes'}})){
	$hexlookup{$hexjson->{'hexes'}{$id}{'n'}} = $id;
}


# TheyWorkForYou MPs CSV
$twfyfile = $tmpdir."society/parliament/twfy.csv";
msg("Saving They Work For You MP data to <cyan>$twfyfile<none>\n");
CacheDownload("https://www.theyworkforyou.com/mps/?f=csv",$twfyfile,86400);


# Get all current, sitting, MPs from Parliament
$baseurl = "https://members-api.parliament.uk/api/Members/Search";
$qs = "House=1&IsCurrentMember=true&IsEligible=true";
$p = 1;
$count = 0;
$total = 650;
$out = {'MPs'=>[]};
msg("Saving API data to <cyan>$dir<none>\n");
while($count < $total){
	$url = $baseurl."?".$qs."&skip=$count&take=20";
	$file = $dir."MPs-$p.json";
	$txt = CacheDownload($url,$file,86400);
	$json = ParseJSON($txt);
	$n = @{$json->{'items'}};
	for($i = 0; $i < $n; $i++){
		if(!defined($json->{'items'}[$i]{'value'}{'latestParty'}{'backgroundColour'})){
			warning("No colour for $json->{'items'}[$i]{'value'}{'nameDisplayAs'}\n");
		}
		push(@{$out->{'MPs'}},{
			'MP'=>$json->{'items'}[$i]{'value'}{'nameDisplayAs'},
			'ID'=>$json->{'items'}[$i]{'value'}{'id'},
			'Gender'=>$json->{'items'}[$i]{'value'}{'gender'},
			'PCON24CD'=>$hexlookup{$json->{'items'}[$i]{'value'}{'latestHouseMembership'}{'membershipFrom'}},
			'PCON24NM'=>$json->{'items'}[$i]{'value'}{'latestHouseMembership'}{'membershipFrom'},
			'Start date'=>$json->{'items'}[$i]{'value'}{'latestHouseMembership'}{'membershipStartDate'},
			'Thumbnail'=>$json->{'items'}[$i]{'value'}{'thumbnailUrl'},
			'Party'=>$json->{'items'}[$i]{'value'}{'latestParty'}{'abbreviation'},
			'Party name'=>$json->{'items'}[$i]{'value'}{'latestParty'}{'name'},
			'Party bg'=>'#'.($json->{'items'}[$i]{'value'}{'latestParty'}{'backgroundColour'}||"4d4d4d"),
			'Party fg'=>'#'.($json->{'items'}[$i]{'value'}{'latestParty'}{'foregroundColour'}||"ffffff"),
		});
	}
	$count += @{$json->{'items'}};
	$total = $json->{'totalResults'};
	$p++;
}

$json = LoadCSV($twfyfile,{'key'=>'Constituency'});

$size = 120;
$args = "-auto-orient -thumbnail ".$size."x".$size."^ -gravity center -extent ".$size."x".$size." -background transparent -quality 90  -strip";
for($i = 0; $i < @{$out->{'MPs'}};$i++){
	$pcon = $out->{'MPs'}[$i]{'PCON24NM'};
	if(defined($json->{$pcon})){
		$out->{'MPs'}[$i]{'TheyWorkForYou ID'} = $json->{$pcon}{'Person ID'};
		$out->{'MPs'}[$i]{'TheyWorkForYou URI'} = $json->{$pcon}{'URI'};
	}
}


$json = {};
$thumbs = {};
for($i = 0; $i < @{$out->{'MPs'}};$i++){
	$json->{$out->{'MPs'}[$i]{'PCON24CD'}} = $out->{'MPs'}[$i];
	if($makethumbs && $out->{'MPs'}[$i]{'Thumbnail'}){
		msg("Processing thumbnail from <cyan>$out->{'MPs'}[$i]{'Thumbnail'}<none> with $args\n");
		$thumbfile = $dir."thumbs/".$out->{'MPs'}[$i]{'ID'};
		CacheDownloadNoReturn($out->{'MPs'}[$i]{'Thumbnail'},$thumbfile,6*86400);
		msg($out->{'MPs'}[$i]{'Thumbnail'}."\n");
		if(!-e $thumbfile.".webp"){
			`convert \"$thumbfile\" $args \"$thumbfile.webp\"`;
		}
		$thumbs->{$out->{'MPs'}[$i]{'PCON24CD'}} = "data:image/webp;base64,".get64($thumbfile = $dir."thumbs/".$out->{'MPs'}[$i]{'ID'}.".webp");
	}
}
SaveJSON($json,$basedir."../../lookups/current-MPs.json",1);
if($makethumbs){
	SaveJSON($thumbs,$basedir."../../lookups/current-MPs-thumbnails.json",1);
}


for($i = 0; $i < @{$out->{'MPs'}};$i++){
	$mp = $out->{'MPs'}[$i];
	$code = $hexlookup{$mp->{'PCON24NM'}};
	$row = $code;
	$row .= ",".($mp->{'PCON24NM'} =~ /,/ ? "\"$mp->{'PCON24NM'}\"":$mp->{'PCON24NM'});
	$row .= ",".($mp->{'MP'} =~ /,/ ? "\"$mp->{'MP'}\"":$mp->{'MP'});
	$row .= ",".$mp->{'Gender'};
	$row .= ",".$mp->{'ID'};
	$row .= ",".($mp->{'TheyWorkForYou ID'}||"");
	$row .= ",".($mp->{'TheyWorkForYou URI'}||"");
	$row .= ",".$mp->{'Start date'};
	$row .= ",".($mp->{'Party'} =~ /,/ ? "\"$mp->{'Party'}\"":$mp->{'Party'});
	$row .= ",".($mp->{'Party name'} =~ /,/ ? "\"$mp->{'Party name'}\"":$mp->{'Party name'});
	$row .= ",".$mp->{'Party bg'};
	$row .= ",".$mp->{'Party fg'};
	$row .= ",".$mp->{'Thumbnail'};
	$row .= "\n";
	push(@rows,$row);
}
@rows = sort(@rows);
$file = $basedir."../../lookups/current-MPs.csv";
msg("Saving lookup to <cyan>$file<none>\n");
open($fh,">:utf8",$file);
print $fh "PCON24CD,PCON24NM,MP,Gender,ID,TheyWorkForYou ID,TheyWorkForYou URI,Start date,Party,Party name,Party bg,Party fg,Thumbnail\n";
print $fh @rows;
close($fh);



##################

sub get64 {
	my $file = shift;
	my ($fh,$buf,$str);
	open($fh, $file) or die "$!";
	$str = "";
	while (read($fh, $buf, 60*57)) {
		$str .= encode_base64($buf);
	}
	close($fh);
	$str =~ s/[\n\r]//g;
	return $str;
}