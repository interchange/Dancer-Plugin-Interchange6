package TestApp;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::Interchange6;
use Dancer::Plugin::Interchange6::Routes;
use Dancer::Plugin::Auth::Extensible;
use Dancer::Plugin::DBIC;

# ROUTES

get '/' => sub {
    return 'Home page';
};

get '/login' => sub {
    return "Login form";
};

get '/login/denied' => sub {
    return 'Denied';
};

get '/private' => require_login sub {
    return 'Private page';
};

get '/sessionid' => sub {
    return session->id;
};

shop_setup_routes;

# HOOKS

# display hooks

hook before_cart_display => sub {
    my $tokens        = shift;
    my $products      = $tokens->{cart};
    my $cart_error    = $tokens->{cart_error};
    my $cart_subtotal = $tokens->{cart_subtotal};
    my $cart_total    = $tokens->{cart_total};

    debug join( " ",
        "hook before_cart_display",
        scalar @$products,
        $cart_subtotal, $cart_total );

    $tokens->{cart} = join(
        ",",
        sort map {
            join( ':',
                $_->sku, $_->name, $_->quantity,
                sprintf( "%.2f", $_->price ),
                sprintf( "%.2f", $_->selling_price ), $_->uri )
        } @$products
    );
};

hook before_checkout_display => sub {
    my $tokens        = shift;
    my $products      = $tokens->{cart};
    my $cart_subtotal = $tokens->{cart_subtotal};
    my $cart_total    = $tokens->{cart_total};

    debug join( " ",
        "hook before_checkout_display",
        scalar @$products,
        $cart_subtotal, $cart_total );


    $tokens->{cart} = join(
        ",",
        sort map {
            join( ':',
                $_->sku, $_->name, $_->quantity,
                sprintf( "%.2f", $_->price ),
                sprintf( "%.2f", $_->selling_price ), $_->uri )
        } @$products
    );
};

hook before_login_display => sub {
    my ($tokens)   = @_;
    my $error      = $tokens->{error};
    my $return_url = $tokens->{return_url};
    debug "hook before_login_display";
};

hook before_product_display => sub {
    my $tokens  = shift;
    my $product = $tokens->{product};
    debug "hook before_product_display";

    $tokens->{name} = $product->name;
};

hook before_navigation_search => sub {
    my ($tokens) = @_;
    my $page     = $tokens->{page};
    my $nav      = $tokens->{navigation};
    my $template = $tokens->{template};
    debug "hook before_navigation_search";
};

hook before_navigation_display => sub {
    my $tokens   = shift;
    my $nav      = $tokens->{navigation};
    my $page     = $tokens->{page};
    my $pager    = $tokens->{pager};
    my $products = $tokens->{products};
    my $template = $tokens->{template};

    debug "hook before_navigation_display";

    $tokens->{name} = $nav->name;
    $tokens->{products} = join( ",", sort map { $_->name } @$products );
};

# cart hooks

hook before_cart_add_validate => sub {
    my ( $cart, $args ) = @_;
    debug "hook before_cart_add_validate ",
      join( " ", $cart->name, $cart->total, $args->[0]->{sku} );
};

hook before_cart_add => sub {
    my ( $cart, $products ) = @_;
    debug "hook before_cart_add ",
      join( " ",
        $cart->name, $cart->total,
        $products->[0]->{sku},
        $products->[0]->{name} );
};

hook after_cart_add => sub {
    my ( $cart, $products ) = @_;
    debug "hook after_cart_add ",
      join( " ",
        $cart->name, $cart->total,
        ref( $products->[0] ),
        $products->[0]->sku,
        $products->[0]->name );
};

hook before_cart_update => sub {
    my ( $cart, $sku, $quantity ) = @_;
    debug "hook before_cart_update";
};

hook after_cart_update => sub {
    my ( $cart, $sku, $quantity ) = @_;
    debug "hook after_cart_update";
};

hook before_cart_remove_validate => sub {
    my ( $cart, $sku ) = @_;
    debug "hook before_cart_remove_validate";
};

hook before_cart_remove => sub {
    my ( $cart, $sku ) = @_;
    debug "hook before_cart_remove";
};

hook after_cart_remove => sub {
    my ( $cart, $sku ) = @_;
    debug "hook after_cart_remove";
};

hook before_cart_rename => sub {
    my ( $cart, $old_name, $new_name ) = @_;
    debug "hook before_cart_rename";
};

hook after_cart_rename => sub {
    my ( $cart, $old_name, $new_name ) = @_;
    debug "hook after_cart_rename";
};

hook before_cart_clear => sub {
    my ($cart) = @_;
    debug "hook before_cart_clear";
};

hook after_cart_clear => sub {
    my ($cart) = @_;
    debug "hook after_cart_clear";
};

hook before_cart_set_users_id => sub {
    my ( $cart, $users_id ) = @_;
    debug "hook before_cart_set_users_id";
};

hook after_cart_set_users_id => sub {
    my ( $cart, $users_id ) = @_;
    debug "hook after_cart_set_users_id";
};

hook before_cart_set_sessions_id => sub {
    my ( $cart, $sessions_id ) = @_;
    debug "hook before_cart_set_sessions_id";
};

hook after_cart_set_sessions_id => sub {
    my ( $cart, $sessions_id ) = @_;
    debug "hook after_cart_set_sessions_id";
};

1;
