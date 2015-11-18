package Test::Cart;

use Test::Most;

use Dancer qw/debug hook setting var/;
use Dancer::Logger::Capture;
use Dancer::Plugin::Interchange6;
use DateTime;

use namespace::clean;
use Test::Roo::Role;

test 'cart tests' => sub {
    my $self = shift;

    diag "Test::Cart";

    my $dt_now = DateTime->now;
    my $trap   = Dancer::Logger::Capture->trap;

    my ( $cart, $product, $name, $ret, $time, $i, $log );

    my $schema = shop_schema;

    set log    => 'debug';
    set logger => 'capture';

    # Get / set cart name
    $cart = cart;

    cmp_ok( $schema->resultset('Cart')->count,
        '==', 1, "1 cart in the database" );
    cmp_ok( $cart->id, '==', 1, "cart id is 1" );

    $log = pop @{$trap->read};
    cmp_deeply(
        $log,
        { level => "debug", message => "New cart 1 main." },
        "Check cart BUILDARGS debug message"
    ) or diag Dumper($log);

    $name = $cart->name;
    ok( $name eq 'main', "Testing default name." );

    $name = $cart->rename('discount');
    ok( $name eq 'discount', "Testing custom name." );

    # Products
    $cart     = cart('new');
    $product = {};

    cmp_ok( $cart->id, '==', 2, "cart id is 2" );

    $log = pop @{$trap->read};
    cmp_deeply(
        $log,
        { level => "debug", message => "New cart 2 new." },
        "Check cart BUILDARGS debug message"
    ) or diag Dumper($log);

    $ret = $schema->resultset('Cart')->search( {}, { order_by => 'carts_id' } );
    cmp_ok( $ret->count, '==', 2, "2 carts in the database" );

    $i = 0;
    while ( my $rec = $ret->next ) {
        cmp_ok( $rec->carts_id, 'eq', ++$i, "cart id is: " . $i );
        if ( $i == 1 ) {
            cmp_ok( $rec->name, 'eq', 'discount', "Cart 1 name is discount" );
        }
        else {
            cmp_ok( $rec->name, 'eq', 'new', "Cart 2 name is new" );
        }
    }

    throws_ok { $cart->add() }
    qr/Attempt to add product to cart without sku failed/,
      "add with no args";

    throws_ok { $cart->add(undef) }
    qr/Attempt to add product to cart without sku failed/,
      "add with undef arg";

    throws_ok { $cart->add('this sku does not exist') }
    qr/Product with sku .+ does not exist/, "add sku that does not exist in db";

    # variant
    lives_ok { $ret = $cart->add('os28085-6') } "add variant os28085-6";
    isa_ok( $ret->[0], 'Interchange6::Cart::Product' );
    cmp_ok( $ret->[0]->sku, 'eq', 'os28085-6', "Check sku" );
    cmp_ok( $ret->[0]->canonical_sku, 'eq', 'os28085', "Check canonical_sku" );
    ok( $ret->[0]->is_variant, "product is a variant" );
    ok( !$ret->[0]->is_canonical, "product is not canonical" );
    lives_ok( sub { $cart->clear }, "clear the cart" );
    cmp_ok( $cart->count, '==', 0,
        "Check number of products in the cart is 0" );

    # add os28005 as scalar
    lives_ok { $ret = $cart->add('os28005') } "add single scalar sku";
    isa_ok( $ret->[0], 'Interchange6::Cart::Product' );
    cmp_ok( $ret->[0]->sku, 'eq', 'os28005', "Check sku of returned product" );
    cmp_ok( $ret->[0]->name, 'eq', 'Trim Brush',
        "Check name of returned product" );
    cmp_ok( sprintf( "%.2f", $ret->[0]->price ),
        '==', 8.99, "Check price of returned product" );
    cmp_ok( sprintf( "%.2f", $ret->[0]->selling_price ),
        '==', 8.99, "Check price of returned product" );
    cmp_ok( $ret->[0]->quantity, '==', 1,
        "Check quantity of returned product is 1" );
    ok( $ret->[0]->is_canonical, "product is canonical" );
    ok( !$ret->[0]->is_variant, "product is not a variant" );
    cmp_ok( $cart->count, '==', 1,
        "Check number of products in the cart is 1" );
    cmp_ok( sprintf( "%.2f", $cart->subtotal ),
        '==', 8.99, "cart subtotal is 8.99" );
    cmp_ok( sprintf( "%.2f", $cart->total ),
        '==', 8.99, "cart total is 8.99" );

    # add os28005 again as hashref
    lives_ok { $ret = $cart->add({ sku => 'os28005'}) }
    "add single hashref without quantity of same product";
    isa_ok( $ret->[0], 'Interchange6::Cart::Product' );
    cmp_ok( $ret->[0]->sku, 'eq', 'os28005', "Check sku of returned product" );
    cmp_ok( $ret->[0]->name, 'eq', 'Trim Brush',
        "Check name of returned product" );
    cmp_ok( sprintf( "%.2f", $ret->[0]->price ),
        '==', 8.99, "Check price of returned product" );
    cmp_ok( sprintf( "%.2f", $ret->[0]->selling_price ),
        '==', 8.99, "Check price of returned product" );
    cmp_ok( $ret->[0]->quantity, '==', 2,
        "Check quantity of returned product is 2" );
    cmp_ok( $cart->count, '==', 1,
        "Check number of products in the cart is 1" );
    cmp_ok( sprintf( "%.2f", $cart->subtotal ),
        '==', 17.98, "cart subtotal is 17.98" );
    cmp_ok( sprintf( "%.2f", $cart->total ),
        '==', 17.98, "cart total is 17.98" );

    # add qty 8 of os28005 as hashref so qty 10 PriceModifier for anonymous
    # should now apply
    lives_ok { $ret = $cart->add( { sku => 'os28005', quantity => 8 } ) }
    "add single hashref with quantity 8 of same product";
    isa_ok( $ret->[0], 'Interchange6::Cart::Product' );
    cmp_ok( $ret->[0]->sku, 'eq', 'os28005', "Check sku of returned product" );
    cmp_ok( $ret->[0]->name, 'eq', 'Trim Brush',
        "Check name of returned product" );
    cmp_ok( sprintf( "%.2f", $ret->[0]->price ),
        '==', 8.99, "Check price of returned product" );
    cmp_ok( sprintf( "%.2f", $ret->[0]->selling_price ),
        '==', 8.49, "Check price of returned product" );
    cmp_ok( $ret->[0]->quantity, '==', 10,
        "Check quantity of returned product is 10" );
    cmp_ok( sprintf( "%.2f", $ret->[0]->total), '==', 84.90,
        "Check total of returned product is 84.90" );
    cmp_ok( $cart->count, '==', 1,
        "Check number of products in the cart is 1" );
    cmp_ok( sprintf( "%.2f", $cart->subtotal ),
        '==', 84.90, "cart subtotal is 84.90" );
    cmp_ok( sprintf( "%.2f", $cart->total ),
        '==', 84.90, "cart total is 84.90" );

    # add qty 2 of os28006
    lives_ok { $ret = $cart->add( { sku => 'os28006', quantity => 2 } ) }
    "add single hashref with quantity 2 of os28006";
    isa_ok( $ret->[0], 'Interchange6::Cart::Product' );
    cmp_ok( $ret->[0]->sku, 'eq', 'os28006', "Check sku of returned product" );
    cmp_ok( $ret->[0]->name, 'eq', 'Painters Brush Set',
        "Check name of returned product" );
    cmp_ok( sprintf( "%.2f", $ret->[0]->price ),
        '==', 29.99, "Check price of returned product" );
    cmp_ok( sprintf( "%.2f", $ret->[0]->selling_price ),
        '==', 24.99, "Check selling_price of returned product" );
    cmp_ok( $ret->[0]->quantity, '==', 2,
        "Check quantity of returned product is 2" );
    cmp_ok( sprintf( "%.2f", $ret->[0]->total), '==', 49.98,
        "Check total of returned product is 49.98" );
    cmp_ok( $cart->count, '==', 2,
        "Check number of products in the cart is 2" );
    cmp_ok( sprintf( "%.2f", $cart->subtotal ),
        '==', 134.88, "cart subtotal is 134.88" );
    cmp_ok( sprintf( "%.2f", $cart->total ),
        '==', 134.88, "cart total is 134.88" );

    # Update product(s)

    lives_ok { $cart->update( os28006 => 5 ) }
    "Change quantity of os28006 to 5";
    cmp_ok( $cart->count, '==', 2, "cart count after update of os28006." );
    cmp_ok( $cart->quantity, '==', 15,
        "cart quantity after update of os28006." );
    cmp_ok( sprintf( "%.2f", $cart->subtotal ),
        '==', 209.85, "cart subtotal is 209.85" );
    cmp_ok( sprintf( "%.2f", $cart->total ),
        '==', 209.85, "cart total is 209.85" );

    lives_ok { $cart->update( os28005 => 20, os28006 => 4 ) }
    "Update qty of os28005 and os28006";
    cmp_ok( $cart->count, '==', 2,
        "cart count after update of os28005 and os28006." );
    cmp_ok( $cart->quantity, '==', 24,
        "cart quantity after update of os28005 and os28006." );
    cmp_ok( sprintf( "%.2f", $cart->subtotal ),
        '==', 269.76, "cart subtotal is 269.76" );
    cmp_ok( sprintf( "%.2f", $cart->total ),
        '==', 269.76, "cart total is 269.76" );

    # product removal

    lives_ok { $cart->update( os28006 => 0 ) }
    "Update quantity of os28006 to 0.";
    cmp_ok( $cart->count, '==', 1, "cart count after update of os28006 to 0." );
    cmp_ok( $cart->quantity, '==', 20,
        "cart quantity after update of os28006 to 0." );
    cmp_ok( sprintf( "%.2f", $cart->total ),
        '==', 169.80, "cart total is 169.80" );

    lives_ok(
        sub {
            hook before_cart_remove => sub {
                my ( $cart, $sku ) = @_;

                if ( $sku eq 'os28005' ) {
                    die 'Product not removed due to hook.';
                }
              }
        },
        "Add before_cart_remove hook"
    );

    throws_ok { $cart->remove('os28005') }
        qr/Product not removed due to hook/,
        "fail to remove product os28005 using remove due to hook"
    ;

    throws_ok(
        sub { $cart->update(os28005 => 0) },
        qr/Product not removed due to hook/,
        "fail to remove product os28005 using update due to hook"
    );

    cmp_ok( $cart->count, '==', 1, "cart count is still 1" );
    cmp_ok( $cart->quantity, '==', 20, "cart quantity is still 20" );
    cmp_ok( sprintf( "%.2f", $cart->total ),
        '==', 169.80, "cart total is still 169.80" );

    # Hooks

    lives_ok {
        hook 'before_cart_add' => sub {
            my ( $cart, $products ) = @_;
            foreach my $product (@$products) {
                if ( $product->{sku} eq 'os28007' ) {
                    die 'Test error';
                }
            }
        }
    }
    "hook to prevent add of sku os28007";

    lives_ok { $cart->clear } "Clear cart";
    cmp_ok( $cart->count, '==', 0, "cart count is 0" );
    cmp_ok( $cart->quantity, '==', 0, "cart quantity is 0" );
    cmp_ok( $cart->subtotal, '==', 0, "cart subtotal is 0" );
    cmp_ok( $cart->total, '==', 0, "cart total is 0" );

    throws_ok( sub { $ret = $cart->add('os28007') },
        qr/Test error/, "fail add product with sku os28007 due to hook" );

    cmp_ok( $cart->count, '==', 0, "cart is still empty" );
    cmp_ok( $cart->id,    '==', 2, "cart id is still 2" );

    lives_ok {
        hook 'before_cart_add' => sub {
            my ( $cart, $products ) = @_;
            foreach my $product (@$products) {
                if ( $product->{price} > 20 ) {
                    die 'Test error';
                }
            }
        }
    }
    "hook to prevent add of product with price > 20";

    lives_ok {
        hook 'before_cart_add' => sub {
            my ( $cart, $products ) = @_;
            debug "added to cart id "
              . $cart->id
              . " these skus: "
              . join( ", ", map { $_->{sku} } @$products );
        }
    }
    "hook to debug log skus of added products";

    throws_ok( sub { $ret = $cart->add('os28062') },
        qr/Test error/, "fail add product with sku os28062 due to price hook" );
    cmp_ok( $cart->count, '==', 0, "cart count is 0" );

    $log = pop @{$trap->read};
    ok( !defined $log, "nothing in the logs" );

    lives_ok( sub { $ret = $cart->add('os28064') },
        "add product with sku os28064 not prevented by price hook" );
    cmp_ok( $cart->count, '==', 1, "cart count is 1" );

    $log = pop @{$trap->read};
    cmp_deeply(
        $log,
        {
            level   => "debug",
            message => "added to cart id 2 these skus: os28064"
        },
        "debug message from hook found in logs"
    ) or diag Dumper($log);

    # Seed

    lives_ok( sub { var ic6_carts => undef },
        "undef var ic6_carts so new cart will not come from cache" );

    lives_ok { $cart = cart } "Create a new cart";
    cmp_ok( $cart->id, '==', 3, "cart id is 3" );

    $log = $trap->read;
    cmp_deeply(
        $log,
        [
            { level => "debug", message => "carts_var_name: ic6_carts" },
            { level => "debug", message => "New cart 3 main." },
        ],
        "Check cart BUILDARGS debug message"
    ) or diag Dumper($log);

    lives_ok { $cart = cart } "calling cart again should return same cart";
    cmp_ok( $cart->id, '==', 3, "cart id is 3" );

    $ret = $schema->resultset('Cart')->search( {}, { order_by => 'carts_id' } );
    cmp_ok( $ret->count, '==', 3, "3 carts in the database" );

    $i = 0;
    while ( my $rec = $ret->next ) {
        cmp_ok( $rec->carts_id, 'eq', ++$i, "cart id is: " . $i );
        if ( $i == 1 ) {
            cmp_ok( $rec->name, 'eq', 'discount', "Cart 1 name is discount" );
        }
        elsif ( $i == 2 ) {
            cmp_ok( $rec->name, 'eq', 'new', "Cart 2 name is new" );
        }
        else {
            cmp_ok( $rec->name, 'eq', 'main', "Cart 3 name is main" );
        }
    }

    lives_ok {
        $cart->seed(
            [
                { sku => 'ABC',  name => 'ABC',  price => 2, quantity => 1 },
                { sku => 'ABCD', name => 'ABCD', price => 3, quantity => 2 },
            ]
        );
    }
    "Seed cart";

    cmp_ok( $cart->count, '==', 2, "2 products in cart" );

    cmp_ok( $cart->quantity, '==', 3, "Quantity is 3" );

    cmp_ok( $cart->total, '==', 8, "Total is 8" );

    lives_ok { $cart->clear } "Clear cart";

    cmp_ok( $cart->count, '==', 0, "0 products in cart" );

    cmp_ok( $cart->quantity, '==', 0, "Quantity is 0" );

    lives_ok( sub { $schema->resultset('Cart')->delete_all },
        "delete all carts" );

    cmp_ok( $schema->resultset('Cart')->count, '==', 0, "0 Cart rows" );

    # plugin setting carts_var_name
    
    setting('plugins')->{Interchange6}->{carts_var_name} = "foobar";

    $trap->read;

    lives_ok { $cart = cart } "Create a new cart";

    $log = $trap->read;
    cmp_deeply(
        $log,
        [
            { level => "debug", message => "carts_var_name: foobar" },
            { level => "debug", message => re('New cart \d+ main') },
        ],
        "Check cart BUILDARGS debug message"
    ) or diag Dumper($log);

    # subclassed cart

    setting('plugins')->{Interchange6}->{carts_var_name} = "ic6_carts";
    setting('plugins')->{Interchange6}->{cart_class} = "TestCart";

    lives_ok( sub { var ic6_carts => undef },
        "undef var ic6_carts so new cart will not come from cache" );

    lives_ok( sub { $cart = cart("test") }, "get new TestCart with name test" );

    isa_ok( $cart, 'TestCart' );
    isa_ok( $cart, 'Interchange6::Cart' );
    ok( $cart->can('add'), "has add method" );
    ok( $cart->can('test_method'), "has test_method" );
    cmp_ok( $cart->name, 'eq', 'test', "name is test" );
    ok( ! defined $cart->test_attribute, "test_attribute is undef" );
    lives_ok( sub { $cart->test_attribute("foobar") }, "set test_attribute" );
    cmp_ok( $cart->test_attribute, 'eq', 'foobar', "has test_attribute" );

};

1;
