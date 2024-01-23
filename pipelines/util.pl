#!/usr/bin/perl

use utf8;
use JSON::XS;
use open qw(:std :encoding(UTF-8));
binmode(STDOUT, ":utf8");
binmode(STDIN, ":encoding(UTF-8)");

my $colours = {'black'=>"\033[0;30m",'red'=>"\033[0;31m",'green'=>"\033[0;32m",'yellow'=>"\033[0;33m",'blue'=>"\033[0;34m",'magenta'=>"\033[0;35m",'cyan'=>"\033[0;36m",'white'=>"\033[0;37m",'none'=>"\033[0m"};


sub loadJSON {
	my ($file,$fh,$debug,$conf,$str,$coder,@lines);
	$file = shift;
	$str = "{}";
	if(-e $file){
		open($fh,"<:utf8",$file);
		@lines = <$fh>;
		close($fh);
		$str = join("",@lines);
	}else{
		error("No config file: <green>$file<none>");
	}
	$coder = JSON::XS->new->allow_nonref;
	eval {
		$conf = $coder->decode($str);
	};
	if($@){ error("Failed to load JSON from <cyan>$file<none>:\n".substr($str,0,120)."...\n"); }

	return $conf;
}


sub msg {
	my $str = $_[0];
	my $dest = $_[1]||"STDOUT";
	foreach my $c (keys(%{$colours})){ $str =~ s/\< ?$c ?\>/$colours->{$c}/g; }
	if($dest eq "STDERR"){
		print STDERR $str;
	}else{
		print STDOUT $str;
	}
}

sub warning {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<yellow>WARNING:<none> /;
	msg($str,"STDERR");
}

sub error {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<red>ERROR:<none> /;
	msg($str,"STDERR");
}

1;