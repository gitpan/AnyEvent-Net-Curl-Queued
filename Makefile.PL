
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Moo wrapper for queued downloads via Net::Curl & AnyEvent",
  "AUTHOR" => "Stanislaw Pusep <stas\@sysd.org>",
  "BUILD_REQUIRES" => {
    "Test::Exception" => 0,
    "Test::Warn" => 0
  },
  "CONFIGURE_REQUIRES" => {},
  "DISTNAME" => "AnyEvent-Net-Curl-Queued",
  "EXE_FILES" => [
    "bin/yada"
  ],
  "LICENSE" => "perl",
  "NAME" => "AnyEvent::Net::Curl::Queued",
  "PREREQ_PM" => {
    "AnyEvent" => 0,
    "HTTP::Response" => 0,
    "JSON" => 0,
    "Moo" => "1.001000",
    "MooX::Types::MooseLike" => "0.18",
    "Net::Curl" => "0.25",
    "URI" => 0
  },
  "VERSION" => "0.043",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



