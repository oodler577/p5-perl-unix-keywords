use strict;
use warnings;
use Test::More tests => 8;
use Perl::Unix::Keywords;

my @items = qw(Foo foo BAR bar bar);

my @unique = uniq { lc $_ } first => @items;
is_deeply \@unique, [qw(Foo BAR)], 'paper uniq first syntax and semantics';

my %counts = uniq { lc $_ } count => @items;
is_deeply \%counts, { foo => 2, bar => 3 }, 'paper uniq count syntax and semantics';

my %groups = group { substr $_, 0, 1 } qw(apple apricot banana);
is_deeply $groups{a}, [qw(apple apricot)], 'paper group syntax';
is_deeply $groups{b}, [qw(banana)], 'paper group semantics';

my @walked = walk { $_ } __FILE__;
is_deeply \@walked, [__FILE__], 'paper walk BLOCK LIST syntax';

my @none;
my $status = xargs command_that_is_not_run => @none;
is $status, 0, 'paper xargs COMMAND => LIST syntax';

my $compiled = eval q{
    if (0) {
        xargs rm => walk {
            -f $_ && /[.]tmp\z/ ? $_ : ();
        } '.';
    }
    1;
};
ok $compiled, 'paper walk-to-xargs composition parses';
is $@, q{}, 'paper composition parse has no exception';
