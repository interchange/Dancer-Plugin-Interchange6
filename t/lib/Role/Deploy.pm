package Role::Deploy;

use Test::Exception;
use Test::More;
use Test::Roo::Role;
use Interchange6::Schema;
use Interchange6::Schema::Populate::CountryLocale;
use Interchange6::Schema::Populate::StateLocale;
use Interchange6::Schema::Populate::Zone;
use Interchange6::Schema::Populate::MessageType;

use Dancer qw(:tests !after);
use Dancer::Plugin::Interchange6;
use Dancer::Plugin::DBIC;
use Dancer::Test;

use Data::Dumper;
use DateTime;

test 'deploy tests' => sub {
    my $self = shift;

    diag "Role::Deploy";

    set plugins => {
        DBIC => {
            default => {
                schema_class => $self->schema_class,
                connect_info => [ $self->connect_info ],
            }
        }
    };

    my $schema = schema;

    set session => 'DBIC';
    set session_options => { schema => $schema, };

    lives_ok { $schema->deploy } "Deploy schema";

    my $pop_countries =
      Interchange6::Schema::Populate::CountryLocale->new->records;
    my $pop_states = Interchange6::Schema::Populate::StateLocale->new->records;
    my $pop_zones  = Interchange6::Schema::Populate::Zone->new->records;
    my $pop_message_types =
      Interchange6::Schema::Populate::MessageType->new->records;

    lives_ok( sub { my $ret = $schema->populate( 'Country', $pop_countries ) },
        "populate Country" );
    lives_ok( sub { my $ret = $schema->populate( 'State', $pop_states ) },
        "populate State" );
    lives_ok( sub { my $ret = $schema->populate( 'Zone', $pop_zones ) },
        "populate Zone" );
    lives_ok(
        sub { my $ret = $schema->populate( 'MessageType', $pop_message_types ) }
        ,
        "populate MessageType"
    );

    lives_ok(
        sub {
            shop_user->create(
                {
                    username => 'testuser',
                    email    => 'user@example.com',
                    password => 'mypassword'
                }
            );
        },
        "create testuser"
    );

};

1;
