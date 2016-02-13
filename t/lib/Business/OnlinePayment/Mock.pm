package Business::OnlinePayment::Mock;

use strict;
use warnings;

use base 'Business::OnlinePayment';

our $auth_id      = 0;
our $order_number = 1000;

sub submit {
    my $self    = shift;
    my %content = $self->content;

    my $test_type = $content{test_type};

    if ( !defined $test_type ) {
        die "test_type not defined";
    }
    elsif ( $test_type eq "die" ) {
        die "test_type die";
    }
    elsif ( $test_type eq "success" ) {
        $self->is_success(1);
        $self->authorization( ++$auth_id );
        $self->order_number( ++$order_number );
    }
    else {
        $self->is_success(0);
        my ( $code, $msg ) = split( /;/, $test_type );
        $self->failure_status($code);
        $self->error_message($msg);
    }
}

1;
