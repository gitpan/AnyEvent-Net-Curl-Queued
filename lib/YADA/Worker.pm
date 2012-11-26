package YADA::Worker;
# ABSTRACT: "Yet Another Download Accelerator Worker": alias for AnyEvent::Net::Curl::Queued::Easy


use strict;
use utf8;
use warnings qw(all);

use Any::Moose;

extends 'AnyEvent::Net::Curl::Queued::Easy';

our $VERSION = '0.037'; # VERSION


no Any::Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf8

=head1 NAME

YADA::Worker - "Yet Another Download Accelerator Worker": alias for AnyEvent::Net::Curl::Queued::Easy

=head1 VERSION

version 0.037

=head1 DESCRIPTION

Exactly the same thing as L<AnyEvent::Net::Curl::Queued::Easy>, however, with a more Perl-ish and shorter name.

=head1 SEE ALSO

=over 4

=item *

L<AnyEvent::Net::Curl::Queued>

=item *

L<AnyEvent::Net::Curl::Queued::Easy>

=item *

L<YADA>

=back

=head1 AUTHOR

Stanislaw Pusep <stas@sysd.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Stanislaw Pusep.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
