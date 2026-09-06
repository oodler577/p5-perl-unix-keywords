use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use Perl::Unix::Keywords;

my $dir = tempdir(CLEANUP => 1);
my $out = File::Spec->catfile($dir, 'argv.txt');
my $helper = File::Spec->catfile($dir, 'write-argv.pl');

# Use a helper script rather than perl -e.  Complex -e strings are subject to
# platform-specific command-line quoting on MSWin32 and can make an argv test
# fail before xargs itself has been exercised.
open my $script, '>', $helper or die "open $helper: $!";
print {$script} <<'PERL';
use strict;
use warnings;
my $out = shift @ARGV;
open my $fh, '>', $out or die "open $out: $!";
print {$fh} join("\n", @ARGV);
close $fh or die "close $out: $!";
PERL
close $script or die "close $helper: $!";

my @items = ('plain', 'with space', q{semi;colon}, q{$dollar});
my $rc = xargs [ $^X, $helper, $out ] => @items;
is $rc, 0, 'arrayref command exits successfully';

open my $fh, '<', $out or die "open $out: $!";
my @got = <$fh>;
close $fh;
chomp @got;
is_deeply \@got, \@items, 'arguments arrive literally without shell interpolation';

$rc = xargs $^X => '-e', 'exit 0';
is $rc, 0, 'scalar executable command works';

$rc = xargs $^X => '-e', 'exit 7';
is $rc >> 8, 7, 'raw system status preserves child exit status';

my $marker = File::Spec->catfile($dir, 'should-not-exist');
my $touch_helper = File::Spec->catfile($dir, 'touch.pl');
open $script, '>', $touch_helper or die "open $touch_helper: $!";
print {$script} <<'PERL';
use strict;
use warnings;
my $file = shift @ARGV;
open my $fh, '>', $file or die "open $file: $!";
close $fh or die "close $file: $!";
PERL
close $script or die "close $touch_helper: $!";

$rc = xargs [ $^X, $touch_helper, $marker ] => ();
is $rc, 0, 'empty input is successful no-op';
ok !-e $marker, 'empty input does not invoke subprocess';

my $ok = eval { xargs [] => qw(a); 1 };
ok !$ok, 'empty command arrayref throws';
like $@, qr/must not be empty/, 'empty-array diagnostic';

$ok = eval { xargs {} => qw(a); 1 };
ok !$ok, 'unsupported command reference throws';
like $@, qr/scalar executable name or an array reference/, 'unsupported-reference diagnostic';

$ok = eval { xargs q{} => qw(a); 1 };
ok !$ok, 'empty scalar command throws';
like $@, qr/command must not be empty/, 'empty-scalar diagnostic';

done_testing;
