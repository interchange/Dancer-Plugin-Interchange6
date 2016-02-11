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

post '/rename_cart' => sub {
    my $newname = param('name');
    shop_cart->rename($newname);
    return $newname;
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
    my $error      = $tokens->{error} || 'none';
    my $return_url = $tokens->{return_url} || 'none';

    debug join(" ", "hook before_login_display", $error, $return_url);
};

hook before_product_display => sub {
    my $tokens  = shift;
    my $product = $tokens->{product};

    debug join( " ",
        "hook before_product_display",
        $product->sku, $product->name, $product->price );

    $tokens->{name} = $product->name;
};

hook before_navigation_search => sub {
    my ($tokens) = @_;
    my $nav      = $tokens->{navigation};
    my $page     = $tokens->{page};
    my $template = $tokens->{template};

    debug
      join( " ", "hook before_navigation_search", $nav->name, $page,
        $template );
};

hook before_navigation_display => sub {
    my $tokens   = shift;
    my $nav      = $tokens->{navigation};
    my $page     = $tokens->{page};
    my $pager    = $tokens->{pager};
    my $products = $tokens->{products};
    my $template = $tokens->{template};

    debug join( " ",
        "hook before_navigation_display",
        $nav->name, $page, $pager->last_page, scalar @$products, $template );

    $tokens->{name} = $nav->name;
    $tokens->{products} = join( ",", sort map { $_->name } @$products );
};

# cart hooks

hook before_cart_add_validate => sub {
    my ( $cart, $args ) = @_;

    debug join( " ",
        "hook before_cart_add_validate",
        $cart->name, $cart->total, $args->[0]->{sku} || 'undef' );
};

hook before_cart_add => sub {
    my ( $cart, $products ) = @_;

    debug join( " ",
        "hook before_cart_add",
        $cart->name, $cart->total,
        $products->[0]->{sku},
        $products->[0]->{name} );
};

hook after_cart_add => sub {
    my ( $cart, $products ) = @_;

    debug join( " ",
        "hook after_cart_add",
        $cart->name, $cart->total,
        ref( $products->[0] ),
        $products->[0]->sku,
        $products->[0]->name );
};

hook before_cart_update => sub {
    my ( $cart, $sku, $quantity ) = @_;

    $quantity = 'undef' if !defined $quantity;
    $sku      = 'undef' if !defined $sku;

    debug join( " ",
        "hook before_cart_update",
        $cart->name, $cart->total, $sku, $quantity );
};

hook after_cart_update => sub {
    my ( $ret, $sku, $quantity ) = @_;

    debug join( " ",
        "hook after_cart_update",
        $ret->sku, $ret->quantity, $sku, $quantity );
};

hook before_cart_remove_validate => sub {
    my ( $cart, $sku ) = @_;

    debug join( " ",
        "hook before_cart_remove_validate",
        $cart->name, $cart->total, $sku || 'undef' );
};

hook before_cart_remove => sub {
    my ( $cart, $sku ) = @_;

    debug join( " ",
        "hook before_cart_remove",
        $cart->name, $cart->total, $sku || 'undef' );
};

hook after_cart_remove => sub {
    my ( $cart, $sku ) = @_;

    debug join( " ",
        "hook after_cart_remove",
        $cart->name, $cart->total, $sku );
};

hook before_cart_rename => sub {
    my ( $cart, $old_name, $new_name ) = @_;

    debug join( " ",
        "hook before_cart_rename",
        $cart->name,
        $old_name || 'undef',
        $new_name || 'undef' );
};

hook after_cart_rename => sub {
    my ( $cart, $old_name, $new_name ) = @_;

    debug join( " ",
        "hook after_cart_rename",
        $cart->name, $old_name, $new_name );
};

hook before_cart_clear => sub {
    my ($cart) = @_;

    debug join( " ", "hook before_cart_clear", $cart->name, $cart->total );
};

hook after_cart_clear => sub {
    my ($cart) = @_;

    debug join( " ", "hook after_cart_clear", $cart->name, $cart->total );
};

hook before_cart_set_users_id => sub {
    my ( $cart, $users_id ) = @_;

    debug join( " ",
        "hook before_cart_set_users_id",
        $cart->name, $cart->total,
        $cart->users_id || 'undef',
        $users_id || 'undef' );
};

hook after_cart_set_users_id => sub {
    my ( $ret, $users_id ) = @_;

    debug join( " ",
        "hook after_cart_set_users_id",
        $ret, $users_id );
};

hook before_cart_set_sessions_id => sub {
    my ( $cart, $sessions_id ) = @_;

    debug join( " ",
        "hook before_cart_set_sessions_id",
        $cart->name, $cart->total,
        $cart->sessions_id || 'undef',
        $sessions_id || 'undef' );
};

hook after_cart_set_sessions_id => sub {
    my ( $cart, $sessions_id ) = @_;

    debug join( " ",
        "hook after_cart_set_sessions_id",
        $cart->name, $cart->total,
        $cart->sessions_id || 'undef',
        $sessions_id || 'undef' );
};

1;
