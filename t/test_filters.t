#!/usr/bin/perl -w
#
# Run lots of filter programs on lots of inputs and check the output
# is as expected.  We do not check the stderr messages, and we do not
# allow for filters that return an error code.  In fact, they're not
# filters at all: we assume that each can take an input filename and
# the --output option.
#
# -- Ed Avis, epa98@doc.ic.ac.uk, 2002-02-14
#

use strict;
use Getopt::Long;

my @cmds = ([ 'tv_cat' ],
	    [ 'tv_extractinfo_en' ],
	    [ 'tv_grep', 'a' ],
	    [ 'tv_grep', '--category', 'b' ],
	    [ 'tv_grep', '-i', '--last-chance', 'c' ],
	    [ 'tv_grep', '--new' ],
	    [ 'tv_grep', '--channel-name', 'd' ],
	    [ 'tv_grep', '--channel-id', 'channel4.com' ],
	    [ 'tv_grep', '--on-after', '2002-02-05' ],
	    [ 'tv_grep', '--eval', 'scalar keys %$_ > 5' ],
	    [ 'tv_grep', '--category', 'e', '--and', '--title', 'f' ],
	    [ 'tv_grep', '--category', 'g', '--or', '--title', 'h' ],
	    [ 'tv_grep', '-i', '--category', 'i', '--title', 'j' ],
	    [ 'tv_sort' ],
	    [ 'tv_to_latex' ]);

my $tests_dir = 't/data';           # directory test files live in
my $cmds_dir = '../../blib/script'; # directory filter programs live in,
                                    # relative to $tests_dir
my $verbose = 0;
GetOptions('tests-dir=s' => \$tests_dir, 'cmds-dir=s' => \$cmds_dir,
	   'verbose' => \$verbose);
chdir $tests_dir or die "cannot chdir to $tests_dir: $!";
my @tests = <*.xml>;
die "no test cases (*.xml) found in $tests_dir"
  if not @tests;
die "no directory $cmds_dir relative to $tests_dir"
  if not -d $cmds_dir;

# Any other environment needed (relative to $tests_dir)
$ENV{PERL5LIB} .= ":..";

my %seen;
my $num_tests = (scalar @cmds) * (scalar @tests);
print "1..$num_tests\n";
my $test_num = 0;
foreach my $cmd (@cmds) {
    foreach my $in (@tests) {
	++ $test_num;
	my $test_name = join('_', @$cmd, $in);
	$test_name =~ tr/A-Za-z0-9/_/sc;
	die "two tests munge to $test_name"
	  if $seen{$test_name}++;

	my $expected = "$test_name.expected";
	my $out = "$test_name.out";
	my $diff = "$test_name.diff";

	my @cmd = (@$cmd, $in, '--output', $out);
	$cmd[0] = "$cmds_dir/$cmd[0]";
	if ($verbose) {
	    print STDERR "test $test_num: @cmd\n";
	}
	if (system(@cmd)) {
	    my ($status, $sig, $core) = ($? >> 8, $? & 127, $? & 128);
	    if ($sig) {
		die "@cmd killed by signal $sig, aborting";
	    }
	    warn "@cmd failed: $status, $sig, $core\n";
	    print "not ok $test_num\n";
	}

	if (-e $expected) {
	    if (system("diff -u $expected $out >$diff")) {
		warn "failure for @cmd, see $diff\n";
		print "not ok $test_num\n";
	    }
	    else {
		print "ok $test_num\n";
		unlink $diff or warn "cannot unlink $diff: $!";
		unlink $out or warn "cannot unlink $out: $!";
	    }
	}
	else {
	    # This should happen after adding a new test case, never
	    # when just running the tests.
	    #
	    warn "creating $expected\n";
	    rename($out, $expected)
	      or die "cannot rename $out to $expected: $!";
	}
    }
}
die if $test_num != $num_tests;
