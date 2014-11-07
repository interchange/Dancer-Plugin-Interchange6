use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Dancer::Plugin::Interchange6',
    AUTHOR              => q{Stefan Hornburg (Racke) <racke@linuxia.de>},
    VERSION_FROM        => 'lib/Dancer/Plugin/Interchange6.pm',
    ABSTRACT            => 'Dancer Plugin for Interchange6 Open Source Shop Machine',
    ($ExtUtils::MakeMaker::VERSION >= 6.47
      ? ('LICENSE'=> 'perl')
      : ()),
    MIN_PERL_VERSION    => '5.014000',
    PL_FILES            => {},
    EXE_FILES           => ['bin/interchange6-expire-sessions'],
    BUILD_REQUIRES      => {
                            'Test::Most' => 0,
                            'DBICx::TestDatabase' => 0,
                            'Test::Database' => 0,
                            'Test::Roo' => 1.004,
                      },
    PREREQ_PM => {
                  'YAML'       => 0,
                  'Interchange6::Schema'     => '0.060',
                  'Interchange6' => '0.060',
                  'Dancer'     => 1.3098,
                  'Dancer::Session::DBIC' => 0,
                  'Dancer::Plugin::DBIC' => 0,
                  'Dancer::Plugin::Auth::Extensible' => 0,
                  'Dancer::Plugin::Auth::Extensible::Provider::DBIC' => 0,
                  'Business::OnlinePayment' => 3.02,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Dancer-Plugin-Interchange6-*' },
    test                => { TESTS => join( ' ', (glob( 't/*.t'), glob('t/*/*.t')))},
    META_MERGE        => {
        resources => {
            repository  => 'https://github.com/interchange/Dancer-Plugin-Interchange6.git',
            bugtracker => 'https://github.com/interchange/Dancer-Plugin-Interchange6/issues',
            IRC => 'irc://irc.freenode.net/#interchange',
        },
    },
);
