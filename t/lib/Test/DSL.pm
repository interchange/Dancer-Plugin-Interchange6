package Test::DSL;

use Test::Exception;
use Test::More;
use Test::Roo::Role;

use Dancer::Plugin::Interchange6;

test 'shop_schema' => sub {

    diag "Test::DSL";

    my $schema;

    lives_ok { $schema = shop_schema } "shop_schema lives";

    isa_ok $schema, "DBIx::Class::Schema";

    lives_ok { $schema = shop_schema('shop2') } "shop_schema('shop2') lives";

    isa_ok $schema, "DBIx::Class::Schema";

    throws_ok { $schema = shop_schema('bad') }
    qr/The schema bad is not configured/,
      "shop_schema('bad') dies";
};

test 'shop_cart' => sub {

    my $cart;

    lives_ok { $cart = shop_cart } "shop_cart lives";

    isa_ok $cart, "Dancer::Plugin::Interchange6::Cart";

    cmp_ok $cart->name, 'eq', 'main', 'name is main';

    lives_ok { $cart = shop_cart('test') } "shop_cart('test') lives";

    isa_ok $cart, "Dancer::Plugin::Interchange6::Cart";

    cmp_ok $cart->name, 'eq', 'test', 'name is test';

    lives_ok { $cart = cart } "cart lives";

    isa_ok $cart, "Dancer::Plugin::Interchange6::Cart";

    cmp_ok $cart->name, 'eq', 'main', 'name is main';

    lives_ok { $cart = cart('test') } "cart('test') lives";

    isa_ok $cart, "Dancer::Plugin::Interchange6::Cart";

    cmp_ok $cart->name, 'eq', 'test', 'name is test';
};

test 'shop_charge' => sub {

    my $charge;

    # FIXME we need some tests here

    throws_ok { $charge = shop_charge } qr/No payment setting/,
      "shop_charge dies";
};

test 'shop_redirect' => sub {

    my ( $result, $code );

    lives_ok { $result = shop_redirect } "shop_redirect lives";

    ok !defined $result, "result is undef";

    lives_ok { $result = shop_redirect('bad_uri_1') }
    "shop_redirect('bad_uri_1') in scalar context lives";

    cmp_ok $result->[0], 'eq', 'correct_uri_1', 'result is correct_uri_1';
    cmp_ok $result->[1], 'eq', '301',           'code is 301';

    lives_ok { ( $result, $code ) = shop_redirect('bad_uri_1') }
    "shop_redirect('bad_uri_1') in list context lives";

    cmp_ok $result, 'eq', 'correct_uri_1', 'result is correct_uri_1';
    cmp_ok $code,   'eq', '301',           'code is 301';
};

test 'shop_address' => sub {

    my $result;

    lives_ok { $result = shop_address } "shop_address lives";

    like ref($result), qr/ResultSet/, "returns a ResultSet";

    cmp_ok $result->count, '>', 0, "we have some addresses";

    lives_ok { $result = shop_address->search( undef, { rows => 1 } )->next }
    "get a random address";

    isa_ok $result, "Interchange6::Schema::Result::Address", "address";

    lives_ok { $result = shop_address( $result->id ) }
    "shop_address find lives";

    isa_ok $result, "Interchange6::Schema::Result::Address", "address";
};

test 'shop_attribute' => sub {

    my $result;

    lives_ok { $result = shop_attribute } "shop_attribute lives";

    like ref($result), qr/ResultSet/, "returns a ResultSet";

    cmp_ok $result->count, '>', 0, "we have some attributes";

    lives_ok { $result = shop_attribute->search( undef, { rows => 1 } )->next }
    "get a random attribute";

    isa_ok $result, "Interchange6::Schema::Result::Attribute", "attribute";

    lives_ok { $result = shop_attribute( $result->id ) }
    "shop_attribute find lives";

    isa_ok $result, "Interchange6::Schema::Result::Attribute", "attribute";
};

test 'shop_country' => sub {

    my $result;

    lives_ok { $result = shop_country } "shop_country lives";

    like ref($result), qr/ResultSet/, "returns a ResultSet";

    lives_ok { $result = shop_country("MT") } "find country MT";

    isa_ok $result, "Interchange6::Schema::Result::Country", "MT";
};

test 'shop_message' => sub {

    my $result;

    lives_ok { $result = shop_message } "shop_message lives";

    like ref($result), qr/ResultSet/, "returns a ResultSet";

    cmp_ok $result->count, '>', 0, "we have some messages";

    lives_ok { $result = shop_message->search( undef, { rows => 1 } )->next }
    "get a random message";

    isa_ok $result, "Interchange6::Schema::Result::Message", "message";

    lives_ok { $result = shop_message( $result->id ) }
    "shop_message find lives";

    isa_ok $result, "Interchange6::Schema::Result::Message", "message";
};

test 'shop_navigation' => sub {

    my $result;

    lives_ok { $result = shop_navigation } "shop_navigation lives";

    like ref($result), qr/ResultSet/, "returns a ResultSet";

    lives_ok { $result = shop_navigation( { uri => 'hand-tools' } ) }
    "find navigation hand-tools";

    isa_ok $result, "Interchange6::Schema::Result::Navigation", "hand-tools";
};

test 'shop_order' => sub {

    my $result;

    lives_ok { $result = shop_order } "shop_order lives";

    like ref($result), qr/ResultSet/, "returns a ResultSet";

    cmp_ok $result->count, '>', 0, "we have some orders";

    lives_ok { $result = shop_order->search( undef, { rows => 1 } )->next }
    "get a random order";

    isa_ok $result, "Interchange6::Schema::Result::Order", "order";

    lives_ok { $result = shop_order( $result->id ) } "shop_order find lives";

    isa_ok $result, "Interchange6::Schema::Result::Order", "order";
};

test 'shop_product' => sub {

    my $result;

    lives_ok { $result = shop_product } "shop_product lives";

    like ref($result), qr/ResultSet/, "returns a ResultSet";

    lives_ok { $result = shop_product("os28004") } "find product os28004";

    isa_ok $result, "Interchange6::Schema::Result::Product", "os28004";
};

test 'shop_state' => sub {

    my $state;

    lives_ok { shop_state } "shop_state lives";

    lives_ok {
        $state =
          shop_state( { country_iso_code => 'US', state_iso_code => 'CA' } )
    }
    "find state CA in US";

    isa_ok $state, "Interchange6::Schema::Result::State", "CA/US";
};

test 'shop_user' => sub {

    my $result;

    lives_ok { $result = shop_user } "shop_user lives";

    like ref($result), qr/ResultSet/, "returns a ResultSet";

    lives_ok { $result = shop_user( { username => "customer1" } ) }
    "find user customer1";

    isa_ok $result, "Interchange6::Schema::Result::User", "customer1";
};

1;
