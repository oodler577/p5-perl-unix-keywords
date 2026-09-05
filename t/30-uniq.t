use strict;
use warnings;
use Test::More;
use Perl::Unix::Keywords;

my @items = qw(Foo foo BAR bar bar Baz);

my @first = uniq { lc $_ } first => @items;
is_deeply \@first, [qw(Foo BAR Baz)], 'first mode preserves first representatives and order';

my $n = uniq { lc $_ } first => @items;
is $n, 3, 'first mode scalar context returns unique count';

my %count = uniq { lc $_ } count => @items;
is_deeply \%count, { foo => 2, bar => 3, baz => 1 }, 'count mode counts canonical keys';

my @pairs = uniq { lc $_ } count => @items;
is_deeply \@pairs, [ foo => 2, bar => 3, baz => 1 ], 'count mode list order is first-seen key order';

my $href = uniq { lc $_ } count => @items;
is ref($href), 'HASH', 'count mode scalar context returns hash reference';
is_deeply $href, { foo => 2, bar => 3, baz => 1 }, 'count hashref values';

my @seen;
uniq {
    push @seen, [ $_, $_[0] ];
    return $_;
} first => qw(a b);
ok !grep({ $_->[0] ne $_->[1] } @seen), 'block receives value in both $_ and first argument';

my @undef = uniq { undef } first => qw(a b c);
is_deeply \@undef, ['a'], 'undefined keys canonicalize together';

my @empty = uniq { $_ } first => ();
is_deeply \@empty, [], 'empty first input';

my %empty_count = uniq { $_ } count => ();
is_deeply \%empty_count, {}, 'empty count input';

my $ok = eval { uniq { $_ } bogus => qw(a); 1 };
ok !$ok, 'invalid mode throws';
like $@, qr/mode must be 'first' or 'count'/, 'invalid-mode diagnostic';

$ok = eval { uniq { die "boom\n" } first => qw(a); 1 };
ok !$ok, 'block exception propagates';
like $@, qr/^boom/, 'uniq block exception retained';

done_testing;
