package AnyEvent::Net::Curl::Const;
# ABSTRACT: Access Net::Curl::* constants by name


use strict;
use utf8;
use warnings qw(all);

use Carp qw(carp);
use Memoize;
use Net::Curl::Easy;
use Scalar::Util qw(looks_like_number);

our $VERSION = '0.023'; # VERSION

memoize($_) for qw(info opt);


sub info {
    return _curl_const(CURLINFO => shift);
}

sub opt {
    return _curl_const(CURLOPT => shift);
}

sub _curl_const {
    my ($suffix => $key) = @_;

    return $key if looks_like_number($key);

    $key =~ s{^Net::Curl::Easy::}{}i;
    $key =~ y{-}{_};
    $key =~ s{\W}{}g;
    $key = uc $key;
    $key = "${suffix}_${key}" if $key !~ m{^${suffix}_};

    my $val;
    eval {
        no strict 'refs';   ## no critic
        my $const_name = 'Net::Curl::Easy::' . $key;
        $val = *$const_name->();
    };
    carp "Invalid libcurl constant: $key" if $@;

    return $val;
}


1;

__END__
=pod

=encoding utf8

=head1 NAME

AnyEvent::Net::Curl::Const - Access Net::Curl::* constants by name

=head1 VERSION

version 0.023

=head1 SYNOPSIS

    $easy->setopt(AnyEvent::Net::Curl::Const::opt('verbose'), 1);
    ...;
    $easy->getinfo(AnyEvent::Net::Curl::Const::info('size_download'));

=head1 DESCRIPTION

Perl-friendly access to the L<libcurl|http://curl.haxx.se/libcurl/> constants.
For example, you can access C<CURLOPT_TCP_NODELAY> value by supplying any of:

=over 4

=item *

C<'Net::Curl::Easy::CURLOPT_TCP_NODELAY'>

=item *

C<'CURLOPT_TCP_NODELAY'>

=item *

C<'TCP_NODELAY'>

=item *

C<'TCP-NoDelay'>

=item *

C<'tcp_nodelay'>

=back

=head1 FUNCTIONS

=head2 info($constant_name)

Retrieve numeric value for C<$constant_name> in C<CURLINFO> namespace.

=head2 opt($constant_name)

Retrieve numeric value for C<$constant_name> in I<CURLOPT> namespace.

=for test_synopsis my ($easy);

=head1 SEE ALSO

=over 4

=item *

L<libcurl - curl_easy_getinfo()|http://curl.haxx.se/libcurl/c/curl_easy_getinfo.html>

=item *

L<libcurl - curl_easy_setopt()|http://curl.haxx.se/libcurl/c/curl_easy_setopt.html>

=item *

L<Net::Curl::Easy>

=back

=head1 AUTHOR

Stanislaw Pusep <stas@sysd.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Stanislaw Pusep.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

