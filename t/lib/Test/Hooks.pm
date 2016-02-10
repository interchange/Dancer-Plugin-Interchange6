package Test::Hooks;

use Test::Exception;
use Test::More;
use Dancer qw/debug hook/;
use Dancer::Plugin::Interchange6;
use Test::Roo::Role;
with 'Role::Mechanize';

test 'before_cart_display hook' => sub {
    my $self = shift;
    my $mech = $self->mech;

    diag "Test::Hooks";

    # before_cart_display

    lives_ok {
        hook before_cart_display => sub {
            my ( $cart, $tokens ) = @_;
            my $products      = $tokens->{cart};
            my $cart_error    = $tokens->{cart_error};
            my $cart_subtotal = $tokens->{cart_subtotal};
            my $cart_total    = $tokens->{cart_total};
            debug "hook before_cart_display";
        };
    }
    "add hook before_cart_display";
};

test 'before_checkout_display hook' => sub {
    my $self = shift;
    my $mech = $self->mech;

    # before_checkout_display

    lives_ok {
        hook before_checkout_display => sub {
            my ( $cart, $tokens ) = @_;
            my $products      = $tokens->{cart};
            my $cart_subtotal = $tokens->{cart_subtotal};
            my $cart_total    = $tokens->{cart_total};
            debug "hook before_checkout_display";
        };
    }
    "add hook before_checkout_display";
};

test 'before_login_display hook' => sub {
    my $self = shift;
    my $mech = $self->mech;

    # before_login_display

    lives_ok {
        hook before_login_display => sub {
            my ( $cart, $tokens ) = @_;
            my $error      = $tokens->{error};
            my $return_url = $tokens->{return_url};
            debug "hook before_login_display";
        };
    }
    "add hook before_login_display";
};

test 'before_navigation hooks' => sub {
    my $self = shift;
    my $mech = $self->mech;

    # before_navigation_search
    # before_navigation_display

    lives_ok {
        hook before_navigation_search => sub {
            my ( $cart, $tokens ) = @_;
            my $page     = $tokens->{page};
            my $nav      = $tokens->{navigation};
            my $template = $tokens->{template};
            debug "hook before_navigation_search";
        };
    }
    "add hook before_navigation_search";

    lives_ok {
        hook before_navigation_display => sub {
            my ( $cart, $tokens ) = @_;
            my $nav      = $tokens->{navigation};
            my $page     = $tokens->{page};
            my $pager    = $tokens->{pager};
            my $products = $tokens->{products};
            my $template = $tokens->{template};
            debug "hook before_navigation_display";
        };
    }
    "add hook before_navigation_display";
};

test 'before_product_display hook' => sub {
    my $self = shift;
    my $mech = $self->mech;

    # before_product_display

    lives_ok {
        hook before_product_display => sub {
            my ( $cart, $tokens ) = @_;
            my $product = $tokens->{product};
            debug "hook before_product_display";
        };
    }
    "add hook before_product_display";
};

test 'cart_add hooks' => sub {
    my $self = shift;

    # before_cart_add_validate
    # before_cart_add
    # after_cart_add

    my $cart;

    lives_ok { shop_schema->resultset('Cart')->delete }
    "clear out any carts in the database";

    lives_ok { $cart = shop_cart } "get cart";

    lives_ok {
        hook before_cart_add_validate => sub {
            my ( $cart, $args ) = @_;
            debug "hook before_cart_add_validate";
        };
    }
    "add hook before_cart_add_validate";

    lives_ok {
        hook before_cart_add => sub {
            my ( $cart, $products ) = @_;
            debug "hook before_cart_add";
        };
    }
    "add hook before_cart_add";

    lives_ok {
        hook after_cart_add => sub {
            my ( $cart, $products ) = @_;
            debug "hook after_cart_add";
        };
    }
    "add hook after_cart_add";
};

test 'cart_update hooks' => sub {
    my $self = shift;

    # before_cart_update
    # after_cart_update

    my $cart;

    lives_ok { $cart = shop_cart } "get cart";

    lives_ok {
        hook before_cart_update => sub {
            my ( $cart, $sku, $quantity ) = @_;
            debug "hook before_cart_update";
        };
    }
    "add hook before_cart_update";

    lives_ok {
        hook after_cart_update => sub {
            my ( $cart, $sku, $quantity ) = @_;
            debug "hook after_cart_update";
        };
    }
    "add hook after_cart_update";

};

test 'cart_remove hooks' => sub {
    my $self = shift;

    # before_cart_remove_validate
    # before_cart_remove
    # after_cart_remove

    my $cart;

    lives_ok { $cart = shop_cart } "get cart";

    lives_ok {
        hook before_cart_remove_validate => sub {
            my ( $cart, $sku ) = @_;
            debug "hook before_cart_remove_validate";
        };
    }
    "add hook before_cart_remove_validate";

    lives_ok {
        hook before_cart_remove => sub {
            my ( $cart, $sku ) = @_;
            debug "hook before_cart_remove";
        };
    }
    "add hook before_cart_remove";

    lives_ok {
        hook after_cart_remove => sub {
            my ( $cart, $sku ) = @_;
            debug "hook after_cart_remove";
        };
    }
    "add hook after_cart_remove";

};

test 'cart_rename hooks' => sub {
    my $self = shift;

    # before_cart_rename
    # after_cart_rename

    my $cart;

    lives_ok { $cart = shop_cart } "get cart";

    lives_ok {
        hook before_cart_rename => sub {
            my ( $cart, $old_name, $new_name ) = @_;
            debug "hook before_cart_rename";
        };
    }
    "add hook before_cart_rename";

    lives_ok {
        hook after_cart_rename => sub {
            my ( $cart, $old_name, $new_name ) = @_;
            debug "hook after_cart_rename";
        };
    }
    "add hook after_cart_rename";

};

test 'cart_clear hooks' => sub {
    my $self = shift;

    # before_cart_clear
    # after_cart_clear

    my $cart;

    lives_ok { $cart = shop_cart } "get cart";

    lives_ok {
        hook before_cart_clear => sub {
            my ($cart) = @_;
            debug "hook before_cart_clear";
        };
    }
    "add hook before_cart_clear";

    lives_ok {
        hook after_cart_clear => sub {
            my ($cart) = @_;
            debug "hook after_cart_clear";
        };
    }
    "add hook after_cart_clear";

};

test 'cart_set_users_id hooks' => sub {
    my $self = shift;

    # before_cart_set_users_id
    # after_cart_set_users_id

    my $cart;

    lives_ok { $cart = shop_cart } "get cart";

    lives_ok {
        hook before_cart_set_users_id => sub {
            my ( $cart, $users_id ) = @_;
            debug "hook before_cart_set_users_id";
        };
    }
    "add hook before_cart_set_users_id";

    lives_ok {
        hook after_cart_set_users_id => sub {
            my ( $cart, $users_id ) = @_;
            debug "hook after_cart_set_users_id";
        };
    }
    "add hook after_cart_set_users_id";

};

test 'cart_set_sessions_id hooks' => sub {
    my $self = shift;

    # before_cart_set_sessions_id
    # after_cart_set_sessions_id

    my $cart;

    lives_ok { $cart = shop_cart } "get cart";

    lives_ok {
        hook before_cart_set_sessions_id => sub {
            my ( $cart, $sessions_id ) = @_;
            debug "hook before_cart_set_sessions_id";
        };
    }
    "add hook before_cart_set_sessions_id";

    lives_ok {
        hook after_cart_set_sessions_id => sub {
            my ( $cart, $sessions_id ) = @_;
            debug "hook after_cart_set_sessions_id";
        };
    }
    "add hook after_cart_set_sessions_id";

};

1;
