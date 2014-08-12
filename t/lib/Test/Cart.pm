package Test::Cart;

use 5.014;

use Test::Most;
use Test::Roo::Role;
use Interchange6::Schema;
use Dancer qw(:tests !after);
use Dancer::Plugin::Interchange6;
use Dancer::Plugin::DBIC;
use Dancer::Test;

use Data::Dumper;
use DateTime;

test 'cart tests' => sub {
    my $self = shift;

    diag "Test::Cart";

    my $dt_now = DateTime->now;

    my ( $cart, $product, $name, $ret, $time, $modified, $i, $log );

    my $schema = schema;

    set log    => 'debug';
    set logger => 'capture';

    # Get / set cart name
    $cart = cart;

    cmp_ok( $schema->resultset('Cart')->count,
        '==', 1, "1 cart in the database" );
    cmp_ok( $cart->id, '==', 1, "cart id is 1" );

    $log = pop read_logs;
    cmp_deeply(
        $log,
        { level => "debug", message => "New cart 1 main." },
        "Check cart BUILDARGS debug message"
    ) or diag Dumper($log);

    $name = $cart->name;
    ok( $name eq 'main', "Testing default name." );

    $name = $cart->name('discount');
    ok( $name eq 'discount', "Testing custom name." );

    # Values for created / modified
    $ret = $cart->created;
    ok( $ret >= $dt_now, "Testing cart creation time: $ret." );

    $ret = $cart->last_modified;
    ok( $ret >= $dt_now, "Testing cart modification time: $ret." );

    # Add products for testing
    shop_product->create( { sku => 'ABC', name => 'name', description => '' } );
    shop_product->create( { sku => 'DEF', name => 'name', description => '' } );
    shop_product->create( { sku => 'KLM', name => 'name', description => '' } );
    shop_product->create( { sku => '123', name => 'name', description => '' } );

    # Products
    $cart     = cart('new');
    $modified = $cart->last_modified;
    sleep 1;    # so we can check last_modified
    $product = {};

    cmp_ok( $cart->id, '==', 2, "cart id is 2" );

    $log = pop read_logs;
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

    throws_ok { $cart->add($product) } qr/Missing required arg/,
      "add empty product";
    ok( $cart->last_modified == $modified,
        "Testing cart last modified with empty product." )
      || diag "Last modified: " . $cart->last_modified;

    $product->{sku} = 'ABC';
    throws_ok { $cart->add($product) } qr/Missing required arg/,
      "Tetsing product with SKU only";

    ok( $cart->last_modified == $modified,
        "Testing cart last modified with SKU only product." )
      || diag "Last modified: " . $cart->last_modified;

    $product->{name} = 'Foobar';
    throws_ok { $cart->add($product) } qr/Missing required arg/,
      "Testing product with SKU and name.";

    ok( $cart->last_modified == $modified,
        "Testing cart last modified with SKU and name." )
      || diag "Last modified: " . $cart->last_modified;

    $product->{price} = '42';
    lives_ok { $ret = $cart->add($product) } "Testing adding correct product."
      || diag "Cart error: $cart->error";
    isa_ok( $ret, 'Interchange6::Cart::Product' );
    cmp_ok( $ret->sku,   'eq', 'ABC',    "Check sku of returned product" );
    cmp_ok( $ret->name,  'eq', 'Foobar', "Check name of returned product" );
    cmp_ok( $ret->price, '==', 42,       "Check price of returned product" );
    cmp_ok( $ret->quantity, '==', 1, "Check quantity of returned product" );

    cmp_ok( $cart->last_modified, '>=', $modified,
        "Check for update on last modified value." );
    cmp_ok( $cart->count, '==', 1,
        "Check number of products in the cart is 1" );

    # Combine products
    $product = { sku => 'ABC', name => 'Foobar', price => 5 };
    lives_ok { $ret = $cart->add($product) }
    "Add another product to cart with same SKU";
    isa_ok( $ret, 'Interchange6::Cart::Product' );
    cmp_ok( $cart->count, '==', 1,
        "Check number of products in the cart is 1" );

    $product = { sku => 'DEF', name => 'Foobar', price => 5 };
    lives_ok { $ret = $cart->add($product) } "Add a different product to cart";
    isa_ok( $ret, 'Interchange6::Cart::Product' );
    cmp_ok( $cart->count, '==', 2,
        "Check number of products in the cart is 2" );

    # Update product(s)
    lives_ok { $cart->update( ABC => 2 ) } "Change quantity of ABC to 2";
    cmp_ok( $cart->count, '==', 2, "Testing count after update of ABC." );

    cmp_ok( $cart->quantity, '==', 3, "Testing quantity after update of ABC." );

    lives_ok { $cart->update( ABC => 1, DEF => 4 ) }
    "Update qty of ABC and DEF";
    cmp_ok( $cart->count, '==', 2,
        "Testing count after update of ABC and DEF." );
    cmp_ok( $cart->quantity, '==', 5,
        "Testing quantity after update of ABC and DEF." );

    lives_ok { $cart->update( ABC => 0 ) } "Update quantity of ABC to 0.";
    cmp_ok( $cart->count, '==', 1, "Testing count after update of ABC to 0." );
    cmp_ok( $cart->quantity, '==', 4,
        "Testing quantity after update of ABC to 0." );

    # Cart removal
    lives_ok(
        sub {
            hook before_cart_remove => sub {
                my ( $cart, $product ) = @_;

                if ( $product->sku eq '123' ) {
                    $cart->set_error('Product not removed due to hook.');
                }
              }
        },
        "Add before_cart_remove hook"
    );

    $product = { sku => 'DEF', name => 'Foobar', price => 5 };
    lives_ok { $cart->add($product) } "Add product DEF";

    $product = { sku => '123', name => 'Foobar', price => 5 };
    lives_ok { $cart->add($product) } "Add product 123";

    cmp_ok( $cart->count, '==', 2, "Testing count is 2." );

    lives_ok { $cart->remove('123') } "Try to remove product 123";
    cmp_ok(
        $cart->error, 'eq',
        'Product not removed due to hook.',
        "Test removal prevented by hook"
    );

    cmp_ok( $cart->count, '==', 2, "Testing count is still 2." );

    lives_ok { $cart->remove('DEF') } "Try to remove product DEF";

    cmp_ok( $cart->count, '==', 1, "Testing count after removal of DEF." );

    # Calculating total
    lives_ok { $cart->clear } "Clear cart";
    cmp_ok( $cart->total, '==', 0, "Cart total is 0" );

    $product = { sku => 'GHI', name => 'Foobar', price => 2.22, quantity => 3 };
    lives_ok { $ret = $cart->add($product) } "Add product GHI";
    isa_ok( $ret, 'Interchange6::Cart::Product' );

    cmp_ok( $cart->total, '==', 6.66, "Cart total for 3 pieces of GHI." );

    $product = { sku => 'KLM', name => 'Foobar', price => 3.34, quantity => 1 };
    lives_ok { $ret = $cart->add($product) } "Add product KLM";
    isa_ok( $ret, 'Interchange6::Cart::Product' );

    cmp_ok( $cart->total, '==', 10, "Cart total for GHI and KLM" );

    # Hooks
    lives_ok {
        hook 'before_cart_add' => sub {
            my ( $cart, $product ) = @_;

            if ( $product->sku eq 'KLM' ) {
                $cart->set_error('Test error');
            }
          }
    }
    "Add price > 3 hook";

    lives_ok { $cart->clear } "Clear cart";

    $product = { sku => 'KLM', name => 'Foobar', price => 3.34, quantity => 1 };
    lives_ok { $ret = $cart->add($product) } "Add product with proce 3.34";

    cmp_ok( $cart->count, '==', 0, "Cart after adding KLM is empty" );

    cmp_ok( $cart->error, 'eq', 'Test error', "Checking cart error" );
    cmp_ok( $cart->id,    '==', 2,            "cart id is 2" );

    lives_ok {
        hook 'before_cart_add' => sub {
            my ( $cart, $product ) = @_;
          }
    }
    "Add sku eq KLM hook";

    # Seed

    lives_ok { $cart = cart } "Create a new cart";
    cmp_ok( $cart->id, '==', 3, "cart id is 3" );

    $log = pop read_logs;
    cmp_deeply(
        $log,
        { level => "debug", message => "New cart 3 main." },
        "Check cart BUILDARGS debug message"
    ) or diag Dumper($log);

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

};

1;
