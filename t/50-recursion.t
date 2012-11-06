#!perl
package MyDownloader;
use strict;
use utf8;
use warnings qw(all);

use Any::Moose;
use Net::Curl::Easy qw(/^CURLOPT_/);

extends 'AnyEvent::Net::Curl::Queued::Easy';

has cb      => (is => 'ro', isa => 'CodeRef', required => 1);

after finish => sub {
    my ($self, $result) = @_;

    my @path = $self->final_url->path_segments;
    my $str = pop @path;
    my $num = pop @path;
    --$num;

    for (0 .. $num) {
        $str++;
        my $uri = $self->final_url->clone;
        $uri->path('/repeat/' . $_ . '/' . $str);

        # TODO prepend() fails sporadically?!
        $self->queue->append(
            sub {
                __PACKAGE__->new(
                    initial_url => $uri,
                    cb          => $self->cb,
                )
            }
        );
    }

    $self->cb->(@_);
};

no Any::Moose;
__PACKAGE__->meta->make_immutable;

1;

package main;
use strict;
use utf8;
use warnings qw(all);

use Test::More;

use_ok('AnyEvent::Net::Curl::Queued');
use_ok('AnyEvent::Net::Curl::Queued::Easy');
use_ok('AnyEvent::Net::Curl::Queued::Stats');
use_ok('Test::HTTP::AnyEvent::Server');

my $server = Test::HTTP::AnyEvent::Server->new;
isa_ok($server, 'Test::HTTP::AnyEvent::Server');

my $q = AnyEvent::Net::Curl::Queued->new;
isa_ok($q, qw(AnyEvent::Net::Curl::Queued));

$q->append(
    sub {
        MyDownloader->new(
            initial_url => $server->uri . 'repeat/6/aaaaa',
            cb          => sub {
                my ($self, $result) = @_;

                isa_ok($self, qw(MyDownloader));
                ok($result == 0, 'got CURLE_OK for ' . $self->final_url);
                ok(!$self->has_error, "libcurl message: '$result'");
            },
        )
    }
);

$q->wait;

done_testing(156);
