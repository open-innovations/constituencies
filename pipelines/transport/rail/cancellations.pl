#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use lib "./../../lib/";	# Custom functions
use Data::Dumper;
use JSON::XS;
use Encode;
use Scalar::Util qw(looks_like_number);
use Cwd qw(abs_path);
# Get the real base directory for this script
my $basedir = "./";
if(abs_path($0) =~ /^(.*\/)[^\/]*/){ $basedir = $1; }
my $repodir = $basedir."../../../";
require $basedir."../../lib/lib.pl";

my $filestations = $basedir."GB-stations-pcon-sorted.csv";
my $filecancellations = $basedir."table-3130-time-to-3-and-cancellations-by-station-and-operator.csv";
my $filecons = $repodir."src/_data/hexjson/uk-constituencies-2024.hexjson";


my ($station,$renamedstation,$stations,$cancellations,$hexes,$data,$pcon,$c,$lookup,$str);

$stations = LoadCSV($filestations,{'key'=>'Station name'});
$cancellations = LoadCSV($filecancellations,{'key'=>'Station name'});
$hexes = LoadJSON($filecons);
$hexes = $hexes->{'hexes'};


$lookup = {
	'Bethnal Green' => 'Bethnal Green Rail',
	'Burnham (Buckinghamshire)' => 'Burnham',
	'Chafford Hundred Lakeside' => 'Chafford Hundred',
	'Dorking (Main)' => 'Dorking',
	'Epsom (Surrey)' => 'Epsom',
	'Hampton (London)' => 'Hampton',
	'Hayes (Kent)' => 'Hayes',
	'Heathrow Terminal 4 (Rail Station Only)' => 'Heathrow Terminal 4',
	'Heathrow Terminal 5 (Rail Station Only)' => 'Heathrow Terminal 5',
	'Kensington Olympia' => 'Kensington (Olympia)',
	'Langley (Berks)' => 'Langley',
	'Lee (London)' => 'Lee',
	'London Blackfriars' => 'Blackfriars',
	'London Cannon Street' => 'Cannon Street',
	'London Charing Cross' => 'Charing Cross',
	'London Euston' => 'Euston',
	'London Fenchurch Street' => 'Fenchurch Street',
	'London Kings Cross' => 'King\'s Cross',
	'London Liverpool Street' => 'Liverpool Street',
	'London Marylebone' => 'Marylebone',
	'London Paddington' => 'Paddington',
	'London St Pancras International' => 'St Pancras',
	'London Victoria' => 'Victoria',
	'London Waterloo' => 'Waterloo',
	'London Waterloo East' => 'Waterloo East',
	'Newark Northgate' => 'Newark North Gate',
	'Queens Road (Peckham)' => 'Queens Road Peckham',
	'Richmond (London)' => 'Richmond',
	'Seer Green and Jordans' => 'Seer Green',
	'St Helier (London)' => 'St Helier',
	'St James Street (Walthamstow)' => 'St James Street',
	'St Johns (London)' => 'St Johns',
	'St Margarets (London)' => 'St Margarets',
	'Stratford (London)' => 'Stratford',
	'Streatham (Greater London)' => 'Streatham',
	'Sutton (London)' => 'Sutton',
	'Sydenham (London)' => 'Sydenham',
	'Whitton (London)' => 'Whitton'
};

foreach $pcon (keys(%{$hexes})){
	if($pcon !~ /^N/){
		$data->{$pcon} = {'name'=>$hexes->{$pcon}{'n'}};
	}
}

foreach $station (sort(keys(%{$cancellations}))){
	$renamedstation = $station;
	if(!defined($stations->{$station}) && defined($lookup->{$station})){
		$renamedstation = $lookup->{$station};
	}
	$pcon = $stations->{$renamedstation}{'PCON24CD'};
	if(!defined($pcon)){
		msg("No station found for <yellow>$station<none>\n");
	}
	if(!defined($data->{$pcon})){
		$data->{$pcon} = {'name'=>$stations->{$renamedstation}{'PCON24NM'}};
	}
	if(!defined($data->{$pcon}{'stations'})){
		$data->{$pcon}{'stations'} = {};
	}
	if(looks_like_number($cancellations->{$station}{'Scheduled stops'})){
		$data->{$pcon}{'Scheduled stops'} += $cancellations->{$station}{'Scheduled stops'};
	}

	if(looks_like_number($cancellations->{$station}{'Recorded station stops'})){
		$data->{$pcon}{'Recorded station stops'} += $cancellations->{$station}{'Recorded station stops'};
	}
	if(looks_like_number($cancellations->{$station}{'Scheduled stops'}) && looks_like_number($cancellations->{$station}{'Cancellations (percentage) [note 4, 5]'})){
		$c = int($cancellations->{$station}{'Scheduled stops'}*$cancellations->{$station}{'Cancellations (percentage) [note 4, 5]'}/100);
	}else{
		$c = 0;
	}
	$data->{$pcon}{'Cancellations'} += $c;
	$data->{$pcon}{'stations'}{$stations->{$renamedstation}{'Station name'}} = {'code'=>$stations->{$renamedstation}{'Station code'},'cancelled'=>$cancellations->{$station}{'Cancellations (percentage) [note 4, 5]'}};
}


my $csv = "PCON24CD,PCON24NM,Scheduled stops,Recorded station stops,Cancellations,Cancellations %,Stations\n";
foreach $pcon (sort(keys(%{$data}))){
	$csv .= $pcon;
	$csv .= ",\"".($data->{$pcon}{'name'}||"?")."\"";
	$csv .= ",".($data->{$pcon}{'Scheduled stops'}||"");
	$csv .= ",".($data->{$pcon}{'Recorded station stops'}||"");
	$csv .= ",".($data->{$pcon}{'Cancellations'}||"");
	$csv .= ",";
	if(defined($data->{$pcon}{'Scheduled stops'}) && defined($data->{$pcon}{'Cancellations'}) && $data->{$pcon}{'Scheduled stops'} > 0){
		$csv .= sprintf("%0.1f",(100*$data->{$pcon}{'Cancellations'}/$data->{$pcon}{'Scheduled stops'}));
	}else{
		$csv .= "0";
	}
	$csv .= ",";
	if(defined($data->{$pcon}{'stations'})){
		$str = "";
		foreach $station (sort(keys(%{$data->{$pcon}{'stations'}}))){
			$str .= "<li>$station ($data->{$pcon}{'stations'}{$station}{'code'}) - <strong>";
			#print "$station = $data->{$pcon}{'stations'}{$station}{'cancelled'}\n";

			if(looks_like_number($data->{$pcon}{'stations'}{$station}{'cancelled'})){
				$str .= sprintf("%0.1f",$data->{$pcon}{'stations'}{$station}{'cancelled'})."%";
			}else{
				$str .= convertNote($data->{$pcon}{'stations'}{$station}{'cancelled'}||"");
			}
			$str .= "</strong></li>";
		}
		$csv .= ($str ? "<ul>":"").$str.($str ? "</ul>":"");
	}
	$csv .= "\n";
}

open(my $fh,">:utf8",$repodir."src/_data/sources/transport/rail-cancellations.csv");
print $fh $csv;
close($fh);
#print Dumper $data->{'E14001325'};


sub convertNote {
	my $v = shift;
	if($v eq "[u]"){
		return "low quality data";
	}elsif($v eq "[z]"){
		return "data not applicable";
	}else{
		return $v;
	}
}