use strict;
use warnings;
use Test::More;
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Perl::Unix::Keywords;

my $root = tempdir(CLEANUP => 1);
my $sub = File::Spec->catdir($root, 'sub');
make_path($sub);
my @files = (
    File::Spec->catfile($root, 'a.tmp'),
    File::Spec->catfile($root, 'b.txt'),
    File::Spec->catfile($sub, 'c.tmp'),
);
for my $file (@files) {
    open my $fh, '>', $file or die "open $file: $!";
    close $fh;
}

my @tmp = walk { -f $_ && /[.]tmp\z/ ? $_ : () } $root;
is_deeply \@tmp, [ $files[0], $files[2] ], 'walk produces composable list';

my @unique = uniq { /([.]\w+)\z/ ? $1 : $_ } first => @files;
is_deeply \@unique, [ $files[0], $files[1] ], 'uniq composes over arbitrary computed keys';

my %groups = group { /([.]\w+)\z/ ? $1 : q{} } @files;
is_deeply $groups{'.tmp'}, [ $files[0], $files[2] ], 'group consumes ordinary list output';

my $out = File::Spec->catfile($root, 'seen.txt');
my $helper = File::Spec->catfile($root, 'write-seen.pl');
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

my $rc = xargs [ $^X, $helper, $out ] => walk {
    -f $_ && /[.]tmp\z/ ? $_ : ();
} $root;
is $rc, 0, 'walk output can feed xargs directly';

open my $fh, '<', $out or die "open $out: $!";
my @seen = <$fh>;
close $fh;
chomp @seen;
is_deeply \@seen, [ $files[0], $files[2] ], 'xargs received walk output as argv';

done_testing;
