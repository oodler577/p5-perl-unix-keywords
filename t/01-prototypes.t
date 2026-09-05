use strict;
use warnings;
use Test::More tests => 8;
use Perl::Unix::Keywords;

is prototype(\&walk),  '&@',  'walk prototype';
is prototype(\&group), '&@',  'group prototype';
is prototype(\&uniq),  '&$@', 'uniq prototype';
is prototype(\&xargs), '$@',  'xargs prototype';

my @items = qw(a b a);
my @walked = walk { uc $_ } __FILE__;
is_deeply \@walked, [ uc(__FILE__) ], 'walk block syntax parses';

my %grouped = group { $_ eq 'a' ? 'A' : 'B' } @items;
is_deeply $grouped{A}, [qw(a a)], 'group block syntax parses';

my %counts = uniq { $_ } count => @items;
is_deeply \%counts, { a => 2, b => 1 }, 'uniq block-first mode syntax parses';

my $rc = xargs $^X => '-e', 'exit 0';
is $rc, 0, 'xargs scalar-command syntax parses';
