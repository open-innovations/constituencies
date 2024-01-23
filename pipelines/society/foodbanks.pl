#!/usr/bin/perl

use JSON::XS;

open($fh,">","../../src/_data/sources/society/foodbanks.csv");
print $fh "Field1,Field2\n";
print $fh "Value1,Value2\n";
close($fh);