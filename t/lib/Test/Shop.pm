package Test::Shop;

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

test 'misc shop tests' => sub {
    my $self = shift;

    diag "Test::Shop";

    my $ret;

    my $shop_schema = shop_schema;

    # check PL country
    $ret = shop_country->find('PL');

    isa_ok($ret, 'Interchange6::Schema::Result::Country');
    ok($ret->name eq 'Poland', 'Country name Poland');
    ok($ret->show_states == 0, 'Show states for Poland');

    # check US country
    $ret = shop_country->find('US');

    isa_ok($ret, 'Interchange6::Schema::Result::Country');
    ok($ret->name eq 'United States', 'Country name United States');
    ok($ret->show_states == 1, 'Show states for United States');

    # create product
    my %product_data;

    %product_data = (
        sku => 'F0001',
        name => 'One Dozen Roses',
        short_description => 'What says I love you better than 1 dozen fresh roses?',
        description => 'Surprise the one who makes you smile, or express yourself perfectly with this stunning bouquet of one dozen fresh red roses. This elegant arrangement is a truly thoughtful gift that shows how much you care.',
        price => '39.95',
        uri => 'one-dozen-roses',
        weight => '4',
    );

    my $product = shop_product->create(\%product_data);
    isa_ok($product, 'Interchange6::Schema::Result::Product');

    # create review
    my %review_data;

    %review_data = (
        author => shop_user->first->id,
        title => 'test',
        content => 'Text review',
        rating => 2,
    );

    cmp_ok(shop_message->count, '==', 0, "0 Message rows");

    lives_ok( sub { $ret = $product->set_reviews(\%review_data) },
    "add a product review" );

    cmp_ok(shop_message->count, '==', 1, "1 Message row");
};

1;
