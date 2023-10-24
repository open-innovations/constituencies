#!/usr/bin/perl

use Data::Dumper;

$file = $ARGV[0]||"TS058-2021-3-filtered-2023-10-10T18 09 15Z.csv";

if(!-e $file){
	print "Usage:\n";
	print "perl grouprows.pl <file> -groupby <column> -code <column> -value <column> -order <col1>,<col2>,<col3>\n";
	#perl grouprows.pl raw-data/school_funding.csv -groupby "Year" -value "\"Cons, Total Schools Block Allocation (Nominal)\",\"Cons, Total Schools Block Allocation (Real)\"" -code "ONSconstID" -order "ONSconstID,Region,Cons Total Number of Pupils,\"Cons, Allocation per Pupil (Nominal)\",\"Cons, Allocation per Pupil (Real)\""
	exit;
}

$rename = {};

for($i = 0; $i < @ARGV; $i++){
	if($ARGV[$i] eq "-groupby"){
		$groupby = $ARGV[$i+1];
		$i++;
	}
	if($ARGV[$i] eq "-code"){
		$colcode = $ARGV[$i+1];
		$i++;
	}
	if($ARGV[$i] eq "-value"){
		$valuestr = $ARGV[$i+1];
		@values = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$valuestr);
		for($c = 0; $c < @values; $c++){
			$values[$c] =~ s/(^\"|\"$)//g;
		}
		$i++;
	}
	if($ARGV[$i] eq "-order"){
		@order = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$ARGV[$i+1]);
		for($c = 0; $c < @order; $c++){
			$order[$c] =~ s/(^\"|\"$)//g;
		}
		$i++;
	}
	if($ARGV[$i] eq "-rename"){
		@bits = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$ARGV[$i+1]);
		for($c = 0; $c < @bits; $c++){
			($old,$new) = split(/=/,$bits[$c]);
			$old =~ s/(^\"|\"$)//g;
			$new =~ s/(^\"|\"$)//g;
			$rename->{$old} = $new;
		}
		$i++;
	}
	if($ARGV[$i] eq "-normalise"){
		@normalise = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$ARGV[$i+1]);
		for($c = 0; $c < @normalise; $c++){
			$order[$c] =~ s/(^\"|\"$)//g;
		}
		$i++;
	}
}

if(@values < 1){
	print "No value column(s) provided (comma separated):\n";
	print "  -value <value>\n";
	exit;
}
if(!$colcode){
	print "No constituency code column provided with:\n";
	print "  -code <value>\n";
	exit;
}

open(FILE,$file);
@lines = <FILE>;
close(FILE);

$constituencies = {};
$lookup = {};
for($r = 0; $r < @lines; $r++){
	$lines[$r] =~ s/[\n\r]//g;
	
	@cols = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$lines[$r]);
	for($c = 0; $c < @cols; $c++){
		$cols[$c] =~ s/(^\"|\"$)//g;
	}
	if($r == 0){
		@headers = @cols;
		for($c = 0; $c < @cols; $c++){
			if($rename->{$cols[$c]}){
				$headers[$c] = $rename->{$cols[$c]};
				$cols[$c] = $headers[$c];
			}
			$lookup->{$cols[$c]} = $c;
		}
	}else{
		$id = $cols[$lookup->{$colcode}];
		if(!$constituencies->{$id}){ $constituencies->{$id} = {}; }
		
		for($c = 0; $c < @cols; $c++){
			$grouped = 0;
			for($v = 0; $v < @values; $v++){
				if($c == $lookup->{$values[$v]}){ $grouped = 1; }
			}
			if($grouped){
				for($v = 0; $v < @values; $v++){
					$constituencies->{$id}{$values[$v]." / ".$cols[$lookup->{$groupby}]} = $cols[$lookup->{$values[$v]}];
				}
			}else{
				$constituencies->{$id}{$headers[$c]} = $cols[$c];
			}
		}
	}	
}

if(@normalise > 0){
	foreach $id (sort(keys(%{$constituencies}))){
		$total = 0;
		for($c = 0; $c < @normalise; $c++){
			$total += $constituencies->{$id}{$normalise[$c]};
		}
		for($c = 0; $c < @normalise; $c++){
			$constituencies->{$id}{$normalise[$c]." %"} = sprintf("%0.1f",$constituencies->{$id}{$normalise[$c]}*100/$total);
		}
	}
	for($c = @order-1; $c >= 0; $c--){
		if($constituencies->{'E14000530'}{$order[$c]." %"}){
			splice(@order,$c+1,0,$order[$c]." %");
		}
	}
}



if(@order <= 0){
	@order = (sort(keys(%{$constituencies->{'E14000530'}})));
}
$csv = "";
for($c = 0; $c < @order; $c++){
	$csv .= ($c==0 ? "":",").($order[$c] =~ /,/ ? "\"" : "").$order[$c].($order[$c] =~ /,/ ? "\"" : "");
}
$csv .= "\n";
foreach $id (sort(keys(%{$constituencies}))){
	$c = 0;
	foreach $key (@order){
		$csv .= ($c==0 ? "":",").($constituencies->{$id}{$key} =~ /,/ ? "\"" : "").$constituencies->{$id}{$key}.($constituencies->{$id}{$key} =~ /,/ ? "\"" : "");
		$c++;
	}
	$csv .= "\n";
}
print $csv;
