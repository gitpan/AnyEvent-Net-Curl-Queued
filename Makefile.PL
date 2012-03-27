
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Any::Moose wrapper for queued downloads via Net::Curl & AnyEvent",
  "AUTHOR" => "Stanislaw Pusep <stas\@sysd.org>",
  "BUILD_REQUIRES" => {
    "English" => 0,
    "File::Find" => 0,
    "File::Temp" => 0,
    "Test::HTTP::Server" => 0,
    "Test::Kwalitee" => 0,
    "Test::More" => 0,
    "Test::Requires" => 0,
    "warnings" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "AnyEvent-Net-Curl-Queued",
  "EXE_FILES" => [
    "bin/yada"
  ],
  "LICENSE" => "perl",
  "NAME" => "AnyEvent::Net::Curl::Queued",
  "PREREQ_PM" => {
    "Any::Moose" => 0,
    "AnyEvent" => 0,
    "Carp" => 0,
    "Config" => 0,
    "Digest::SHA" => 0,
    "File::Copy" => 0,
    "Getopt::Long" => 0,
    "HTTP::Response" => 0,
    "Memoize" => 0,
    "Mouse::Util::TypeConstraints" => 0,
    "MouseX::NativeTraits" => 0,
    "MouseX::NonMoose" => 0,
    "Net::Curl::Easy" => 0,
    "Net::Curl::Multi" => 0,
    "Net::Curl::Share" => 0,
    "Pod::Usage" => 0,
    "Scalar::Util" => 0,
    "URI" => 0,
    "autodie" => 0,
    "common::sense" => 0,
    "strict" => 0
  },
  "VERSION" => "0.017",
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



