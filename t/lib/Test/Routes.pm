package Test::Routes;

# Dancer::Test uses some deep voodoo so please be very careful about changing
# the order of the setup parts of these tests. Note that some settings
# have to be set in config.yml in order to make them work but others we
# have to set within this script.
# IMPORTANT: these tests cannot live directly under 't' since Dancer merrily
# trashes appdir under certain circumstances when we live there.

use Test::Most;
use Test::Roo::Role;
use File::Spec;
use Data::Dumper;

use Interchange6::Schema;

use Dancer qw/:tests !after/;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Interchange6;
use Dancer::Plugin::Interchange6::Routes;

test 'route tests' => sub {
    my $self = shift;

    diag "Test::Routes";

    my ( $resp, $sessionid, %form, $log, @logs, $user );

    my $schema = schema;

    use TestApp;
    use Dancer::Test;

    # product

    lives_ok { $resp = dancer_response GET => '/ergo-roller' }
    "GET /ergo-roller (product route via uri)";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr|name="Ergo Roller"|, 'found Ergo Roller';

    lives_ok { $resp = dancer_response GET => '/os28005' }
    "GET /os28005 (product route via sku)";

    $log = pop @{&read_logs};
    cmp_deeply(
        $log,
        {
            level => "debug",
            message =>
              "Redirecting permanently to product uri trim-brush for os28005."
        },
        "Check 'Redirecting permanently...' debug message"
    ) || diag Dumper($log);

    response_status_is $resp => 301, 'status is 301';
    response_headers_include $resp =>
      [ Location => 'http://localhost/trim-brush' ],
      "Check redirect path";

    # navigation

    lives_ok { $resp = dancer_response GET => '/hand-tools' }
    "GET /hand-tools (navigation route)";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr|name="Hand Tools"|, 'found Hand Tools';
    response_content_like $resp => qr|products="([^,]+,){9}[^,]+"|,
      'found 10 products';

    lives_ok { $resp = dancer_response GET => '/hand-tools/brushes' }
    "GET /hand-tools/brushes (navigation route)";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr|name="Brushes"|, 'found Brushes';
    response_content_like $resp => qr|products="[^,]+,[^,]+"|,
      'found 2 products';
    response_content_like $resp => qr|products=".*Brush Set|,
      'found Brush Set';

    # cart

    lives_ok { $resp = dancer_response GET => '/cart' } "GET /cart";

    response_status_is $resp => 200, 'status is ok';

    # try to add canonical product which has variants to cart
    %form = ( sku => 'os28004', );
    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add Ergo Roller";

    response_status_is $resp => 302, 'status is 302';
    response_headers_include $resp =>
      [ Location => 'http://localhost/ergo-roller' ],
      "Check redirect path";

    # non-existant variant
    %form = ( sku => 'os28004', roller => 'camel', color => 'orange' );
    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add Ergo Roller camel orange";

    response_status_is $resp => 302, 'status is 302';
    response_headers_include $resp =>
      [ Location => 'http://localhost/ergo-roller' ],
      "Check redirect path";

    # now add variant
    %form = ( sku => 'os28004', roller => 'camel', color => 'black' );
    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add Ergo Roller camel black";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_subtotal="16/,
      'cart_subtotal is 16.00';
    response_content_like $resp => qr/cart_total="16/, 'cart_total is 16.00';
    response_content_like $resp => qr/cart="os28004-CAM-BLK:Ergo Roller:1:16/,
      'found qty 1 os28004-CAM-BLK in cart';

    # add again
    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add Ergo Roller camel black";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_subtotal="32/,
      'cart_subtotal is 32.00';
    response_content_like $resp => qr/cart_total="32/, 'cart_total is 32.00';
    response_content_like $resp => qr/cart="os28004-CAM-BLK:Ergo Roller:2:16/,
      'found qty 2 os28004-CAM-BLK in cart';

    # now different variant
    %form = ( sku => 'os28004', roller => 'camel', color => 'white' );
    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add Ergo Roller camel white";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_subtotal="48/,
      'cart_subtotal is 48.00';
    response_content_like $resp => qr/cart_total="48/, 'cart_total is 48.00';
    response_content_like $resp =>
      qr/cart="os28004-CAM-BLK:Ergo Roller:2:16.*?,os28004-CAM-WHT:Ergo Roller:1:16/,
      'found qty 1 os28004-CAM-WHT in cart and qty 2 BLK';

    # add non-existant product
    %form = ( sku => 'POT002', );
    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add potatoes";

    response_status_is $resp => 302, 'status is 302';
    response_headers_include $resp => [ Location => 'http://localhost/' ],
      "Check redirect path";

    # add variant using variant sku
    %form = ( sku => 'os28004-HUM-BLK', );
    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add Ergo Roller human black using variant's sku only";
    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_total="64/, 'cart_total is 64.00';

    # remove the variant
    %form = ( remove => 'os28004-HUM-BLK', );
    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart remove Ergo Roller human black using variant's sku only";
    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_total="48/, 'cart_total is 48.00';

    # GET /cart
    lives_ok { $resp = dancer_response GET => '/cart' } "GET /cart";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_subtotal="48/,
      'cart_subtotal is 48.00';
    response_content_like $resp => qr/cart_total="48/, 'cart_total is 48.00';
    response_content_like $resp =>
      qr/cart="os28004-CAM-BLK:Ergo Roller:2:16.*?,os28004-CAM-WHT:Ergo Roller:1:16/,
      'found qty 1 os28004-CAM-WHT in cart and qty 2 BLK';

    # login

    # grab session id - we want to make sure it does NOT change on login
    # but that it DOES change after logout
    # TODO: the session id does NOT currently change on login but it ought to

    lives_ok { $resp = dancer_response GET => '/sessionid' } "GET /sessionid";
    $sessionid = $resp->content;

    lives_ok { $resp = dancer_response GET => '/private' }
    "GET /private (login restricted)";

    response_redirect_location_is $resp =>
      'http://localhost/login?return_url=%2Fprivate',
      "Redirected to /login";

    lives_ok { $resp = dancer_response GET => '/login' } "GET /login";

    response_status_is $resp    => 200,            'status is ok';
    response_content_like $resp => qr/Login form/, 'got login page';

    # bad login

    read_logs;    # clear logs

    %form = (
        username => 'testuser',
        password => 'badpassword'
    );

    lives_ok {
        $resp = dancer_response( POST => '/login', { body => {%form} } );
    }
    "POST /login with bad password";

    response_status_is $resp    => 200,            'status is ok';
    response_content_like $resp => qr/Login form/, 'got login page';

    $log = pop @{&read_logs};
    cmp_deeply(
        $log,
        { level => "debug", message => "Authentication failed for testuser" },
        "Check auth failed debug message"
    ) || diag Dumper($log);

    # good login

    read_logs;    # clear logs

    %form = (
        username => 'customer1',
        password => 'c1passwd'
    );

    lives_ok {
        $resp = dancer_response( POST => '/login', { body => {%form} } );
    }
    "POST /login with good password";

    response_redirect_location_is $resp => 'http://localhost/',
      "Redirected to /";

    my $logs = read_logs;
    $log = pop @$logs;
    cmp_deeply(
        $log,
        { level => "debug", message => re('Change users_id') },
        "users_id set in debug logs"
    ) || diag Dumper($log);

    $log = pop @$logs;
    cmp_deeply(
        $log,
        { level => "debug", message => "users accepted user customer1" },
        "login successful in debug logs"
    ) || diag Dumper($log);

    lives_ok { $resp = dancer_response GET => '/sessionid' } "GET /sessionid";
    cmp_ok( $resp->content, 'eq', $sessionid,
        "Check session id has not changed" );

    # we should now be able to GET /private

    lives_ok { $resp = dancer_response GET => '/private' }
    "GET /private (login restricted)";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/Private page/, 'got private page';

    # price modifiers

    lives_ok( sub { $user = shop_user->find({username => 'customer1' }) },
            "grab customer1 fom db" );

    cmp_ok( $user->roles->count, "==", 1, "user has 1 role" );

    %form = ( sku => 'os28005', quantity => 5 );
    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add 5 Trim Brushes";
    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_subtotal="92.95"/,
      'cart_subtotal is 92.95';
    response_content_like $resp => qr/cart=.+os28005:Trim Brush:5:8.99:8.99:/,
      'found qty 5 os28005 @ 8.99 in cart';

    # authenticated user should get selling_price of 8.20
    # total is 48 for ergo rollers plus 82 for trim brushes = 130
    %form = ( sku => 'os28005', quantity => 5 );
    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add 5 Trim Brushes";
    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_subtotal="130.00"/,
      'cart_subtotal is 130.00';
    response_content_like $resp => qr/cart=.+os28005:Trim Brush:10:8.99:8.20:/,
      'found qty 10 os28005 @ 8.20 in cart';

    # add trade role to user
    lives_ok( sub { $user->add_to_roles( { name => 'trade' } ) },
        "Add user to role trade" );

    # trade user should get selling_price of 7.80
    # total is 48 for ergo rollers plus 78 for trim brushes = 126
    lives_ok( sub { $resp = dancer_response( GET => '/cart' ) }, "GET /cart" );
    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_subtotal="126.00"/,
      'cart_subtotal is 126.00';
    response_content_like $resp => qr/cart=.+os28005:Trim Brush:10:8.99:7.80:/,
      'found qty 10 os28005 @ 7.80 in cart';

    # checkout

    lives_ok { $resp = dancer_response GET => '/checkout' } "GET /checkout";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_subtotal="126.00"/,
      'cart_subtotal is 126.00';
    response_content_like $resp => qr/cart_total="126.00"/,
      'cart_total is 126.00';
    response_content_like $resp =>
      qr/cart=".*:Ergo Roller:2:16.*?,os28004-CAM-WHT:Ergo Roller:1:16/,
      'found 2 ergo roller variants at checkout';

    # logout

    lives_ok { $resp = dancer_response GET => '/logout' } "GET /logout";
    response_status_is $resp => 302, 'status is ok';

    response_redirect_location_is $resp => 'http://localhost/',
      "Redirected to /";

    lives_ok { $resp = dancer_response GET => '/sessionid' } "GET /sessionid";
    cmp_ok( $resp->content, 'ne', $sessionid, "Check session id has changed" );

    lives_ok { $resp = dancer_response GET => '/private' }
    "GET /private (login restricted)";

    response_redirect_location_is $resp =>
      'http://localhost/login?return_url=%2Fprivate',
      "Redirected to /login";

    lives_ok { $resp = dancer_response GET => '/cart' } "GET /cart";

    response_status_is $resp    => 200,               'status is ok';
    response_content_like $resp => qr/cart_total="0/, 'cart_total is 0';
    response_content_like $resp => qr/cart=""/,       'cart is empty';

};

1;
