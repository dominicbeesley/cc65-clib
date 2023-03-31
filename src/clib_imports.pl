#!/usr/bin/perl

#build a set of imports and a jump table of symbols

use strict;

sub usage($) {
	my ($msg) = @_;

	print STDERR "$0 <rom import.s> [<input.s>...]\n\n";

	die $msg;
}

my $outfn_imports = shift or usage "no output filename";
open(my $fh_out_imports, ">", $outfn_imports) or usage "Cannot open $outfn_imports for output";

my $outfn_jumps = shift or usage "no output filename";
open(my $fh_out_jumps, ">", $outfn_jumps) or usage "Cannot open $outfn_jumps for output";

my $outfn_include_objs = shift or usage "no output filename";
open(my $fh_out_include_objs, ">", $outfn_include_objs) or usage "Cannot open $outfn_include_objs for output";

my $outfn_exclude_objs = shift or usage "no output filename";
open(my $fh_out_exclude_objs, ">", $outfn_exclude_objs) or usage "Cannot open $outfn_exclude_objs for output";


my %allowed_segment_names = map { $_ => $_ } ("CODE", "RODATA", "NULL", "ZEROPAGE");

my %file_imports=();
my %file_exports=();
my %excluded_files=();
my %allowed_files=();
my %zp_exports=();

while (my $infn = shift) {
	print "scanning $infn\n";

	open(my $fh_in, "<", $infn) or usage "Cannot open $infn for input";

	my @imports=();
	my @exports=();
	$allowed_files{$infn}=1;

	my $state="";
	my $seg_name="";
	my $is_zp = 0;

	while (<$fh_in>) {
		my $l = $_;
		$l =~ s/\s*\r*\s*$//;

		if ($l =~ /^\s\sSegments:/) {
			$state = "segments";	
		} elsif ($l =~ /^\s\sImports:/) {
			$state = "imports";
		} elsif ($l =~ /^\s\sExports:/) {
			$state = "exports";
		} elsif ($l =~ /^\s\sDebug/) {
			$state = "";
		} elsif ($state eq "segments") {
			if ($l =~ /^\s{6}Name:\s*\"([^\"]+)\"/) {
				$seg_name = $1;
			} elsif ($l =~ /^\s{6}Size:\s*([0-9]+)/) {
				if ($1 ne "0") {
					if (! exists($allowed_segment_names{$seg_name})) {
						$excluded_files{$infn} = 1;
						delete $allowed_files{$infn};
						print $fh_out_imports "; file $infn uses disallowed segment $seg_name\n";
					}
				}
			}

		} elsif ($state eq "imports") {
			if ($l =~ /Address size:/)
			{
				if ($l =~ /zeropage/) {
					$is_zp = 1;
				}
				else {
					$is_zp = 0;
				}
			}
			elsif ($l =~ /\s{6}Name:\s*\"([^\"]+)\"/)
			{
				if ($is_zp) {
			#		$zp_exports{$1} = 1;
				} else {
					push @imports, $1;
				}
			}
		} elsif ($state eq "exports") {
			if ($l =~ /Address size:/)
			{
				if ($l =~ /zeropage/) {
					$is_zp = 1;
				}
				else {
					$is_zp = 0;
				}
			}
			elsif ($l =~ /\s{6}Name:\s*\"([^\"]+)\"/)
			{
				if ($is_zp) {
					$zp_exports{$1} = 1;
				} else {
					push @exports, $1;
				}
			}
		}
	}

	$file_imports{$infn} = \@imports;
	$file_exports{$infn} = \@exports;

	close ($fh_in);
} 

#exclude files that import excluded symbols
my $again = 1;
while ($again) {

	$again = 0;

	my %excluded_syms = ();
	for my $fn (keys %excluded_files) {
		for my $s (@{$file_exports{$fn}})
		{
			if (exists $excluded_syms{$s}) {
				push @{$excluded_syms{$s}}, $fn;
			} else {
				@{$excluded_syms{$s}} = [ $fn ];
			}
		}
	}

	my %included_syms = ();
	for my $fn (keys %allowed_files) {
		for my $s (@{$file_exports{$fn}})
		{
			$included_syms{$s} = 1;
		}
	}


	for my $fn (keys %allowed_files) {
		for my $s (@{$file_imports{$fn}}) {

			if (!exists($included_syms{$s}) && !exists($zp_exports{$s}) ){
				$excluded_files{$fn} = 1;
				delete $allowed_files{$fn};
				$again = 1;
				print $fh_out_imports "; file $fn relies on symbol $s which is not in the library\n"; 
			} elsif (exists $excluded_syms{$s}) {
				$excluded_files{$fn} = 1;
				delete $allowed_files{$fn};
				$again = 1;
				print $fh_out_imports "; file $fn relies on symbol $s which is in excluded file(s) " 
					. join(", ", @{$excluded_syms{$s}}) . "\n";

			}

		}
	}

}


my %my_exports_runtime = ();
for my $fn (keys %allowed_files) {
	my $fn_o = $fn;
	$fn_o =~ s/\.info/\.o/gi;
	print $fh_out_include_objs "$fn_o ";
	for my $s (@{$file_exports{$fn}})
	{
		$my_exports_runtime{$s} = $fn;
	}
}

for my $fn (keys %excluded_files) {
	my $fn_o = $fn;
	$fn_o =~ s/\.info/\.o/gi;
	print $fh_out_exclude_objs "$fn_o ";
}

print $fh_out_imports "; generated by cli_mports.pl\n";

for my $sym (sort keys %my_exports_runtime) {
	if ($sym) {
		print $fh_out_imports "\n\t\t.import\t$sym\t;\t${my_exports_runtime{$sym}}\n";
		print $fh_out_imports "\n\t\tFORCE_$sym=$sym\n";
	}
}

print $fh_out_imports "; The following files and symbols were ignored due to using data\n";

for my $fn (sort keys %excluded_files) {
	print $fh_out_imports ";\t$fn\n";
	for my $sym (sort @{$file_exports{$fn}}) {
		print $fh_out_imports ";\t\t.export $sym\n";
	}
	for my $sym (sort @{$file_imports{$fn}}) {
		print $fh_out_imports ";\t\t.import $sym\t\t;$fn\n";
	}
}

print $fh_out_jumps "; generated by cli_mports.pl\n";


for my $sym (sort keys %my_exports_runtime) {
#	if ($sym) {
#		print $fh_out_jumps "\njmp_$sym:\t\tjmp\t$sym\n";
#	}
}

print $fh_out_imports "\n";
print $fh_out_jumps "\n";

close($fh_out_imports);
close($fh_out_jumps);
close($fh_out_include_objs);