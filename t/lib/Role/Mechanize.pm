package Role::Mechanize;

use Moo::Role;

use Dancer ();
use Test::WWW::Mechanize::PSGI;
use Types::Standard qw/InstanceOf/;

has mech => (
    is      => 'lazy',
    isa     => InstanceOf ['Test::WWW::Mechanize'],
    clearer => 1,
);

sub _build_mech {
    Test::WWW::Mechanize::PSGI->new(
        app => sub {
            my $env = shift;
            Dancer::load_app 'TestApp',;
            my $request = Dancer::Request->new( env => $env );
            Dancer->dance($request);
        }
    );
}

1;
