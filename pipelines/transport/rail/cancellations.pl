#!/usr/bin/perl

use lib "./../../lib/";	# Custom functions
use Data::Dumper;
use JSON::XS;
use Encode;
require "lib.pl";

my $filestations = "GB-stations-pcon-sorted.csv";
my $filecancellations = "table-3130-time-to-3-and-cancellations-by-station-and-operator.csv";
my $filecons = "../../../src/_data/hexjson/uk-constituencies-2024.hexjson";


my ($station,$stations,$cancellations,$hexes,$data,$pcon,$c,$lookup,$str);

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
	if(!defined($stations->{$station}) && defined($lookup->{$station})){
		$station = $lookup->{$station};
	}
	$pcon = $stations->{$station}{'PCON24CD'};
	if(!defined($pcon)){
		msg("No station found for <yellow>$station<none>\n");
		#print Dumper $stations->{$station};
		#print Dumper $cancellations->{$station};
	}
	if(!defined($data->{$pcon})){
		$data->{$pcon} = {'name'=>$stations->{$station}{'PCON24NM'}};
	}
	if(!defined($data->{$pcon}{'stations'})){
		$data->{$pcon}{'stations'} = {};
	}
	$data->{$pcon}{'Scheduled stops'} += $cancellations->{$station}{'Scheduled stops'};
	$data->{$pcon}{'Recorded station stops'} += $cancellations->{$station}{'Recorded station stops'};
	$c = int($cancellations->{$station}{'Scheduled stops'}*$cancellations->{$station}{'Cancellations (percentage) [note 4, 5]'}/100);
	$data->{$pcon}{'Cancellations'} += $c;
	$data->{$pcon}{'stations'}{$stations->{$station}{'Station name'}} = {'code'=>$stations->{$station}{'Station code'},'cancelled'=>$cancellations->{$station}{'Cancellations (percentage) [note 4, 5]'}};
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
			$str .= "<li>$station ($data->{$pcon}{'stations'}{$station}{'code'}) - <strong>".sprintf("%0.1f",$data->{$pcon}{'stations'}{$station}{'cancelled'})."%</strong></li>";
		}
		$csv .= ($str ? "<ul>":"").$str.($str ? "</ul>":"");
	}
	$csv .= "\n";
}

open(my $fh,">../../../src/_data/sources/transport/rail-cancellations.csv");
print $fh $csv;
close($fh);
#print Dumper $data->{'E14001325'};