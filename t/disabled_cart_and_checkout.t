use Test::More import => ['!pass'], tests => 2;
use Test::WWW::Mechanize::PSGI;
use Dancer;
use Dancer::Plugin::Interchange6;
use Dancer::Plugin::Interchange6::Routes;

setting('plugins')->{DBIC} = {
    default => {
        schema_class => 'Interchange6::Schema',
        connect_info => [
            "dbi:SQLite:dbname=:memory:",
            undef, undef,
            {
                sqlite_unicode  => 1,
                on_connect_call => 'use_foreign_keys',
                on_connect_do   => 'PRAGMA synchronous = OFF',
                quote_names     => 1,
            }
        ]
    }
};

my $schema = shop_schema;
$schema->deploy;

set session => 'DBIC';
set session_options => { schema => $schema, };

set logger   => 'console';
set log      => 'warn';
set template => 'template_toolkit';    # for coverage testing only
setting('plugins')->{'Interchange6::Routes'} = {
    cart     => { active => 0 },
    checkout => { active => 0 },
};

my $app = sub {
    my $env = shift;
    shop_setup_routes;
    my $request = Dancer::Request->new( env => $env );
    Dancer->dance($request);
};

my $mech = Test::WWW::Mechanize::PSGI->new( app => $app );

subtest "cart route not defined" => sub {

    $mech->get('/cart');

    ok $mech->status eq '404', "/cart not found" or diag $mech->status;
};

subtest "checkout route not defined" => sub {

    $mech->get('/checkout');

    ok $mech->status eq '404', "/checkout not found" or diag $mech->status;
};

