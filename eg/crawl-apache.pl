#!/usr/bin/env perl
use common::sense;

use Data::Printer;

use YADA;
use CrawlApache;

my $q = YADA->new;
$q->append(sub {
    CrawlApache->new({ initial_url => 'http://localhost/manual/', use_stats => 1 })
});
$q->wait;

p $q->stats;
