#! perl

use strict;
use warnings;

use Test::More tests => 40;
use Interchange6::Schema;

use Dancer qw(:syntax);
use Dancer::Plugin::Interchange6;

use Data::Dumper;
use File::Temp 'tempfile';

my $filename;

(undef, $filename) = tempfile;

my $schema_class = 'Interchange6::Schema';

my $schema = $schema_class->connect( "DBI:SQLite:$filename", '', '',
        { sqlite_unicode => 1 } )
        or die "failed to connect to DBI:SQLite:$filename ($schema_class)";

$schema->deploy;

my ($cart, $item, $name, $ret, $time, $modified);

set session => 'simple';

set plugins => {DBIC => {default =>
                     {dsn => "DBI:SQLite:$filename",
                      schema_class => 'Interchange6::Schema',
                     }
                        }
               };

# Get / set cart name
$cart = cart;

$name = $cart->name;
ok($name eq 'main', "Testing default name.");

$name = $cart->name('discount');
ok($name eq 'discount', "Testing custom name.");

# Values for created / modified
$ret = $cart->created;
ok($ret > 0, "Testing cart creation time: $ret.");

$ret = $cart->last_modified;
ok($ret > 0, "Testing cart modification time: $ret.");

# Add items for testing
shop_product_class->create({sku_class => 'alphabet'});
shop_product->create({sku => 'ABC',
                      sku_class => 'alphabet'});
shop_product->create({sku => 'DEF',
                      sku_class => 'alphabet'});
shop_product->create({sku => 'KLM',
                      sku_class => 'alphabet'});
shop_product->create({sku => '123',
                      sku_class => 'alphabet'});

# Items
$cart = cart('new');
$modified = $cart->last_modified;
$item = {};
$ret = $cart->add($item);
ok(! defined($ret), "Testing empty item.");
ok($cart->last_modified == $modified, "Testing cart last modified with empty item.")
    || diag "Last modified: " . $cart->last_modified;

$item->{sku} = 'ABC';
$ret = $cart->add($item);
ok(! defined($ret), "Testing item with SKU only.");
ok($cart->last_modified == $modified, "Testing cart last modified with SKU only item.")
    || diag "Last modified: " . $cart->last_modified;

$item->{name} = 'Foobar';
$ret = $cart->add($item);
ok(! defined($ret), "Testing item with SKU and name.");
ok($cart->last_modified == $modified, "Testing cart last modified with SKU and name.")
    || diag "Last modified: " . $cart->last_modified;

$item->{price} = '42';
$ret = $cart->add($item);
ok(ref($ret) eq 'HASH', "Testing adding correct item.")
    || diag "Cart error: $cart->error";
ok($cart->last_modified > 0, "Check for update on last modified value.");
$ret = $cart->items();
ok(@$ret == 1, "Check number of items in the cart is one")
    || diag "Items: $ret";

# Combine items
$item = {sku => 'ABC', name => 'Foobar', price => 5};
$ret = $cart->add($item);
ok(ref($ret) eq 'HASH', $cart->error);

$ret = $cart->items;
ok(@$ret == 1, "Items: $ret");

$item = {sku => 'DEF', name => 'Foobar', price => 5};
$ret = $cart->add($item);
ok(ref($ret) eq 'HASH', $cart->error);

$ret = $cart->items;
ok(@$ret == 2, "Items: $ret");

# Update item(s)
$cart->update(ABC => 2);

$ret = $cart->count;
ok($ret == 2, "Testing count after update of ABC.")
    || diag "Count: $ret";

$ret = $cart->quantity;
ok($ret == 3, "Testing quantity after update of ABC.")
   || diag "Quantity: $ret";

$cart->update(ABC => 1, DEF => 4);

$ret = $cart->count;
ok($ret == 2, "Testing count after update of ABC and DEF.")
   || diag "Count: $ret";

$ret = $cart->quantity;
ok($ret == 5, "Testing quantity after update of ABC and DEF.")
   || diag "Quantity: $ret";

$cart->update(ABC => 0);

$ret = $cart->count;
ok($ret == 1, "Testing count after update of ABC to 0.")
   || diag "Count: $ret";

$ret = $cart->quantity;
ok($ret == 4, "Testing quantity after update of ABC to 0.")
   || diag "Quantity: $ret";

# Cart removal
hook before_cart_remove => sub {
    my ($cart, $item) = @_;

    if ($item->{sku} eq '123') {
        $item->{error} = 'Item not removed due to hook.';
    }
};

$item = {sku => 'DEF', name => 'Foobar', price => 5};
$ret = $cart->add($item);

$item = {sku => '123', name => 'Foobar', price => 5};
$ret = $cart->add($item);

$ret = $cart->remove('123');
ok($cart->error eq 'Item not removed due to hook.',
   "Test removal prevented by hook")
   || diag "Cart Error: " . $cart->error;

$ret = $cart->items;
ok(@$ret == 2, "Items: $ret");

$ret = $cart->remove('DEF');
ok(defined($ret), "Item DEF removed from cart.");

$ret = $cart->items;
ok(@$ret == 1, "List of items after removal of DEF")
    || diag "Items: " . Dumper($ret);


# Calculating total
$cart->clear;
$ret = $cart->total;
ok($ret == 0, "Total: $ret");

$item = {sku => 'GHI', name => 'Foobar', price => 2.22, quantity => 3};
$ret = $cart->add($item);
ok(ref($ret) eq 'HASH', "Adding item GHI.")
    || diag "Cart error: " . $cart->error;

$ret = $cart->total;
ok($ret == 6.66, "Cart total for 3 pieces of GHI.")
    || diag "Total: $ret";

$item = {sku => 'KLM', name => 'Foobar', price => 3.34, quantity => 1};
$ret = $cart->add($item);
ok(ref($ret) eq 'HASH', "Adding item KLM.")
    || diag "Cart error: " . $cart->error;

$ret = $cart->total;
ok($ret == 10, "Cart total for GHI and KLM")
    || diag "Total: $ret";

# Hooks
hook 'before_cart_add' => sub {
    my ($cart, $item) = @_;

    if ($item->{price} > 3) {
        $item->{error} = 'Test error';
    }
};

$cart->clear;
$item = {sku => 'KLM', name => 'Foobar', price => 3.34, quantity => 1};
$ret = $cart->add($item);

$ret = $cart->items;
ok(@$ret == 0, "Cart after adding KLM")
    || diag "Items: " . Dumper($ret);

ok($cart->error eq 'Test error', "Checking cart error")
    || diag "Cart error: " . $cart->error;

# Seed
$cart = cart;
$cart->seed([{sku => 'ABC', name => 'ABC', price => 2, quantity => 1},
	     {sku => 'ABCD', name => 'ABCD', price => 3, quantity => 2},
	    ]);

$ret = $cart->items;
ok(@$ret == 2, "Items: $ret");

$ret = $cart->count;
ok($ret == 2, "Count: $ret");

$ret = $cart->quantity;
ok($ret == 3, "Quantity: $ret");

$ret = $cart->total;
ok($ret == 8, "Total: $ret");

$cart->clear;

$ret = $cart->count;
ok($ret == 0, "Count: $ret");

$ret = $cart->quantity;
ok($ret == 0, "Quantity: $ret");
