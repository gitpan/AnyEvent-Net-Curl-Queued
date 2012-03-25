package AnyEvent::Net::Curl::Queued;
# ABSTRACT: Any::Moose wrapper for queued downloads via Net::Curl & AnyEvent


use common::sense;

use AnyEvent;
use Any::Moose;
use Any::Moose qw(::Util::TypeConstraints);
use Net::Curl::Share;

use AnyEvent::Net::Curl::Queued::Multi;

our $VERSION = '0.016'; # VERSION


has allow_dups  => (is => 'ro', isa => 'Bool', default => 0);


has completed  => (
    traits      => ['Counter'],
    is          => 'ro',
    isa         => 'Int',
    default     => 0,
    handles     => {qw{
        inc_completed inc
    }},
);


has cv          => (is => 'rw', isa => 'Ref | Undef', default => sub { AE::cv }, lazy => 1);


subtype 'MaxConn'
    => as Int
    => where { $_ >= 1 };
has max         => (is => 'rw', isa => 'MaxConn', default => 4);


has multi       => (is => 'rw', isa => 'AnyEvent::Net::Curl::Queued::Multi');


has queue       => (
    traits      => ['Array'],
    is          => 'ro',
    isa         => 'ArrayRef[Any]',
    default     => sub { [] },
    handles     => {qw{
        queue_push      push
        queue_unshift   unshift
        dequeue         shift
        count           count
    }},
);


has share       => (is => 'ro', isa => 'Net::Curl::Share', default => sub { Net::Curl::Share->new }, lazy => 1);


has stats       => (is => 'ro', isa => 'AnyEvent::Net::Curl::Queued::Stats', default => sub { AnyEvent::Net::Curl::Queued::Stats->new }, lazy => 1);


has timeout     => (is => 'ro', isa => 'Num', default => 60.0);


has unique      => (is => 'rw', isa => 'HashRef[Str]', default => sub { {} });


has watchdog    => (is => 'rw', isa => 'Ref | Undef');

sub BUILD {
    my ($self) = @_;

    $self->multi(
        AnyEvent::Net::Curl::Queued::Multi->new({
            max         => $self->max,
            timeout     => $self->timeout,
        })
    );

    $self->share->setopt(Net::Curl::Share::CURLSHOPT_SHARE, Net::Curl::Share::CURL_LOCK_DATA_COOKIE);   # 2
    $self->share->setopt(Net::Curl::Share::CURLSHOPT_SHARE, Net::Curl::Share::CURL_LOCK_DATA_DNS);      # 3
    eval { $self->share->setopt(Net::Curl::Share::CURLSHOPT_SHARE, Net::Curl::Share::CURL_LOCK_DATA_SSL_SESSION) };
}


sub start {
    my ($self) = @_;

    # watchdog
    $self->watchdog(AE::timer 1, 1, sub {
        $self->multi->perform;
        $self->empty;
    });

    # populate queue
    $self->add($self->dequeue)
        while
            $self->count
            and ($self->multi->handles < $self->max);

    # check if queue is empty
    $self->empty;
}


sub empty {
    my ($self) = @_;

    $self->cv->send
        if
            $self->completed > 0
            and $self->count == 0
            and $self->multi->handles == 0;
}



sub add {
    my ($self, $worker) = @_;

    # vivify the worker
    $worker = $worker->()
        if ref($worker) eq 'CODE';

    # self-reference & warmup
    $worker->queue($self);
    $worker->init;

    # check if already processed
    if (not $self->allow_dups and not $worker->force) {
        return if ++$self->unique->{$worker->unique} > 1;
    }

    # fire
    $self->multi->add_handle($worker);
}


sub append {
    my ($self, $worker) = @_;

    $self->queue_push($worker);
    $self->start;
}


sub prepend {
    my ($self, $worker) = @_;

    $self->queue_unshift($worker);
    $self->start;
}


sub wait {
    my ($self) = @_;

    # handle queue
    $self->cv->recv;

    # stop the watchdog
    $self->watchdog(undef);

    # reload
    $self->cv(AE::cv);
    $self->multi(
        AnyEvent::Net::Curl::Queued::Multi->new({
            max         => $self->max,
            timeout     => $self->timeout,
        })
    );
}


no Any::Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__
=pod

=encoding utf8

=head1 NAME

AnyEvent::Net::Curl::Queued - Any::Moose wrapper for queued downloads via Net::Curl & AnyEvent

=head1 VERSION

version 0.016

=head1 SYNOPSIS

    #!/usr/bin/env perl

    package CrawlApache;
    use common::sense;

    use HTML::LinkExtor;
    use Any::Moose;

    extends 'AnyEvent::Net::Curl::Queued::Easy';

    after finish => sub {
        my ($self, $result) = @_;

        say $result . "\t" . $self->final_url;

        if (
            not $self->has_error
            and $self->getinfo('content_type') =~ m{^text/html}
        ) {
            my @links;

            HTML::LinkExtor->new(sub {
                my ($tag, %links) = @_;
                push @links,
                    grep { $_->scheme eq 'http' and $_->host eq 'localhost' }
                    values %links;
            }, $self->final_url)->parse(${$self->data});

            for my $link (@links) {
                $self->queue->prepend(sub {
                    CrawlApache->new({ initial_url => $link });
                });
            }
        }
    };

    no Any::Moose;
    __PACKAGE__->meta->make_immutable;

    1;

    package main;
    use common::sense;

    use AnyEvent::Net::Curl::Queued;

    my $q = AnyEvent::Net::Curl::Queued->new;
    $q->append(sub {
        CrawlApache->new({ initial_url => 'http://localhost/manual/' })
    });
    $q->wait;

=head1 DESCRIPTION

Efficient and flexible batch downloader with a straight-forward interface:

=over 4

=item *

create a queue;

=item *

append/prepend URLs;

=item *

wait for downloads to end (retry on errors).

=back

Download init/finish/error handling is defined through L<Moose's method modifiers|Moose::Manual::MethodModifiers>.

=head2 MOTIVATION

I am very unhappy with the performance of L<LWP>.
It's almost perfect for properly handling HTTP headers, cookies & stuff, but it comes at the cost of I<speed>.
While this doesn't matter when you make single downloads, batch downloading becomes a real pain.

When I download large batch of documents, I don't care about cookies or headers, only content and proper redirection matters.
And, as it is clearly an I/O bottleneck operation, I want to make as many parallel requests as possible.

So, this is what L<CPAN> offers to fulfill my needs:

=over 4

=item *

L<Net::Curl>: Perl interface to the all-mighty L<libcurl|http://curl.haxx.se/libcurl/>, is well-documented (opposite to L<WWW::Curl>);

=item *

L<AnyEvent>: the L<DBI> of event loops. L<Net::Curl> also provides a nice and well-documented example of L<AnyEvent> usage (L<03-multi-event.pl|Net::Curl::examples/Multi::Event>);

=item *

L<MooseX::NonMoose>: L<Net::Curl> uses a Pure-Perl object implementation, which is lightweight, but a bit messy for my L<Moose>-based projects. L<MooseX::NonMoose> patches this gap.

=back

L<AnyEvent::Net::Curl::Queued> is a glue module to wrap it all together.
It offers no callbacks and (almost) no default handlers.
It's up to you to extend the base class L<AnyEvent::Net::Curl::Queued::Easy> so it will actually download something and store it somewhere.

=head2 BENCHMARK

Obviously, the bottleneck of any kind of download agent is the connection itself.
However, socket handling and header parsing add a lots of overhead.

The script F<eg/benchmark.pl> compares L<AnyEvent::Net::Curl::Queued> against several other download agents.
Only L<AnyEvent::Net::Curl::Queued> itself, L<AnyEvent::Curl::Multi>, L<Parallel::Downloader> and L<lftp|http://lftp.yar.ru/> support parallel connections natively;
thus, L<Parallel::ForkManager> is used to reproduce the same behaviour for the remaining agents.
Both L<AnyEvent::Curl::Multi> and L<LWP::Curl> are frontends for L<WWW::Curl>.
L<Parallel::Downloader> uses L<AnyEvent::HTTP> as it's backend.

The download target is a copy of the L<Apache documentation|http://httpd.apache.org/docs/2.2/> on an Apache server located in another datacenter.
The benchmark separates the client initialization from the download management, when possible (not possible on external utilities neither L<AnyEvent::Curl::Multi>.
(L<AnyEvent::Net::Curl::Queued> is actually I<"cheating">, as it's non-lazy initialization is slower than the whole download cycle for everything else except L<WWW::Mechanize> and L<LWP::UserAgent>!!!)

                         URLs/s   W::M   LWP  AE::C::M  lftp  H::T  H::L  YADA  P::D  curl  L::C  wget
    WWW::Mechanize          195     --  -50%      -60%  -76%  -76%  -77%  -81%  -84%  -92%  -93%  -94%
    LWP::UserAgent          392   101%    --      -21%  -51%  -52%  -53%  -61%  -67%  -83%  -87%  -88%
    AnyEvent::Curl::Multi   493   153%   26%        --  -39%  -40%  -41%  -51%  -59%  -79%  -83%  -84%
    lftp                    802   312%  105%       63%    --   -3%   -4%  -21%  -33%  -66%  -73%  -75%
    HTTP::Tiny              825   323%  110%       67%    3%    --   -1%  -19%  -32%  -65%  -72%  -74%
    HTTP::Lite              833   329%  113%       69%    4%    1%    --  -17%  -31%  -65%  -72%  -74%
    YADA                   1013   419%  158%      105%   26%   23%   21%    --  -16%  -57%  -66%  -68%
    Parallel::Downloader   1205   518%  207%      144%   50%   46%   44%   19%    --  -49%  -59%  -62%
    curl                   2370  1115%  504%      380%  195%  187%  183%  134%   97%    --  -20%  -25%
    LWP::Curl              2969  1421%  657%      501%  269%  260%  255%  193%  146%   25%    --   -6%
    wget                   3166  1523%  707%      541%  294%  284%  279%  213%  163%   34%    7%    --

Kudos to L<Parallel::Downloader> and L<LWP::Curl> C<:)>

=head1 ATTRIBUTES

=head2 allow_dups

Allow duplicate requests (default: false).
By default, requests to the same URL (more precisely, requests with the same L<signature|AnyEvent::Net::Curl::Queued::Easy/sha> are issued only once.
To seed POST parameters, you must extend the L<AnyEvent::Net::Curl::Queued::Easy> class.
Setting C<allow_dups> to true value disables request checks.

=head2 completed

Count completed requests.

=head2 cv

L<AnyEvent> condition variable.
Initialized automatically, unless you specify your own.
Also reset automatically after L</wait>, so keep your own reference if you really need it!

=head2 max

Maximum number of parallel connections (default: 4; minimum value: 1).

=head2 multi

L<Net::Curl::Multi> instance.

=head2 queue

C<ArrayRef> to the queue.
Has the following helper methods:

=over 4

=item *

queue_push: append item at the end of the queue;

=item *

queue_unshift: prepend item at the top of the queue;

=item *

dequeue: shift item from the top of the queue;

=item *

count: number of items in queue.

=back

=head2 share

L<Net::Curl::Share> instance.

=head2 stats

L<AnyEvent::Net::Curl::Queued::Stats> instance.

=head2 timeout

Timeout (default: 60 seconds).

=head2 unique

Signature cache.

=head2 watchdog

The last resort against the non-deterministic chaos of evil lurking sockets.

=head1 METHODS

=head2 start()

Populate empty request slots with workers from the queue.

=head2 empty()

Check if there are active requests or requests in queue.

=head2 add($worker)

Activate a worker.

=head2 append($worker)

Put the worker (instance of L<AnyEvent::Net::Curl::Queued::Easy>) at the end of the queue.
For lazy initialization, wrap the worker in a C<sub { ... }>, the same way you do with the L<Moose> C<default =E<gt> sub { ... }>:

    $queue->append(sub {
        AnyEvent::Net::Curl::Queued::Easy->new({ initial_url => 'http://.../' })
    });

=head2 prepend($worker)

Put the worker (instance of L<AnyEvent::Net::Curl::Queued::Easy>) at the beginning of the queue.
For lazy initialization, wrap the worker in a C<sub { ... }>, the same way you do with the L<Moose> C<default =E<gt> sub { ... }>:

    $queue->prepend(sub {
        AnyEvent::Net::Curl::Queued::Easy->new({ initial_url => 'http://.../' })
    });

=head2 wait()

Process queue.

=head1 CAVEAT

The I<"Attempt to free unreferenced scalar: SV 0xdeadbeef during global destruction."> message on finalization is mostly harmless.

=head1 SEE ALSO

=over 4

=item *

L<AnyEvent>

=item *

L<Any::Moose>

=item *

L<Net::Curl>

=item *

L<WWW::Curl>

=item *

L<AnyEvent::Curl::Multi>

=back

=head1 AUTHOR

Stanislaw Pusep <stas@sysd.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Stanislaw Pusep.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

