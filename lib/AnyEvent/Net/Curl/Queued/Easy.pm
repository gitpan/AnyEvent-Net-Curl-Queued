package AnyEvent::Net::Curl::Queued::Easy;
# ABSTRACT: Net::Curl::Easy wrapped by Moose


use common::sense;

use Carp qw(carp confess);
use Digest::SHA;
use HTTP::Response;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::NonMoose;
use URI;

extends 'Net::Curl::Easy';

use AnyEvent::Net::Curl::Const;
use AnyEvent::Net::Curl::Queued::Stats;

our $VERSION = '0.007'; # VERSION

subtype 'AnyEvent::Net::Curl::Queued::Easy::URI'
    => as class_type('URI');

coerce 'AnyEvent::Net::Curl::Queued::Easy::URI'
    => from 'Object'
        => via {
            $_->isa('URI')
                ? $_
                : Params::Coerce::coerce('URI', $_);
        }
    => from 'Str'
        => via { URI->new($_) };


has curl_result => (is => 'rw', isa => 'Net::Curl::Easy::Code');


has data        => (is => 'rw', isa => 'Ref');


has header      => (is => 'rw', isa => 'Ref');


has http_response => (is => 'ro', isa => 'Bool', default => 0);


has initial_url => (is => 'ro', isa => 'AnyEvent::Net::Curl::Queued::Easy::URI', coerce => 1, required => 1);


has final_url   => (is => 'rw', isa => 'AnyEvent::Net::Curl::Queued::Easy::URI', coerce => 1);


has queue       => (is => 'rw', isa => 'Ref', weak_ref => 1);


has sha         => (is => 'ro', isa => 'Digest::SHA', default => sub { new Digest::SHA(256) }, lazy => 1);


has res         => (is => 'rw', isa => 'HTTP::Response');


has retry       => (is => 'rw', isa => 'Int', default => 5);


has stats       => (is => 'ro', isa => 'AnyEvent::Net::Curl::Queued::Stats', default => sub { AnyEvent::Net::Curl::Queued::Stats->new }, lazy => 1);
has use_stats   => (is => 'ro', isa => 'Bool', default => 0);


has [qw(on_init on_finish)] => (is => 'ro', isa => 'CodeRef');


sub unique {
    my ($self) = @_;

    # make URL-friendly Base64
    my $digest = $self->sha->clone->b64digest;
    $digest =~ tr{+/}{-_};

    # return the signature
    return $digest;
}


sub sign {
    my ($self, $str) = @_;

    # add entropy to the signature
    $self->sha->add($str);
}


sub init {
    my ($self) = @_;

    # fragment mangling
    my $url = $self->initial_url->clone;
    $url->fragment(undef);
    $self->setopt(Net::Curl::Easy::CURLOPT_URL,         $url->as_string);

    # salt
    $self->sign(($self->meta->class_precedence_list)[0]);
    # URL; GET parameters included
    $self->sign($url->as_string);

    # common parameters
    if ($self->queue) {
        $self->setopt(Net::Curl::Easy::CURLOPT_SHARE,   $self->queue->share);
        $self->setopt(Net::Curl::Easy::CURLOPT_TIMEOUT, $self->queue->timeout);
    }

    # buffers
    my $data;
    $self->setopt(Net::Curl::Easy::CURLOPT_WRITEDATA,   \$data);
    $self->data(\$data);

    my $header;
    $self->setopt(Net::Curl::Easy::CURLOPT_WRITEHEADER, \$header);
    $self->header(\$header);

    # call the optional callback
    $self->on_init->(@_) if ref($self->on_init) eq 'CODE';
}


sub has_error {
    my ($self) = @_;

    # very bad error
    return ($self->curl_result == Net::Curl::Easy::CURLE_OK) ? 0 : 1;
}


sub _finish {
    my ($self, $result) = @_;

    # populate results
    $self->curl_result($result);
    $self->final_url($self->getinfo(Net::Curl::Easy::CURLINFO_EFFECTIVE_URL));

    # optionally encapsulate with HTTP::Response
    if ($self->http_response) {
        $self->res(
            HTTP::Response->parse(
                (${$self->header} // "\n")
                . (${$self->data} // '')
            )
        );

        if (my $msg = $self->res->message) {
            $msg =~ s/^\s+//s;
            $msg =~ s/\s+$//s;
            $self->res->message($msg);
        }
    }

    # wrap around the extendible interface
    $self->finish($result);

    # re-enqueue the request
    if ($self->has_error and $self->retry > 1) {
        $self->queue->unique->{$self->unique} = 0;
        $self->queue->queue_push($self->clone);
    }

    # update stats
    if ($self->use_stats) {
        $self->stats->sum($self);
        $self->queue->stats->sum($self);
    }

    # request completed (even if returned error!)
    $self->queue->inc_completed;

    # move queue
    $self->queue->start;
}

sub finish {
    my ($self, $result) = @_;

    # call the optional callback
    $self->on_finish->($self, $result) if ref($self->on_finish) eq 'CODE';
}


sub clone {
    my ($self, $param) = @_;

    $param //= {};

    my $class = ($self->meta->class_precedence_list)[0];
    $param->{initial_url}   = $self->initial_url;
    $param->{retry}         = $self->retry - 1;

    return sub { $class->new($param) };
}


around setopt => sub {
    my $orig = shift;
    my $self = shift;

    if (@_) {
        my %param;
        if (scalar @_ % 2 == 0) {
            %param = @_;
        } elsif (ref($_[0]) eq 'HASH') {
            my $param = shift;
            %param = %{$param};
        } else {
            carp "setopt() expects OPTION/VALUE pair, OPTION/VALUE hash or hashref!";
        }

        while (my ($key, $val) = each %param) {
            $key = AnyEvent::Net::Curl::Const::opt($key);
            $self->$orig($key, $val) if defined $key;
        }
    } else {
        carp "Specify at least one OPTION/VALUE pair!";
    }
};


around getinfo => sub {
    my $orig = shift;
    my $self = shift;

    given (ref($_[0])) {
        when ('ARRAY') {
            my @val;
            for my $name (@{$_[0]}) {
                my $const = AnyEvent::Net::Curl::Const::info($name);
                next unless defined $const;
                push @val, $self->$orig($const);
            }
            return @val;
        } when ('HASH') {
            my %val;
            for my $name (keys %{$_[0]}) {
                my $const = AnyEvent::Net::Curl::Const::info($name);
                next unless defined $const;
                $val{$name} = $self->$orig($const);
            }

            # write back to HashRef if called under void context
            unless (defined wantarray) {
                while (my ($k, $v) = each %val) {
                    $_[0]->{$k} = $v;
                }
                return;
            } else {
                return \%val;
            }
        } when ('') {
            my $const = AnyEvent::Net::Curl::Const::info($_[0]);
            return defined $const ? $self->$orig($const) : $const;
        } default {
            carp "getinfo() expects array/hash reference or string!";
            return;
        }
    }
};


no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__
=pod

=encoding utf8

=head1 NAME

AnyEvent::Net::Curl::Queued::Easy - Net::Curl::Easy wrapped by Moose

=head1 VERSION

version 0.007

=head1 SYNOPSIS

    package MyIEDownloader;
    use common::sense;

    use Moose;
    use Net::Curl::Easy qw(/^CURLOPT_/);

    extends 'AnyEvent::Net::Curl::Queued::Easy';

    after init => sub {
        my ($self) = @_;

        $self->setopt(CURLOPT_ENCODING,         '');
        $self->setopt(CURLOPT_FOLLOWLOCATION,   1);
        $self->setopt(CURLOPT_USERAGENT,        'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)');
        $self->setopt(CURLOPT_VERBOSE,          1);
    };

    after finish => sub {
        my ($self, $result) = @_;

        if ($self->has_error) {
            printf "error downloading %s: %s\n", $self->final_url, $result;
        } else {
            printf "finished downloading %s: %d bytes\n", $self->final_url, length ${$self->data};
        }
    };

    around has_error => sub {
        my $orig = shift;
        my $self = shift;

        return 1 if $self->$orig(@_);
        return 1 if $self->getinfo(Net::Curl::Easy::CURLINFO_RESPONSE_CODE) =~ m{^5[0-9]{2}$};
    };

    no Moose;
    __PACKAGE__->meta->make_immutable;

    1;

=head1 DESCRIPTION

The class you should overload to fetch stuff your own way.

=head1 ATTRIBUTES

=head2 curl_result

libcurl return code (C<Net::Curl::Easy::Code>).

=head2 data

Receive buffer.

=head2 header

Header buffer.

=head2 http_response

Optionally encapsulate the response in L<HTTP::Response>.

=head2 initial_url

URL to fetch (string).

=head2 final_url

Final URL (after redirections).

=head2 queue

L<AnyEvent::Net::Curl::Queued> circular reference.

=head2 sha

Uniqueness detection helper.

=head2 res

Encapsulated L<HTTP::Response> instance, if L</http_response> was set.

=head2 retry

Number of retries (default: 5).

=head2 stats

L<AnyEvent::Net::Curl::Queued::Stats> instance.

=head2 use_stats

Set to true to enable stats computation.
Note that extracting C<libcurl> time/size data degrades performance slightly.

=head2 on_init

Callback you can define instead of extending the C<init> method.
Almost the same as C<after init =E<gt> sub { ... }>

=head2 on_finish

Callback you can define instead of extending the C<finish> method.
Almost the same as C<after finish =E<gt> sub { ... }>

=head1 METHODS

=head2 unique()

Returns the unique signature of the request.
By default, the signature is derived from L<Digest::SHA> of the C<initial_url>.

=head2 sign($str)

Use C<$str> to compute the C<unique> value.
Useful to successfully enqueue POST parameters.

=head2 init()

Initialize the instance.
We can't use the default C<BUILD> method as we need the initialization to be done B<after> the instance is in the queue.

You are supposed to build your own stuff after/around/before this method using L<method modifiers|Moose::Manual::MethodModifiers>.

=head2 has_error()

Error handling: if C<has_error> returns true, the request is re-enqueued (until the retries number is exhausted).

You are supposed to build your own stuff after/around/before this method using L<method modifiers|Moose::Manual::MethodModifiers>.

=head2 finish($result)

Called when the download is finished.
C<$result> holds the C<Net::Curl::Easy::Code>.

You are supposed to build your own stuff after/around/before this method using L<method modifiers|Moose::Manual::MethodModifiers>.

=head2 clone()

Clones the instance, for re-enqueuing purposes.

You are supposed to build your own stuff after/around/before this method using L<method modifiers|Moose::Manual::MethodModifiers>.

=head2 setopt(OPTION => VALUE [, OPTION => VALUE])

Extends L<Net::Curl::Easy> C<setopt()>, allowing option lists:

    $self->setopt(
        CURLOPT_ENCODING,         '',
        CURLOPT_FOLLOWLOCATION,   1,
        CURLOPT_USERAGENT,        'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)',
        CURLOPT_VERBOSE,          1,
    );

Or even shorter:

    $self->setopt(
        encoding            => '',
        followlocation      => 1,
        useragent           => 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)',
        verbose             => 1,
    );

Complete list of options: L<http://curl.haxx.se/libcurl/c/curl_easy_setopt.html>

=head2 getinfo(VAR_NAME [, VAR_NAME])

Extends L<Net::Curl::Easy> C<getinfo()> so it is able to get several variables at once;
C<HashRef> parameter under void context will fill respective values in the C<HashRef>:

    my $x = {
        content_type    => 0,
        speed_download  => 0,
        primary_ip      => 0,
    };
    $self->getinfo($x);

C<HashRef> parameter will return another C<HashRef>:

    my $x = $self->getinfo({
        content_type    => 0,
        speed_download  => 0,
        primary_ip      => 0,
    });

C<ArrayRef> parameter will return a list:

    my ($content_type, $speed_download, $primary_ip) =
        $self->getinfo([qw(content_type speed_download primary_ip)]);

Complete list of options: L<http://curl.haxx.se/libcurl/c/curl_easy_getinfo.html>

=head1 SEE ALSO

=over 4

=item *

L<Moose>

=item *

L<MooseX::NonMoose>

=item *

L<Net::Curl::Easy>

=back

=head1 AUTHOR

Stanislaw Pusep <stas@sysd.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Stanislaw Pusep.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

