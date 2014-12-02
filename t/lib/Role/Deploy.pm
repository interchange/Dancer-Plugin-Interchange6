package Role::Deploy;

use Test::Exception;
use Test::More;
use Test::Roo::Role;
use Interchange6::Schema;

use Dancer qw(:tests !after);
use Dancer::Plugin::Interchange6;
use Dancer::Plugin::DBIC;
use Dancer::Test;

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

    # deploy magically happens in here:
    lives_ok { $self->load_all_fixtures } "load all fixtures";

    cmp_ok( $self->attributes->count, '>=', 4, "at least 4 attributes" );
    cmp_ok( $self->countries->count, '>=', 250, "at least 250 countries" );
    cmp_ok( $self->price_modifiers->count,
        '>=', 15, "at least 15 price_modifiers" );
    cmp_ok( $self->roles->count, '>=', 5, "at least 5 roles" );
    cmp_ok( $self->states->count, '>=', 64, "at least 64 states" );
    cmp_ok( $self->taxes->count, '>=', 37, "at least 37 Tax rates" );
    cmp_ok( $self->users->count, '>=', 5, "at least 5 users" );
    cmp_ok( $self->zones->count, '>=', 317, "at least 317 zones" );

};

1;
