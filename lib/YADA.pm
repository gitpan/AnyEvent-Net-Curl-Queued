package YADA;
# ABSTRACT: "Yet Another Download Accelerator": alias for AnyEvent::Net::Curl::Queued


use strict;
use utf8;
use warnings qw(all);

use Any::Moose;

extends 'AnyEvent::Net::Curl::Queued';

use YADA::Worker;

our $VERSION = '0.023'; # VERSION


no Any::Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__
=pod

=encoding utf8

=head1 NAME

YADA - "Yet Another Download Accelerator": alias for AnyEvent::Net::Curl::Queued

=head1 VERSION

version 0.023

=head1 SYNOPSIS

    #!/usr/bin/env perl
    use strict;
    use utf8;
    use warnings qw(all);

    use YADA;

    my $q = YADA->new;
    $q->append(
        YADA::Worker->new({
            initial_url => $_,
            on_finish   => sub {
                say $_[0]->final_url;
                say ${$_[0]->header};
            },
        })
    ) for qw(
        http://www.cpan.org/modules/by-category/02_Language_Extensions/
        http://www.cpan.org/modules/by-category/02_Perl_Core_Modules/
        http://www.cpan.org/modules/by-category/03_Development_Support/
        ...
        http://www.cpan.org/modules/by-category/27_Pragma/
        http://www.cpan.org/modules/by-category/28_Perl6/
        http://www.cpan.org/modules/by-category/99_Not_In_Modulelist/
    );
    $q->wait;

=head1 DESCRIPTION

Use L<AnyEvent::Net::Curl::Queued> with fewer keystrokes.
Also, the I<easy things should be easy> side of the package.
For the I<hard things should be possible> side, refer to the complete L<AnyEvent::Net::Curl::Queued> documentation.

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

This software is copyright (c) 2012 by Stanislaw Pusep.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

