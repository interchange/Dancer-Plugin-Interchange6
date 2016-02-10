package Test::Hooks;

use Test::Exception;
use Test::More;
use Test::Roo::Role;

use Dancer::Plugin::Interchange6;

test 'before_cart_display hook' => sub {
    my $self = shift;

    diag "Test::Hooks";

    ok(1);
};

test 'before_checkout_display hook' => sub {
    my $self = shift;

    ok(1);
};

test 'before_login_display hook' => sub {
    my $self = shift;

    ok(1);
};

test 'before_navigation hooks' => sub {
    my $self = shift;

    ok(1);

    # before_navigation_search
    # before_navigation_display
};

test 'before_product_display hook' => sub {
    my $self = shift;

    ok(1);
};

test 'cart_add hooks' => sub {
    my $self = shift;

    ok(1);
    # before_cart_add_validate
    # before_cart_add
    # after_cart_add
};

test 'cart_update hooks' => sub {
    my $self = shift;

    ok(1);
    # before_cart_update
    # after_cart_update

};

test 'cart_remove hooks' => sub {
    my $self = shift;

    ok(1);
    # before_cart_remove_validate
    # before_cart_remove
    # after_cart_remove

};

test 'cart_rename hooks' => sub {
    my $self = shift;

    ok(1);
    # before_cart_rename
    # after_cart_rename

};

test 'cart_clear hooks' => sub {
    my $self = shift;

    ok(1);
    # before_cart_clear
    # after_cart_clear

};

test 'cart_set_users_id hooks' => sub {
    my $self = shift;

    ok(1);
    # before_cart_set_users_id
    # after_cart_set_users_id

};

test 'cart_set_sessions_id hooks' => sub {
    my $self = shift;

    ok(1);
    # before_cart_set_sessions_id
    # after_cart_set_sessions_id

};

1;
