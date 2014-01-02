use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Dancer::Plugin::Interchange6',
    AUTHOR              => q{Stefan Hornburg (Racke) <racke@linuxia.de>},
    VERSION_FROM        => 'lib/Dancer/Plugin/Interchange6.pm',
    ABSTRACT            => 'Dancer Plugin for Interchange6 Open Source Shop Machine',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    BUILD_REQUIRES      => {
                            'Test::More' => 0,
                            'DBICx::TestDatabase' => 0,
                            'Test::Database' => 0,
                      },
    PREREQ_PM => {
                  'YAML'       => 0,
                  'Interchange6::Schema'     => 0.011,
                  'Interchange6' => 0.003,
                  'Dancer'     => 1.3098,
                  'Dancer::Plugin::DBIC' => 0,
                  'Dancer::Plugin::Auth::Extensible' => 0,
                  'Business::OnlinePayment' => 3.02,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Dancer-Plugin-Interchange6-*' },
    META_MERGE        => {
        resources => {
            repository  => 'https://github.com/interchange/Dancer-Plugin-Interchange6.git',
            bugtracker => 'https://github.com/interchange/Dancer-Plugin-Interchange6/issues'
        },
    },
);
