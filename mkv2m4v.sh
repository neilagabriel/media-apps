#!/bin/sh
perl -e 'foreach my $mkv (@ARGV) {(my $m4v = $mkv) =~ tr/mkv/m4v/; `SublerCLI -source $mkv -dest $m4v`; }' $@

