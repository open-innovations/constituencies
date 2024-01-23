#!/usr/bin/perl

use JSON::XS;

open($fh,">","../../src/_data/sources/society/foodbanks.csv");
print $fh "Blah"; 
close($fh);