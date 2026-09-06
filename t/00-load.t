use strict;
use warnings;
use Test::More tests => 6;

BEGIN {
    use_ok('Perl::Unix::Keywords');
}

ok defined &walk,  'walk exported';
ok defined &group, 'group exported';
ok defined &uniq,  'uniq exported';
ok defined &xargs, 'xargs exported';
is $Perl::Unix::Keywords::VERSION, '0.03', 'version is expected';
