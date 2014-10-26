package YADA;
# ABSTRACT: "Yet Another Download Accelerator": alias for AnyEvent::Net::Curl::Queued


use strict;
use utf8;
use warnings qw(all);

use feature qw(switch);

use Moo;

extends 'AnyEvent::Net::Curl::Queued';

use YADA::Worker;

our $VERSION = '0.043'; # VERSION

# serious DWIMmery ahead!
around qw(append prepend) => sub {
    my $orig = shift;
    my $self = shift;

    if (1 < scalar @_) {
        my (%init, @url);
        for my $arg (@_) {
            for (ref $arg) {
                when ($_ eq '' or m{^URI::}x) {
                    push @url, $arg;
                } when ('ARRAY') {
                    push @url, @{$arg};
                } when ('CODE') {
                    unless (exists $init{on_finish}) {
                        $init{on_finish} = $arg;
                    } else {
                        @init{qw{on_init on_finish}} = ($init{on_finish}, $arg);
                    }
                } when ('HASH') {
                    $init{$_} = $arg->{$_}
                        for keys %{$arg};
                }
            }
        }

        for my $url (@url) {
            my %copy = %init;
            $copy{initial_url} = $url;
            $orig->($self => sub { YADA::Worker->new(\%copy) });
        }
    } else {
        $orig->($self => @_);
    }

    return $self;
};


1;

__END__

=pod

=encoding utf8

=head1 NAME

YADA - "Yet Another Download Accelerator": alias for AnyEvent::Net::Curl::Queued

=head1 VERSION

version 0.043

=head1 SYNOPSIS

    #!/usr/bin/env perl
    use common::sense;

    use YADA;

    YADA->new->append(
        [qw[
            http://www.cpan.org/modules/by-category/02_Language_Extensions/
            http://www.cpan.org/modules/by-category/02_Perl_Core_Modules/
            http://www.cpan.org/modules/by-category/03_Development_Support/
            ...
            http://www.cpan.org/modules/by-category/27_Pragma/
            http://www.cpan.org/modules/by-category/28_Perl6/
            http://www.cpan.org/modules/by-category/99_Not_In_Modulelist/
        ]] => sub {
            say $_[0]->final_url;
            say ${$_[0]->header};
        },
    )->wait;

=head1 WARNING: GONE MOO!

This module isn't using L<Any::Moose> anymore due to the announced deprecation status of that module.
The switch to the L<Moo> is known to break modules that do C<extend 'AnyEvent::Net::Curl::Queued::Easy'> / C<extend 'YADA::Worker'>!
To keep the compatibility, make sure that you are using L<MooseX::NonMoose>:

    package YourSubclassingModule;
    use Moose;
    use MooseX::NonMoose;
    extends 'AnyEvent::Net::Curl::Queued::Easy';
    ...

Or L<MouseX::NonMoose>:

    package YourSubclassingModule;
    use Mouse;
    use MouseX::NonMoose;
    extends 'AnyEvent::Net::Curl::Queued::Easy';
    ...

Or the L<Any::Moose> equivalent:

    package YourSubclassingModule;
    use Any::Moose;
    use Any::Moose qw(X::NonMoose);
    extends 'AnyEvent::Net::Curl::Queued::Easy';
    ...

However, the recommended approach is to switch your subclassing module to L<Moo> altogether (you can use L<MooX::late> to smoothen the transition):

    package YourSubclassingModule;
    use Moo;
    use MooX::late;
    extends 'AnyEvent::Net::Curl::Queued::Easy';
    ...

=head1 DESCRIPTION

Use L<AnyEvent::Net::Curl::Queued> with fewer keystrokes.
Also, the I<easy things should be easy> side of the package.
For the I<hard things should be possible> side, refer to the complete L<AnyEvent::Net::Curl::Queued> documentation.

=head1 USAGE

The example in L</SYNOPSIS> is equivalent to:

    #!/usr/bin/env perl
    use common::sense;

    use AnyEvent::Net::Curl::Queued;
    use AnyEvent::Net::Curl::Queued::Easy;

    my $q = AnyEvent::Net::Curl::Queued->new;
    $q->append(sub {
        AnyEvent::Net::Curl::Queued::Easy->new({
            initial_url => $_,
            on_finish   => sub {
                say $_[0]->final_url;
                say ${$_[0]->header};
            },
        })
    }) for qw(
        http://www.cpan.org/modules/by-category/02_Language_Extensions/
        http://www.cpan.org/modules/by-category/02_Perl_Core_Modules/
        http://www.cpan.org/modules/by-category/03_Development_Support/
        ...
        http://www.cpan.org/modules/by-category/27_Pragma/
        http://www.cpan.org/modules/by-category/28_Perl6/
        http://www.cpan.org/modules/by-category/99_Not_In_Modulelist/
    );
    $q->wait;

As you see, L<YADA> overloads C<append>/C<prepend> from L<AnyEvent::Net::Curl::Queued>, adding implicit constructor for the worker object.
It also makes both methods return a reference to the queue object, so (almost) everything gets chainable.
The implicit constructor is triggered only when C<append>/C<prepend> receives multiple arguments.
The order of arguments (mostly) doesn't matter.
Their meaning is induced by their reference type:

=over 4

=item *

String (non-reference) or L<URI>: assumed as L<AnyEvent::Net::Curl::Queued::Easy/initial_url> attribute. Passing several URLs will construct & enqueue several workers;

=item *

Array: process a batch of URLs;

=item *

Hash: attributes set for each L<AnyEvent::Net::Curl::Queued::Easy> instantiated. Passing several hashes will merge them, overwriting values for duplicate keys;

=item *

C<sub { ... }>: assumed as L<AnyEvent::Net::Curl::Queued::Easy/on_finish> attribute;

=item *

C<sub { ... }, sub { ... }>: the first block is assumed as L<AnyEvent::Net::Curl::Queued::Easy/on_init> attribute, while the second one is assumed as L<AnyEvent::Net::Curl::Queued::Easy/on_finish>.

=back

=head2 Beware!

L<YADA> tries to follow the I<principle of least astonishment>, at least when you play nicely.
All the following snippets have the same meaning:

    $q->append(
        { retry => 3 },
        'http://www.cpan.org',
        'http://metacpan.org',
        sub { $_[0]->setopt(verbose => 1) }, # on_init placeholder
        \&on_finish,
    );

    $q->append(
        [qw[
            http://www.cpan.org
            http://metacpan.org
        ]],
        { retry => 3, opts => { verbose => 1 } },
        \&on_finish,
    );

    $q->append(
        URI->new($_) => \&on_finish,
        { retry => 3, opts => { verbose => 1 } },
    ) for qw[
        http://www.cpan.org
        http://metacpan.org
    ];

    $q->append(
        [qw[
            http://www.cpan.org
            http://metacpan.org
        ]] => {
            retry       => 3,
            opts        => { verbose => 1 },
            on_finish   => \&on_finish,
        }
    );

However, B<you will be astonished> if you specify multiple distinct C<on_init> and C<on_finish> or try to sneak in C<initial_url> through attributes!
At least, RTFC if you seriously attempt to do that.

=head1 SEE ALSO

=over 4

=item *

L<AnyEvent::Net::Curl::Queued>

=item *

L<AnyEvent::Net::Curl::Queued::Easy>

=item *

L<YADA::Worker>

=back

=head1 AUTHOR

Stanislaw Pusep <stas@sysd.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Stanislaw Pusep.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
