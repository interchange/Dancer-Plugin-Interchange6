use strict;
use warnings;

use Test::More;
use Test::Database;

use DBICx::TestDatabase;
use Interchange6::Schema;
use Interchange6::Schema::Populate::CountryLocale;

use Dancer ':syntax';
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

my $tests = 5 * scalar(@handles);

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
    diag 'Testing with DBI driver ' . $testdb->dbd();

    my $dbh = $testdb->dbh();
    my $dbd = $testdb->dbd();

    my @connection_info = $testdb->connection_info;
    my $schema = Interchange6::Schema->connect($testdb->connection_info);

    isa_ok($schema, 'Interchange6::Schema');

    set plugins => {DBIC => {default => {dsn => $connection_info[0],
                                         user => $connection_info[1],
                                         pass => $connection_info[2],
                                     schema_class => 'Interchange6::Schema'}
                        }
               };

    my $shop_schema = shop_schema;

    isa_ok($schema, 'Interchange6::Schema');

    # deploy our schema
    $schema->deploy({add_drop_table => 1});

    # populate country table
    $schema->populate('Country', $pop_countries);

    # check PL country
    my $ret = $schema->resultset('Country')->find('PL');

    isa_ok($ret, 'Interchange6::Schema::Result::Country');
    ok($ret->name eq 'Poland');

    my $rs = shop_country->find('PL');

    isa_ok($rs, 'Interchange6::Schema::Result::Country');
}
