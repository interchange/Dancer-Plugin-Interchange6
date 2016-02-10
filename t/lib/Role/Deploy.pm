package Role::Deploy;

=head1 NAME

Role::Deploy

=cut

use Test::Exception;
use Test::More;

use Dancer qw/set setting/;
use Dancer::Plugin::Interchange6;

use namespace::clean;
use Test::Roo::Role;

=head1 ATTRIBUTES

=head2 log

L<Dancer::Config/log> - defaults to 'debug'

=cut

has log => (
    is       => 'ro',
    default  => sub { set log => 'debug'; 'debug' },
    trigger  => 1,
);

sub _trigger_log {
    my ( $self, $value ) = @_;
    set log => $value;
};

=head2 logger

L<Dancer::Config/logger> - defaults to 'capture'

=cut

has logger => (
    is      => 'ro',
    default  => sub { set logger => 'capture'; 'capture' },
    trigger  => 1,
);

sub _trigger_logger {
    my ( $self, $value ) = @_;
    set logger => $value;
};

=head2 trap

defaults to C<< Dancer::Logger::Capture->trap >>

=cut

has trap => (
    is      => 'ro',
    default => sub { Dancer::Logger::Capture->trap },
);

test 'deploy tests' => sub {
    my $self = shift;

    diag "Role::Deploy";

    setting('plugins')->{DBIC} = {
        default => {
            schema_class => $self->schema_class,
            connect_info => [ $self->connect_info ],
        },
        shop2 => {
            schema_class => $self->schema_class,
            connect_info => [ $self->connect_info ],
        }
    };

    my $schema = shop_schema;

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
