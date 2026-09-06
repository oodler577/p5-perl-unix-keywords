package Perl::Unix::Keywords;

use 5.010;
use strict;
use warnings;

use Carp qw(croak);
use Exporter qw(import);
use File::Spec ();

our $VERSION = '0.03';

our @EXPORT    = qw(walk group uniq xargs);
our @EXPORT_OK = @EXPORT;

sub walk (&@) {
    my $code = shift;
    my @roots = @_;
    my @out;

    for my $root (@roots) {
        _walk_one($code, $root, \@out);
    }

    return wantarray ? @out : scalar @out;
}

sub _walk_one {
    my ($code, $path, $out) = @_;

    croak qq{walk: path does not exist: $path}
        if !-e $path && !-l $path;

    my $value = $path;
    {
        local $_ = $value;
        push @$out, $code->($value);
    }

    return if !-d $path || -l $path;

    opendir my $dh, $path
        or croak qq{walk: cannot open directory '$path': $!};

    my @entries = sort grep { $_ ne q{.} && $_ ne q{..} } readdir $dh;
    closedir $dh
        or croak qq{walk: cannot close directory '$path': $!};

    for my $entry (@entries) {
        my $child = File::Spec->catfile($path, $entry);
        _walk_one($code, $child, $out);
    }

    return;
}

sub group (&@) {
    my $code = shift;
    my @items = @_;
    my %groups;

    for my $item (@items) {
        my $value = $item;
        my $key;
        {
            local $_ = $value;
            $key = $code->($value);
        }
        $key = q{} if !defined $key;
        push @{ $groups{$key} }, $item;
    }

    return wantarray ? %groups : \%groups;
}

sub uniq (&$@) {
    my $code = shift;
    my $mode = shift;
    my @items = @_;

    croak q{uniq: mode must be 'first' or 'count'}
        if !defined $mode || ($mode ne q{first} && $mode ne q{count});

    my %seen;
    my @order;
    my @first;
    my %count;

    for my $item (@items) {
        my $value = $item;
        my $key;
        {
            local $_ = $value;
            $key = $code->($value);
        }
        $key = q{} if !defined $key;

        if ($mode eq q{first}) {
            next if $seen{$key}++;
            push @first, $item;
        }
        else {
            push @order, $key if !$count{$key};
            $count{$key}++;
        }
    }

    if ($mode eq q{first}) {
        return wantarray ? @first : scalar @first;
    }

    if (wantarray) {
        my @pairs;
        for my $key (@order) {
            push @pairs, $key, $count{$key};
        }
        return @pairs;
    }

    return \%count;
}

sub xargs ($@) {
    my $command = shift;
    my @items = @_;

    my @prefix;
    if (!ref $command) {
        croak q{xargs: command must not be empty}
            if !defined $command || $command eq q{};
        @prefix = ($command);
    }
    elsif (ref $command eq q{ARRAY}) {
        croak q{xargs: command array reference must not be empty}
            if !@$command;
        @prefix = @$command;
    }
    else {
        croak q{xargs: command must be a scalar executable name or an array reference};
    }

    # Deliberately do not invoke the command for an empty input list. This
    # makes list composition safe and predictable.
    return 0 if !@items;

    my @argv = (@prefix, @items);

    # Native Win32 does not pass an argv array to CreateProcess(). Perl must
    # serialize LIST-form system() arguments into a command line and then
    # decide whether cmd.exe is required. Those quoting rules are subtle, in
    # particular when spaces, quotes, and backslashes occur together.
    # Win32::ShellQuote deliberately mirrors Perl's Win32 dispatch behavior
    # and quotes the complete argument vector as one operation. Do not
    # pre-escape individual arguments here; that introduces a second quoting
    # layer and corrupts combinations such as: space and \"quote.
    if ($^O eq q{MSWin32}) {
        require Win32::ShellQuote;
        my @quoted = Win32::ShellQuote::quote_system(@argv);
        return system @quoted;
    }

    return system { $argv[0] } @argv;
}

1;

__END__

=pod

=head1 NAME

Perl::Unix::Keywords - Prototype-based Unix-shaped verbs for Perl lists, trees, and subprocesses

=head1 VERSION

Version 0.03

=head1 SYNOPSIS

  use strict;
  use warnings;
  use Perl::Unix::Keywords;

  my @pm = walk {
      -f $_ && /[.]pm\z/ ? $_ : ();
  } 'lib';

  my %by_initial = group {
      substr $_, 0, 1;
  } qw(apple apricot banana blueberry);

  my @unique = uniq {
      lc $_;
  } first => qw(Foo foo BAR bar);

  my %counts = uniq {
      lc $_;
  } count => qw(Foo foo BAR bar bar);

  my $status = xargs [ $^X, '-e', 'print join qq{,}, @ARGV' ]
      => qw(one two three);

=head1 DESCRIPTION

C<Perl::Unix::Keywords> provides four small exported functions whose prototypes
allow them to be written in a keyword-like style on Perl 5.10 and later:
C<walk>, C<group>, C<uniq>, and C<xargs>.

The functions are ordinary Perl subroutines. They do not install parser hooks,
source filters, or new grammar. Their goal is to name four recurring operations
that otherwise tend to be reconstructed from loops, hashes, callbacks, and
C<system> calls.

The design intentionally favors Perl's long-standing prototype mechanism over
parameter signatures. No signature feature is required.

=head1 EXPORTS

The following names are exported by default and are also available through
C<@EXPORT_OK>:

  walk group uniq xargs

=head1 PROTOTYPES

The public prototypes are:

  walk  (&@)
  group (&@)
  uniq  (&$@)
  xargs ($@)

The block-first forms are significant. In ordinary Perl, a C<&> prototype can
turn a literal block in that position into a code reference without requiring
C<sub { ... }> syntax.

=head1 FUNCTIONS

=head2 walk BLOCK LIST

  my @files = walk {
      -f $_ ? $_ : ();
  } @roots;

C<walk> performs a deterministic, depth-first, pre-order traversal of each path
in C<LIST>. Directory entries are visited in lexical order. Each visited path
is placed in C<$_> and is also passed as the first argument to C<BLOCK>.

The block has map-like output semantics: it may return zero, one, or several
values for each visited path, and those values are flattened into the result.
This makes filtering and transformation possible in one traversal:

  my @perl_files = walk {
      -f $_ && /[.]p[lm]\z/ ? lc($_) : ();
  } 'lib', 'script';

In list context, C<walk> returns all emitted values. In scalar context, it
returns the number of emitted values.

Symbolic links are visited as entries but are never followed as directories.
This avoids accidental traversal cycles. A missing root or an unreadable
directory causes C<walk> to throw an exception with C<croak>.

=head2 group BLOCK LIST

  my %groups = group {
      substr $_, 0, 1;
  } @items;

C<group> computes one grouping key for each item. The item is placed in C<$_>
and is also passed as the first argument to C<BLOCK>. Values are retained in
input order within each group.

In list context, C<group> returns key/array-reference pairs suitable for direct
assignment to a hash:

  my %groups = group { length $_ } qw(a bb ccc dd);

  # $groups{1} is [ 'a' ]
  # $groups{2} is [ 'bb', 'dd' ]
  # $groups{3} is [ 'ccc' ]

In scalar context, C<group> returns a hash reference.

An undefined key is normalized to the empty string, matching Perl hash-key
stringification in a predictable way.

=head2 uniq BLOCK MODE => LIST

  my @unique = uniq { lc $_ } first => @items;
  my %counts = uniq { lc $_ } count => @items;

C<uniq> computes a canonical key for each item and supports two deliberately
small modes.

=over 4

=item * C<first>

Return the first input item observed for each distinct canonical key, preserving
first-seen order.

  my @unique = uniq { lc $_ } first => qw(Foo foo BAR bar);
  # ('Foo', 'BAR')

In scalar context, C<first> returns the number of unique representatives.

=item * C<count>

Count occurrences of each canonical key.

  my %counts = uniq { lc $_ } count => qw(Foo foo BAR bar bar);
  # (foo => 2, bar => 3)

In list context, C<count> returns key/count pairs in first-seen key order. In
scalar context, it returns a hash reference.

=back

Any mode other than C<first> or C<count> causes an exception.

=head2 xargs COMMAND => LIST

  my $status = xargs rm => @files;

  my $status = xargs [ 'rm', '-f' ] => @files;

C<xargs> lifts an in-memory Perl list into the argument vector of one external
command. C<COMMAND> may be a scalar executable name or an array reference
containing an executable plus fixed leading arguments.

The command is executed with Perl's list-form C<system>, so C<xargs> does not
construct a shell command line and does not perform shell interpolation.

C<xargs> returns the raw value returned by C<system>. Callers may decode it in
the usual Perl fashion:

  my $status = xargs command => @args;

  if ($status == -1) {
      die "failed to execute: $!";
  }
  elsif ($status & 127) {
      die sprintf "terminated by signal %d", ($status & 127);
  }
  else {
      my $exit = $status >> 8;
  }

If C<LIST> is empty, C<xargs> performs no subprocess invocation and returns
zero. The initial implementation intentionally performs a single argv-based
invocation rather than reproducing every batching, delimiter, and stdin feature
of the Unix C<xargs> utility.

=head1 COMPOSITION

The functions are intended to compose as ordinary Perl list operators. For
example, a tree can be traversed and the resulting files passed directly to a
subprocess:

  xargs rm => walk {
      -f $_ && /[.]tmp\z/ ? $_ : ();
  } '.';

Or values can be canonicalized before grouping:

  my @unique = uniq { lc $_ } first => @names;
  my %groups = group { substr lc($_), 0, 1 } @unique;

=head1 COMPATIBILITY

The distribution requires Perl 5.10 or later. The implementation uses no
parameter signatures and has no non-core runtime dependencies.

=head1 DESIGN NOTES

These functions intentionally provide a small semantic core rather than clone
every option of their Unix namesakes.

=over 4

=item * C<walk> is a composable tree traversal, not a complete replacement for
C<File::Find>.

=item * C<group> groups values; it does not embed a general reducer language.

=item * C<uniq> offers canonical first-representative selection and counting.

=item * C<xargs> performs safe argv lifting for one command invocation; it does
not read stdin or implement the Unix utility's batching policy.

=back

The narrow scope is deliberate. The four operations remain orthogonal and can
be combined with existing Perl constructs rather than growing into independent
mini-frameworks.

=head1 DIAGNOSTICS

C<walk> throws an exception when a requested path does not exist or a directory
cannot be opened or closed.

C<uniq> throws an exception for an unknown mode.

C<xargs> throws an exception if its command specification is empty or is a
reference type other than an array reference. Execution failure itself is
reported through C<system>'s normal return value and C<$!>.

=head1 AUTHOR

Brett Estrade (OODLER)

=head1 LICENSE AND COPYRIGHT

Copyright 2026 Brett Estrade.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
