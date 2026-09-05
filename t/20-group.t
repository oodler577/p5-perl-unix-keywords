use strict;
use warnings;
use Test::More;
use Perl::Unix::Keywords;

my @items = qw(apple apricot banana blueberry cherry);
my %groups = group { substr $_, 0, 1 } @items;

is_deeply $groups{a}, [qw(apple apricot)], 'a group preserves input order';
is_deeply $groups{b}, [qw(banana blueberry)], 'b group preserves input order';
is_deeply $groups{c}, [qw(cherry)], 'c group present';

my $href = group { length $_ } qw(a bb c dd);
is ref($href), 'HASH', 'scalar context returns hash reference';
is_deeply $href->{1}, [qw(a c)], 'scalar-context hashref has expected group';
is_deeply $href->{2}, [qw(bb dd)], 'second scalar-context group';

my @seen;
group {
    push @seen, [ $_, $_[0] ];
    return length $_;
} qw(a bb);
ok !grep({ $_->[0] ne $_->[1] } @seen), 'block receives value in both $_ and first argument';

my %undef = group { undef } qw(a b);
is_deeply $undef{q{}}, [qw(a b)], 'undefined key normalizes to empty string';

my %empty = group { $_ } ();
is scalar(keys %empty), 0, 'empty input yields no groups';

my $ok = eval { group { die "boom\n" } qw(a); 1 };
ok !$ok, 'block exception propagates';
like $@, qr/^boom/, 'block exception retained';

done_testing;
