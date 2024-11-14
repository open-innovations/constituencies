#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use JSON::XS;
use Data::Dumper;
use Cwd qw(abs_path);
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';

# Get the real base directory for this script
my ($basedir, $path);
BEGIN { ($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$}; push @INC, $basedir; }

my ($baseurl,$url,$page,$json,$p,$qs,$count,$total,$txt,$file,$fh,$out,$i,$n,$dir,$csv,$mp,$hexjson,%hexlookup,$id,$code,$row,@rows);

# Get Constituency IDs from HexJSON
$hexjson = LoadJSON($basedir."../../src/_data/hexjson/uk-constituencies-2024.hexjson");
foreach $id (keys(%{$hexjson->{'hexes'}})){
	$hexlookup{$hexjson->{'hexes'}{$id}{'n'}} = $id;
}


# Get all current, sitting, MPs from Parliament
$baseurl = "https://members-api.parliament.uk/api/Members/Search";
$qs = "House=1&IsCurrentMember=true&IsEligible=true";
$p = 1;
$count = 0;
$total = 650;
$out = {'MPs'=>[]};
$dir = $basedir."../../raw-data/society/parliament/";
msg("Saving API data to <cyan>$dir<none>\n");
while($count < $total){
	$url = $baseurl."?".$qs."&skip=$count&take=20";
	$file = $dir."MPs-$p.json";
	$txt = CacheDownload($url,$file);
	$json = ParseJSON($txt);
	$n = @{$json->{'items'}};
	for($i = 0; $i < $n; $i++){
		if(!defined($json->{'items'}[$i]{'value'}{'latestParty'}{'backgroundColour'})){
			warning("No colour for $json->{'items'}[$i]{'value'}{'nameDisplayAs'}\n");
		}
		push(@{$out->{'MPs'}},{
			'ID'=>$json->{'items'}[$i]{'value'}{'id'},
			'Gender'=>$json->{'items'}[$i]{'value'}{'gender'},
			'MP'=>$json->{'items'}[$i]{'value'}{'nameDisplayAs'},
			'PCON24NM'=>$json->{'items'}[$i]{'value'}{'latestHouseMembership'}{'membershipFrom'},
			'StartDate'=>$json->{'items'}[$i]{'value'}{'latestHouseMembership'}{'membershipStartDate'},
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

SaveJSON($out,$basedir."../../raw-data/society/parliament/MPs-all.json",2);
for($i = 0; $i < @{$out->{'MPs'}};$i++){
	$mp = $out->{'MPs'}[$i];
	$code = $hexlookup{$mp->{'PCON24NM'}};
	$row = $code;
	$row .= ",".($mp->{'PCON24NM'} =~ /,/ ? "\"$mp->{'PCON24NM'}\"":$mp->{'PCON24NM'});
	$row .= ",".($mp->{'MP'} =~ /,/ ? "\"$mp->{'MP'}\"":$mp->{'MP'});
	$row .= ",".$mp->{'ID'};
	$row .= ",".$mp->{'StartDate'};
	$row .= ",".($mp->{'Party'} =~ /,/ ? "\"$mp->{'Party'}\"":$mp->{'Party'});
	$row .= ",".($mp->{'Party name'} =~ /,/ ? "\"$mp->{'Party name'}\"":$mp->{'Party name'});
	$row .= ",".$mp->{'Party bg'};
	$row .= ",".$mp->{'Party fg'};
	$row .= "\n";
	push(@rows,$row);
}
@rows = sort(@rows);
$file = $basedir."../../lookups/current-MPs.csv";
msg("Saving lookup to <cyan>$file<none>\n");
open($fh,">:utf8",$file);
print $fh "PCON24CD,PCON24NM,MP,MP ID,Start date,Party,Party name,BG,FG\n";
print $fh @rows;
close($fh);



############################

sub msg {
	my $str = $_[0];
	my $dest = $_[1]||"STDOUT";
	
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
	foreach my $c (keys(%colours)){ $str =~ s/\< ?$c ?\>/$colours{$c}/g; }
	if($dest eq "STDERR"){
		print STDERR $str;
	}else{
		print STDOUT $str;
	}
}

sub error {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<red>ERROR:<none> /;
	msg($str,"STDERR");
}

sub warning {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<yellow>WARNING:<none> /;
	msg($str,"STDERR");
}

# Version 1.1
sub CacheDownload {
	my $url = shift;
	my $file = shift;
	my $expireafter = shift||86400;
	my (@lines,$fh,$epoch_timestamp,$now,$age);

	$age = 100000;
	if(-e $file){
		$epoch_timestamp = (stat($file))[9];
		$now = time;
		$age = ($now-$epoch_timestamp);
	}

	if(!-e $file || -s $file == 0 || $age >= $expireafter){ SaveURL($url,$file); }
	open($fh,"<:utf8",$file);
	@lines = <$fh>;
	close($fh);
	return join("",@lines);
}

sub GetURL {
	my $url = shift;
	return `wget -q -e robots=off  --no-check-certificate -O- "$url"`;
}

sub SaveURL {
	my $url = shift;
	my $file = shift;
	return `wget -q -e robots=off  --no-check-certificate -O $file "$url"`;
}


sub ParseJSON {
	my $str = shift;
	my $json = {};
	if(!$str){ $str = "{}"; }
	eval {
		$json = JSON::XS->new->decode($str);
	};
	if($@){ error("\tInvalid output.\n"); }
	return $json;
}

sub LoadJSON {
	my (@files,$str,@lines,$json);
	my $file = $_[0];
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = (join("",@lines));
	# Error check for JS variable e.g. South Tyneside https://maps.southtyneside.gov.uk/warm_spaces/assets/data/wsst_council_spaces.geojson.js
	$str =~ s/[^\{]*var [^\{]+ = //g;
	return ParseJSON($str);
}

# Version 1.1
sub SaveJSON {
	my $json = shift;
	my $file = shift;
	my $depth = shift;
	my $oneline = shift;
	if(!defined($depth)){ $depth = 0; }
	my $d = $depth+1;
	my ($txt,$fh);
	

	$txt = JSON::XS->new->canonical(1)->pretty->space_before(0)->encode($json);
	$txt =~ s/   /\t/g;
	$txt =~ s/\n\t{$d,}//g;
	$txt =~ s/\n\t{$depth}\}(\,|\n)/\}$1/g;
	$txt =~ s/": /":/g;

	if($oneline){
		$txt =~ s/\n[\t\s]*//g;
	}

	msg("Save JSON to <cyan>$file<none>\n");
	open($fh,">:utf8",$file);
	print $fh $txt;
	close($fh);

	return $txt;
}