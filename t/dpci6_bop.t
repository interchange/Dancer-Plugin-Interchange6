use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Exception;

use Dancer qw/set/;
use Dancer::Plugin::Interchange6::Business::OnlinePayment;
use lib 't/lib';

set log    => 'debug';
set logger => 'capture';

my ( $bop, $log );
my $trap = Dancer::Logger::Capture->trap;

lives_ok {
    $bop = Dancer::Plugin::Interchange6::Business::OnlinePayment->new('Mock')
}
"create mock bop object with no test_type";

throws_ok { $bop->charge( amount => 1 ) } qr/test_type not defined/,
  "charge dies with no test_type";

lives_ok {
    $bop =
      Dancer::Plugin::Interchange6::Business::OnlinePayment->new( 'Mock',
        test_type => "die" )
}
"create mock bop object with test_type die";

throws_ok {
    $bop->charge( amount => 1, type => 'CC', action => 'Authorization Only' )
}
qr/test_type die/, "charge dies with test_type die";

lives_ok {
    $bop = Dancer::Plugin::Interchange6::Business::OnlinePayment->new(
        'Mock',
        test_type => "declined;invalid cvc",
        type      => 'CC',
        action    => 'Authorization Only'
      )
}
"create mock bop object with test_type declined;invalid cvc";

lives_ok { $bop->charge( amount => 1 ) } "charge lives";

ok !$bop->is_success, "is_success is false";
cmp_ok $bop->error_code,    'eq', 'declined',    "error code declined";
cmp_ok $bop->error_message, 'eq', 'invalid cvc', "error_message invalid cvc";

$log = $trap->read;
cmp_deeply(
    $log,
    superbagof(
        {
            level   => "debug",
            message => "Card was rejected by Mock: invalid cvc",
        }
    ),
    "got expected debug messages"
) or diag explain $log;

lives_ok {
    $bop =
      Dancer::Plugin::Interchange6::Business::OnlinePayment->new( 'Mock',
        test_type => "success" )
}
"create mock bop object with test_type success";

lives_ok { $bop->charge( amount => 1 ) } "charge lives";

ok $bop->is_success,        "is_success is true";
cmp_ok $bop->authorization, '==', 1, "we have authorization == 1";
cmp_ok $bop->order_number,  '==', 1001, "we have order_number = 1001";

$log = $trap->read;
cmp_deeply(
    $log,
    superbagof(
        {
            level   => "debug",
            message => "Successful payment, authorization: 1",
        },
        {
            level   => "debug",
            message => "Order number: 1001",
        },
    ),
    "got expected debug messages"
) or diag explain $log;

lives_ok {
    $bop =
      Dancer::Plugin::Interchange6::Business::OnlinePayment->new( 'MockPopup',
        test_type => "success", server => "www.example.com" )
}
"create MockPopup bop object with test_type success";

lives_ok { $bop->charge( amount => 1 ) } "charge lives";

ok $bop->is_success, "is_success is true";

$log = $trap->read;
cmp_deeply(
    $log,
    superbagof(
        {
            level => "debug",
            message =>
              "Success!  Redirect browser to http://localhost/payment_popup",
        },
    ),
    "got expected debug messages"
) or diag explain $log;

done_testing();
