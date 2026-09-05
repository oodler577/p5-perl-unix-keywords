use strict;
use warnings;
use Test::More;
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Perl::Unix::Keywords;

my $root = tempdir(CLEANUP => 1);
my $sub  = File::Spec->catdir($root, 'sub');
make_path($sub);

my $a = File::Spec->catfile($root, 'a.txt');
my $b = File::Spec->catfile($sub,  'b.pm');
my $c = File::Spec->catfile($sub,  'c.txt');

for my $file ($a, $b, $c) {
    open my $fh, '>', $file or die "open $file: $!";
    print {$fh} "$file\n";
    close $fh or die "close $file: $!";
}

my @all = walk { $_ } $root;
my @expected = ($root, $a, $sub, $b, $c);
is_deeply \@all, \@expected, 'depth-first pre-order traversal is deterministic';

my @pm = walk { -f $_ && /[.]pm\z/ ? $_ : () } $root;
is_deeply \@pm, [$b], 'block can filter paths';

my @mapped = walk { -f $_ ? uc($_) : () } $root;
is_deeply \@mapped, [ map { uc $_ } ($a, $b, $c) ], 'block can transform emitted values';

my $count = walk { -f $_ ? $_ : () } $root;
is $count, 3, 'scalar context returns emitted value count';

my @args;
walk {
    push @args, [ $_, $_[0] ];
    return ();
} $root;
ok !grep({ $_->[0] ne $_->[1] } @args), 'block receives path in both $_ and first argument';

my $missing = File::Spec->catfile($root, 'missing');
my $ok = eval { walk { $_ } $missing; 1 };
ok !$ok, 'missing root throws';
like $@, qr/path does not exist/, 'missing-root diagnostic';

SKIP: {
    my $link = File::Spec->catfile($root, 'link-to-sub');
    my $made = eval { symlink $sub, $link };
    skip 'symlink creation unavailable', 2 if !$made;

    my @seen = walk { $_ } $root;
    ok grep({ $_ eq $link } @seen), 'symlink itself is visited';
    ok !grep({ $_ eq File::Spec->catfile($link, 'b.pm') } @seen), 'symlink directory is not followed';
}

done_testing;
