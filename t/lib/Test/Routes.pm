package Test::Routes;

# Dancer::Test uses some deep voodoo so please be very careful about changing
# the order of the setup parts of these tests. Note that some settings
# have to be set in config.yml in order to make them work but others we
# have to set within this script.
# IMPORTANT: these tests cannot live directly under 't' since Dancer merrily
# trashes appdir under certain circumstances when we live there.

use Test::More;
use Test::Deep;
use Test::Exception;

use Dancer qw/config set/;
use Dancer::Logger::Capture;
use Dancer::Plugin::Interchange6;
use Dancer::Plugin::Interchange6::Routes;

use namespace::clean;
use Test::Roo::Role;
with 'Role::Mechanize';

test 'route tests' => sub {
    my $self = shift;

    my $mech = $self->mech;

    diag "Test::Routes";

    my ( $resp, $sessionid, %form, $log, @logs, $user );

    my $schema = shop_schema;

    set log    => 'debug';
    set logger => 'capture';

    my $trap = Dancer::Logger::Capture->trap;

    # make sure there are no existing carts
    $schema->resultset('Cart')->delete_all;

    $mech->get_ok( '/ergo-roller', "GET /ergo-roller (product route via uri)" );

    $mech->content_like( qr|name="Ergo Roller"|, 'found Ergo Roller' )
      or diag $mech->content;

    $mech->get_ok( '/os28005', "GET /os28005 (product route via sku)" );

    $log = pop @{ $trap->read };
    cmp_deeply(
        $log,
        {
            level => "debug",
            message =>
              "Redirecting permanently to product uri trim-brush for os28005."
        },
        "Check 'Redirecting permanently...' debug message"
    ) || diag explain $log;

    $mech->base_is( 'http://localhost/trim-brush', "Check redirect path" );

    # navigation

    $mech->get_ok( '/hand-tools', "GET /hand-tools (navigation route)" );

    $mech->content_like( qr|name="Hand Tools"|, 'found Hand Tools' );

    $mech->content_like( qr|products="([^,]+,){9}[^,]+"|, 'found 10 products' );

    $mech->get_ok( '/hand-tools/brushes',
        "GET /hand-tools/brushes (navigation route)" );

    $mech->content_like( qr|name="Brushes"|, 'found Brushes' );

    $mech->content_like( qr|products="[^,]+,[^,]+"|, 'found 2 products' );

    $mech->content_like( qr|products=".*Brush Set|, 'found Brush Set' );

    # cart

    $mech->get_ok( '/cart', "GET /cart" );

    # try to add canonical product which has variants to cart
    $mech->post_ok(
        '/cart',
        { sku => 'os28004' },
        "POST /cart add Ergo Roller"
    );

    $mech->base_is( 'http://localhost/ergo-roller', "Check redirect path" );

    # non-existant variant
    $mech->post_ok(
        '/cart',
        { sku => 'os28004', roller => 'camel', color => 'orange' },
        "POST /cart add Ergo Roller camel orange"
    );

    $mech->base_is( 'http://localhost/ergo-roller', "Check redirect path" );

    # now add variant
    $mech->post_ok(
        '/cart',
        { sku => 'os28004', roller => 'camel', color => 'black' },
        "POST /cart add Ergo Roller camel black"
    );

    $mech->base_is( 'http://localhost/cart', "Check redirect path" );

    $mech->content_like( qr/cart_subtotal="16/, 'cart_subtotal is 16.00' );

    $mech->content_like( qr/cart_total="16/, 'cart_total is 16.00' );

    $mech->content_like(
        qr/cart="os28004-CAM-BLK:Ergo Roller:1:16/,
        'found qty 1 os28004-CAM-BLK in cart'
    );

    # add again
    $mech->post_ok(
        '/cart',
        { sku => 'os28004', roller => 'camel', color => 'black' },
        "POST /cart add Ergo Roller camel black"
    );

    $mech->content_like( qr/cart_subtotal="32/, 'cart_subtotal is 32.00' );

    $mech->content_like( qr/cart_total="32/, 'cart_total is 32.00' );

    $mech->content_like(
        qr/cart="os28004-CAM-BLK:Ergo Roller:2:16/,
        'found qty 2 os28004-CAM-BLK in cart'
    );

    # now different variant
    $mech->post_ok(
        '/cart',
        { sku => 'os28004', roller => 'camel', color => 'white' },
        "POST /cart add Ergo Roller camel white"
    );

    $mech->content_like( qr/cart_subtotal="48/, 'cart_subtotal is 48.00' );

    $mech->content_like( qr/cart_total="48/, 'cart_total is 48.00' );

    $mech->content_like(
        qr/cart="os28004-CAM-BLK:.+:2:16.+,os28004-CAM-WHT:.+:1:16/,
        'found qty 1 os28004-CAM-WHT in cart and qty 2 BLK'
    ) or diag $mech->content;

    # add non-existant product
    $mech->post_ok( '/cart', { sku => 'POT002' }, "POST /cart add potatoes" );

    $mech->base_is( 'http://localhost/', "Check redirect path" );

    # add variant using variant sku
    $mech->post_ok(
        '/cart',
        { sku => 'os28004-HUM-BLK' },
        "POST /cart add Ergo Roller human black using variant's sku only"
    );

    $mech->content_like( qr/cart_total="64/, 'cart_total is 64.00' )
      or diag $mech->content;

    # remove the variant
    $mech->post_ok(
        '/cart',
        { remove => 'os28004-HUM-BLK' },
        "POST /cart remove Ergo Roller human black using variant's sku only"
    );

    $mech->content_like( qr/cart_total="48/, 'cart_total is 48.00' );

    # GET /cart
    $mech->get_ok( '/cart', "GET /cart" );

    $mech->content_like( qr/cart_subtotal="48/, 'cart_subtotal is 48.00' );

    $mech->content_like( qr/cart_total="48/, 'cart_total is 48.00' );

    $mech->content_like(
        qr/cart="os28004-CAM-BLK:.+:2:16.+,os28004-CAM-WHT:.+:1:16/,
        'found qty 1 os28004-CAM-WHT in cart and qty 2 BLK'
    );

    # login

    # grab session id - we want to make sure it does NOT change on login
    # but that it DOES change after logout
    # TODO: the session id does NOT currently change on login but it ought to

    $mech->get_ok( '/sessionid', "GET /sessionid" );
    $sessionid = $mech->content;

    $mech->get_ok( '/private', "GET /private (login restricted)" );

    $mech->base_is( 'http://localhost/login?return_url=%2Fprivate',
        "Redirected to /login" );

    $mech->content_like( qr/Login form/, 'got login page' );

    # bad login

    $trap->read;    # clear logs

    $mech->post_ok(
        '/login',
        {
            username => 'testuser',
            password => 'badpassword'
        },
        "POST /login with bad password"
    );

    $mech->content_like( qr/Login form/, 'got login page' );

    $log = pop @{ $trap->read };
    cmp_deeply(
        $log,
        { level => "debug", message => "Authentication failed for testuser" },
        "Check auth failed debug message"
    ) || diag explain $log;

    # good login

    $mech->post_ok(
        '/login',
        {
            username => 'customer1',
            password => 'c1passwd'
        },
        "POST /login with good password"
    );
    $mech->base_is( 'http://localhost/', "Redirected to /" );

    my $logs = $trap->read;
    $log = pop @$logs;
    cmp_deeply(
        $log,
        { level => "debug", message => re('Change users_id') },
        "users_id set in debug logs"
    ) || diag explain $log;

    $log = pop @$logs;
    cmp_deeply(
        $log,
        { level => "debug", message => "users accepted user customer1" },
        "login successful in debug logs"
    ) || diag explain $log;

    $mech->get_ok( '/sessionid', "GET /sessionid" );

    cmp_ok( $mech->content, 'eq', $sessionid,
        "Check session id has not changed" );

    # we should now be able to GET /private

    $mech->get_ok( '/private', "GET /private (login restricted)" );

    $mech->content_like( qr/Private page/, 'got private page' );

    # price modifiers

    lives_ok( sub { $user = shop_user->find( { username => 'customer1' } ) },
        "grab customer1 fom db" );

    cmp_ok( $user->roles->count, "==", 1, "user has 1 role" );

    $mech->post_ok(
        '/cart',
        { sku => 'os28005', quantity => 5 },
        "POST /cart add 5 Trim Brushes"
    );

    $mech->content_like( qr/cart_subtotal="92.95"/, 'cart_subtotal is 92.95' );

    $mech->content_like(
        qr/cart=.+os28005:Trim Brush:5:8.99:8.99:/,
        'found qty 5 os28005 @ 8.99 in cart'
    );

    # authenticated user should get selling_price of 8.20
    # total is 48 for ergo rollers plus 82 for trim brushes = 130
    $mech->post_ok(
        '/cart',
        { sku => 'os28005', quantity => 5 },
        "POST /cart add 5 Trim Brushes"
    );

    $mech->content_like( qr/cart_subtotal="130.00"/,
        'cart_subtotal is 130.00' );

    $mech->content_like(
        qr/cart=.+os28005:Trim Brush:10:8.99:8.20:/,
        'found qty 10 os28005 @ 8.20 in cart'
    );

    # add trade role to user
    lives_ok( sub { $user->add_to_roles( { name => 'trade' } ) },
        "Add user to role trade" );

    # trade user should get selling_price of 7.80
    # total is 48 for ergo rollers plus 78 for trim brushes = 126
    $mech->get_ok( '/cart', "GET /cart" );

    $mech->content_like( qr/cart_subtotal="126.00"/,
        'cart_subtotal is 126.00' );

    $mech->content_like(
        qr/cart=.+os28005:Trim Brush:10:8.99:7.80:/,
        'found qty 10 os28005 @ 7.80 in cart'
    );

    # checkout

    $mech->get_ok( '/checkout', "GET /checkout" ) or diag $mech->content;

    $mech->content_like( qr/cart_subtotal="126.00"/,
        'cart_subtotal is 126.00' );

    $mech->content_like( qr/cart_total="126.00"/, 'cart_total is 126.00' );

    $mech->content_like(
        qr/cart=".+:Ergo Roller:2:16.+,os28004-CAM-WHT:.+:1:16/,
        'found 2 ergo roller variants at checkout' ) or diag $mech->content;

    my @carts = $schema->resultset('Cart')->hri->all;
    cmp_ok @carts, '==', 1, "1 cart in the database";

    # logout

    $mech->get_ok( '/logout', "GET /logout" );

    $mech->base_is( 'http://localhost/', "Redirected to /" );

    $mech->get_ok( '/sessionid', "GET /sessionid" );

    cmp_ok( $mech->content, 'ne', $sessionid, "Check session id has changed" );

    $mech->get_ok( '/private', "GET /private (login restricted)" );

    $mech->base_is( 'http://localhost/login?return_url=%2Fprivate',
        "Redirected to /login" );

    lives_ok { $mech->get('/cart') } "GET /cart";

    $mech->content_like( qr/cart_total="0/, 'cart_total is 0' );

    $mech->content_like( qr/cart=""/, 'cart is empty' );

    # add items to cart then login again to test cart combining via
    # load_saved_products

    @carts = $schema->resultset('Cart')->hri->all;
    cmp_ok @carts, '==', 1, "1 cart in the database";

    $mech->post_ok(
        '/cart',
        { sku => 'os28004', roller => 'camel', color => 'white' },
        "POST /cart add Ergo Roller camel white"
    );

    @carts = $schema->resultset('Cart')->hri->all;
    cmp_ok @carts, '==', 1, "1 cart in the database";

    $mech->content_like( qr/cart_subtotal="16/, 'cart_subtotal is 16.00' );

    $mech->content_like( qr/cart_total="16/, 'cart_total is 16.00' );

    $mech->content_like(
        qr/cart="os28004-CAM-WHT:.+:1:16/,
        'found qty 1 os28004-CAM-WHT in cart'
    ) or diag $mech->content;

    $mech->post_ok(
        '/login',
        {
            username => 'customer1',
            password => 'c1passwd'
        },
        "POST /login with good password"
    );

    $mech->get_ok( '/cart', "GET /cart" );

    $mech->content_like( qr/cart_subtotal="16/, 'cart_subtotal is 16.00' );

    $mech->content_like( qr/cart_total="16/, 'cart_total is 16.00' );

    $mech->content_like(
        qr/cart="os28004-CAM-WHT:.+:1:16/,
        'found qty 1 os28004-CAM-WHT in cart'
    ) or diag $mech->content;

    # shop_redirect
    $mech->get( '/old-hand-tools', "GET /old-hand-tools" );

    cmp_ok( $mech->status, 'eq', '404', 'status is not_found' );

    $schema->resultset("UriRedirect")->delete;

    scalar $schema->resultset("UriRedirect")->populate(
        [
            [qw/uri_source      uri_target  status_code/],
            [qw/old-hand-tools  hand-tools  301/],
            [qw/one             two         301/],
            [qw/two             hand-tools  302/],
            [qw/bad1            bad2        301/],
            [qw/bad2            bad3        301/],
            [qw/bad3            bad1        302/],
        ]
    );

    cmp_ok( $schema->resultset('UriRedirect')->count,
        '==', 6, "6 UriRedirect rows" );

    $mech->get_ok( '/old-hand-tools', "GET /old-hand-tools" );

    $mech->base_is( 'http://localhost/hand-tools', 'redirect is ok' );

    $mech->get_ok( '/one', "GET /one" );

    $mech->base_is( 'http://localhost/hand-tools', 'redirect is ok' );

    lives_ok { $mech->get('/bad1')} "circular redirect";

    cmp_ok( $mech->status, 'eq', '404', 'status is not_found' );
};

1;
