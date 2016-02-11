package Test::Hooks;

use Test::Deep;
use Test::Exception;
use Test::More;

use Test::Roo::Role;

test 'before_cart_display hook' => sub {
    my $self = shift;

    diag "Test::Hooks";

    # before_cart_display

    $self->mech->post_ok(
        '/cart',
        { sku => 'os28112', quantity => 2 },
        "POST /cart add os28112 quantity 2"
    );

    $self->trap->read;

    $self->mech->get_ok( '/cart', "GET /cart" );
    $self->mech->base_is( 'http://localhost/cart',
        "seems we're on the correct page" );

    my $logs = $self->trap->read;
    cmp_deeply(
        $logs,
        superbagof(
            {
                level   => 'debug',
                message => 'hook before_cart_display 1 27.98 27.98'
            }
        ),
        "before_cart_display hook fired"
    ) or diag explain $logs;
};

test 'before_checkout_display hook' => sub {
    my $self = shift;

    # before_checkout_display

    $self->trap->read;

    $self->mech->get_ok( '/checkout', "GET /checkout" );
    $self->mech->base_is( 'http://localhost/checkout',
        "seems we're on the correct page" );

    my $logs = $self->trap->read;
    cmp_deeply(
        $logs,
        superbagof(
            {
                level   => 'debug',
                message => 'hook before_checkout_display 1 27.98 27.98'
            }
        ),
        "before_cart_display hook fired"
    ) or diag explain $logs;
};

test 'before_login_display hook' => sub {

    # FIXME: more tests needed
    my $self = shift;
    my $mech = $self->mech;

    # before_login_display

    ok(1);
};

test 'before_navigation hooks' => sub {

    # FIXME: more tests needed
    my $self = shift;
    my $mech = $self->mech;

    # before_navigation_search
    # before_navigation_display

    ok(1);
};

test 'before_product_display hook' => sub {

    # FIXME: more tests needed
    my $self = shift;
    my $mech = $self->mech;

    # before_product_display

    ok(1);
};

test 'cart_add hooks' => sub {
    my $self = shift;

    # before_cart_add_validate
    # before_cart_add
    # after_cart_add

    my $cart;

    lives_ok { $self->ic6s_schema->resultset('Cart')->delete }
    "clear out any carts in the database";

    $self->mech->post_ok(
        '/cart',
        { sku => 'os28005' },
        "POST /cart add os28005"
    );

    my $logs = $self->trap->read;
    cmp_deeply(
        $logs,
        superbagof(
            {
                level   => 'debug',
                message => 'hook before_cart_add_validate main 0.00 os28005'
            },
            {
                level   => 'debug',
                message => 'hook before_cart_add main 0.00 os28005 Trim Brush'
            },
            {
                level => 'debug',
                message => 'hook after_cart_add main 8.99 Interchange6::Cart::Product os28005 Trim Brush'
            },
        ),
        "check debug logs"
    ) or diag explain $logs;
};

test 'cart_update hooks' => sub {
    my $self = shift;

    # before_cart_update
    # after_cart_update

    $self->mech->post_ok(
        '/cart',
        { update => 'os28005', quantity => 3 },
        "POST /cart update os28005 quantity 3"
    );

    my $logs = $self->trap->read;
    cmp_deeply(
        $logs,
        superbagof(
            {
                level   => 'debug',
                message => 'hook before_cart_update main 8.99 os28005 3'
            },
            {
                level   => 'debug',
                message => 'hook after_cart_update os28005 3 os28005 3'
            },
        ),
        "check debug logs"
    ) or diag explain $logs;

    # remove with qty 0 and we end up with different hooks

    $self->mech->post_ok(
        '/cart',
        { update => 'os28005', quantity => 0 },
        "POST /cart update os28005 quantity 0"
    );

    $logs = $self->trap->read;
    cmp_deeply(
        $logs,
        superbagof(
            {
                level   => 'debug',
                message => 'hook before_cart_remove_validate main 26.97 os28005'
            },
            {
                level   => 'debug',
                message => 'hook before_cart_remove main 26.97 os28005'
            },
            {
                level   => 'debug',
                message => 'hook after_cart_remove main 0.00 os28005'
            },
        ),
        "check debug logs"
    ) or diag explain $logs;

};

test 'cart_remove hooks' => sub {
    my $self = shift;

    # before_cart_remove_validate
    # before_cart_remove
    # after_cart_remove

    $self->mech->post_ok(
        '/cart',
        { sku => 'os28005' },
        "POST /cart add os28005"
    );

    $self->trap->read;

    $self->mech->post_ok(
        '/cart',
        { remove => 'os28005' },
        "POST /cart remove os28005"
    );

    my $logs = $self->trap->read;
    cmp_deeply(
        $logs,
        superbagof(
            {
                level   => 'debug',
                message => 'hook before_cart_remove_validate main 8.99 os28005'
            },
            {
                level   => 'debug',
                message => 'hook before_cart_remove main 8.99 os28005'
            },
            {
                level   => 'debug',
                message => 'hook after_cart_remove main 0.00 os28005'
            },
        ),
        "check debug logs"
    ) or diag explain $logs;

};

test 'cart_rename hooks' => sub {
    my $self = shift;

    # before_cart_rename
    # after_cart_rename

    $self->mech->post_ok(
        '/rename_cart',
        { name => 'crazy' },
        "POST /rename_cart name => crazy"
    ) or diag explain $self->trap->read;

    my $logs = $self->trap->read;
    cmp_deeply(
        $logs,
        superbagof(
            {
                level   => 'debug',
                message => 'hook before_cart_rename main main crazy',
            },
            {
                level   => 'debug',
                message => 'hook after_cart_rename crazy main crazy',
            },
        ),
        "check debug logs"
    ) or diag explain $logs;

};

test 'cart_clear hooks' => sub {

    # FIXME: more tests needed
    my $self = shift;

    # before_cart_clear
    # after_cart_clear

    my $cart;

    ok(1);

};

test 'cart_set_users_id hooks' => sub {

    # FIXME: more tests needed
    my $self = shift;

    # before_cart_set_users_id
    # after_cart_set_users_id

    my $cart;

    ok(1);

};

test 'cart_set_sessions_id hooks' => sub {

    # FIXME: more tests needed
    my $self = shift;

    # before_cart_set_sessions_id
    # after_cart_set_sessions_id

    my $cart;

    ok(1);

};

1;
