use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use Perl::Unix::Keywords;

# Regression for CPAN Testers FAIL on Strawberry Perl 5.42.2 / MSWin32.
# The original tests passed a multiline program through `perl -e`; Windows
# command-line quoting could prevent that program from running, so the output
# file was never created.  This test exercises xargs argv preservation using a
# real helper script and therefore tests the library behavior directly.

my $dir = tempdir(CLEANUP => 1);
my $helper = File::Spec->catfile($dir, 'argv helper.pl');
my $out = File::Spec->catfile($dir, 'argv output.txt');

open my $fh, '>', $helper or die "open $helper: $!";
print {$fh} <<'PERL';
use strict;
use warnings;
my $out = shift @ARGV;
open my $fh, '>', $out or die "open $out: $!";
for my $arg (@ARGV) {
    print {$fh} length($arg), ':', $arg, "\n";
}
close $fh or die "close $out: $!";
PERL
close $fh or die "close $helper: $!";

my @args = (
    'plain',
    'with space',
    q{semi;colon},
    q{$dollar},
    q{double"quote},
    q{single'quote},
    'backslash\\value',
    q{backslash\\"quote},
    q{space and \"quote},
);

my $status = xargs [ $^X, $helper, $out ] => @args;
is $status, 0, 'xargs helper invocation succeeds';
ok -e $out, 'helper created output file';

open $fh, '<', $out or die "open $out: $!";
my @got;
while (my $line = <$fh>) {
    chomp $line;
    my ($length, $value) = split /:/, $line, 2;
    is length($value), $length, 'argument length survived process boundary';
    push @got, $value;
}
close $fh;

is_deeply \@got, \@args,
    'xargs preserves spaces and shell metacharacters as literal argv values';

done_testing;
