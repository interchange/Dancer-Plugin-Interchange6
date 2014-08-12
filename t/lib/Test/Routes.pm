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

    my ( $resp, $sessionid, %form, $log, @logs );

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

    #lives_ok { $schema->deploy } "Deploy schema";

    use TestApp;
    use Dancer::Test;

    # add some stuff to db

    lives_ok(
        sub {
            shop_product->create(
                {
                    sku               => 'BAN001',
                    name              => 'bananas',
                    price             => 5.34,
                    uri               => 'kilo-of-bananas',
                    short_description => 'Fresh bananas from Colombia',
                    description       => 'The best bananas money can buy',
                    active            => 1,
                }
            );
        },
        "create product BAN001"
    );

    lives_ok(
        sub {
            shop_product->create(
                {
                    sku               => 'ORA001',
                    name              => 'oranges',
                    price             => 6.45,
                    uri               => 'kilo-of-oranges',
                    short_description => 'California oranges',
                    description       => 'Organic California navel oranges',
                    active            => 1,
                }
            );
        },
        "create product ORA001"
    );
    lives_ok(
        sub {
            shop_product->create(
                {
                    sku               => 'CAR002',
                    name              => 'carrots',
                    price             => 3.23,
                    uri               => 'kilo-of-carrots',
                    short_description => 'Local carrots',
                    description       => 'Carrots from our local organic farm',
                    active            => 1,
                }
            );
        },
        "create product CAR002"
    );

    lives_ok(
        sub {
            shop_product->create(
                {
                    sku               => 'POT002',
                    name              => 'potatoes',
                    price             => 10.15,
                    uri               => 'kilo-of-potatoes',
                    short_description => 'Maltese potatoes',
                    description       => 'The best new potatoes in the world',
                    active            => 1,
                }
            );
        },
        "create product POT002"
    );

    my $nav_fruit;
    lives_ok(
        sub {
            $nav_fruit = shop_navigation->create(
                {
                    uri       => 'fruit',
                    type      => 'nav',
                    scope     => 'main-menu',
                    name      => 'Fruit',
                    parent_id => undef,
                    active    => 1,
                }
            );
        },
        "create nav fruit"
    );

    my $nav_veg;
    lives_ok(
        sub {
            $nav_veg = shop_navigation->create(
                {
                    uri       => 'vegetables',
                    type      => 'nav',
                    scope     => 'main-menu',
                    name      => 'Vegetables',
                    parent_id => undef,
                    active    => 1,
                }
            );
        },
        "create nav vegetables"
    );

    lives_ok(
        sub {
            $schema->resultset('NavigationProduct')
              ->create(
                { sku => 'BAN001', navigation_id => $nav_fruit->navigation_id }
              );
        },
        "create navigation_product BAN001"
    );

    lives_ok(
        sub {
            $schema->resultset('NavigationProduct')
              ->create(
                { sku => 'ORA001', navigation_id => $nav_fruit->navigation_id }
              );
        },
        "create navigation_product ORA001"
    );

    lives_ok(
        sub {
            $schema->resultset('NavigationProduct')
              ->create(
                { sku => 'CAR002', navigation_id => $nav_veg->navigation_id } );
        },
        "create navigation_product CAR002"
    );

    lives_ok(
        sub {
            $schema->resultset('NavigationProduct')
              ->create(
                { sku => 'POT002', navigation_id => $nav_veg->navigation_id } );
        },
        "create navigation_product POT002"
    );

    # test test test

    # product

    lives_ok { $resp = dancer_response GET => '/kilo-of-bananas' }
    "GET /kilo-of-bananas (product route)";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr|name="bananas"|, 'found bananas';

    lives_ok { $resp = dancer_response GET => '/kilo-of-potatoes' }
    "GET /kilo-of-potatoes (product route)";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr|name="potatoes"|, 'found potatoes';

    lives_ok { $resp = dancer_response GET => '/CAR002' }
    "GET /CAR002 (product route)";

    $log = pop @{&read_logs};
    cmp_deeply(
        $log,
        {
            level => "debug",
            message =>
"Redirecting permanently to product uri kilo-of-carrots for CAR002."
        },
        "Check auth failed debug message"
    ) || diag Dumper($log);

    response_status_is $resp => 301, 'status is 301';
    response_headers_include $resp =>
      [ Location => 'http://localhost/kilo-of-carrots' ],
      "Check redirect path";

    # navigation

    lives_ok { $resp = dancer_response GET => '/fruit' }
    "GET /fruit (navigation route)";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr|name="Fruit"|, 'found Fruit';
    response_content_like $resp => qr|products="bananas,oranges"|,
      'found bananas,oranges';

    lives_ok { $resp = dancer_response GET => '/vegetables' }
    "GET /vegetables (navigation route)";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr|name="Vegetables"|, 'found Vegetables';
    response_content_like $resp => qr|products="carrots,potatoes"|,
      'found carrots,potatoes';

    # cart

    lives_ok { $resp = dancer_response GET => '/cart' } "GET /cart";

    response_status_is $resp => 200, 'status is ok';

    %form = ( sku => 'BAN001', );

    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add bananas";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_subtotal="5.34"/,
      'cart_subtotal is 5.34';
    response_content_like $resp => qr/cart_total="5.34"/, 'cart_total is 5.34';
    response_content_like $resp => qr/cart="BAN001:bananas:1:5.34"/,
      'found qty 1 bananas in cart';

    %form = ( sku => 'POT002', );

    lives_ok { $resp = dancer_response( POST => '/cart', { body => {%form} } ) }
    "POST /cart add potatoes";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_total="15.49"/,
      'cart_total is 15.49';
    response_content_like $resp =>
      qr/cart="BAN001:bananas:1:5.34,POT002:potatoes:1:10.15"/,
      'found bananas & potatoes in cart';

    lives_ok { $resp = dancer_response GET => '/cart' } "GET /cart";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_total="15.49"/,
      'cart_total is 15.49';
    response_content_like $resp =>
      qr/cart="BAN001:bananas:1:5.34,POT002:potatoes:1:10.15"/,
      'found bananas & potatoes in cart';

    # login

    # grab session id - we want to make sure it does NOT change on login
    # but that it DOES change after logout

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
        username => 'testuser',
        password => 'mypassword'
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
        { level => "debug", message => "users accepted user testuser" },
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

    # checkout

    lives_ok { $resp = dancer_response GET => '/checkout' } "GET /checkout";

    response_status_is $resp => 200, 'status is ok';
    response_content_like $resp => qr/cart_subtotal="15.49"/,
      'cart_subtotal is 15.49';
    response_content_like $resp => qr/cart_total="15.49"/,
      'cart_total is 15.49';
    response_content_like $resp =>
      qr/cart="BAN001:bananas:1:5.34,POT002:potatoes:1:10.15"/,
      'found bananas & potatoes at checkout';

    # logout

    read_logs;    # clear logs
    lives_ok { $resp = dancer_response GET => '/logout' } "GET /logout";
    response_redirect_location_is $resp => 'http://localhost/',
      "Redirected to /";

    $log = pop @{&read_logs};
    cmp_deeply(
        $log,
        { level => "debug", message => re('Change sessions_id.+undef') },
        "Check sessions_id undef debug message"
    ) || diag Dumper($log);

    lives_ok { $resp = dancer_response GET => '/sessionid' } "GET /sessionid";
    cmp_ok( $resp->content, 'ne', $sessionid, "Check session id has changed" );

    lives_ok { $resp = dancer_response GET => '/private' }
    "GET /private (login restricted)";

    response_redirect_location_is $resp =>
      'http://localhost/login?return_url=%2Fprivate',
      "Redirected to /login";

    lives_ok { $resp = dancer_response GET => '/cart' } "GET /cart";

    response_status_is $resp    => 200,                'status is ok';
    response_content_like $resp => qr/cart_total="0"/, 'cart_total is 0';
    response_content_like $resp => qr/cart=""/,        'cart is empty';

};

1;
