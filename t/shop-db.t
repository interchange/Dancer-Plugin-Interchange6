use strict;
use warnings;

use Test::More;
use Test::Database;

use DBICx::TestDatabase;
use Interchange6::Schema;
use Interchange6::Schema::Populate::CountryLocale;

use Dancer qw(:tests);
use Dancer::Plugin::Interchange6;

my @all_handles = Test::Database->handles();
my @handles;
my %exclude_dbd = (CSV => 1,
                   DBM => 1,
                   SQLite2 => 1,
                   );

for my $testdb (@all_handles) {
    next if exists $exclude_dbd{$testdb->dbd};

    push @handles, $testdb;
}

my $tests = 10 * scalar(@handles);

if ($tests) {
    # determine number of tests
    plan tests => $tests;
}
else {
    plan skip_all => 'No test database handles available';
}

# prepare records for populating the database
my $pop_countries = Interchange6::Schema::Populate::CountryLocale->new->records;

for my $testdb (@handles) {
    my $driver = $testdb->dbd();

    diag "Testing with DBI driver $driver";

    my $dbh = $testdb->dbh();
    my $dbd = $testdb->dbd();

    my @connection_info = $testdb->connection_info;
    my $schema = Interchange6::Schema->connect($testdb->connection_info);

    my $ret;

    isa_ok($schema, 'Interchange6::Schema');

    set plugins => {DBIC => {$driver => {dsn => $connection_info[0],
                                         user => $connection_info[1],
                                         pass => $connection_info[2],
                                     schema_class => 'Interchange6::Schema'}
                        }
               };

    my $shop_schema = shop_schema($driver);

    # deploy our schema
    $schema->deploy({add_drop_table => 1});

    # add user
    my %user_data = (username => 'nevairbe@nitesi.de',
                     email => 'nevairbe@nitesi.de',
                     password => 'nevairbe');

    my $user = $schema->resultset('User')->create(\%user_data);

    isa_ok($user, 'Interchange6::Schema::Result::User');

    # populate country table
    $schema->populate('Country', $pop_countries);

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

    $ret = shop_product->create(\%product_data);
    isa_ok($ret, 'Interchange6::Schema::Result::Product');

    # create review
    my %review_data;

    %review_data = (
        sku => 'F0001',
        users_id => $user->id,
        title => 'test',
        content => 'Text review',
        rating => 2,
    );

    $ret = shop_review->create(\%review_data);
    isa_ok($ret, 'Interchange6::Schema::Result::Review');
}
