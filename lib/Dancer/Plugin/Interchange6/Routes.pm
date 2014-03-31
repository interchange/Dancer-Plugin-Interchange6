package Dancer::Plugin::Interchange6::Routes;

use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Plugin::Interchange6;
use Dancer::Plugin::Interchange6::Routes::Account;
use Dancer::Plugin::Interchange6::Routes::Cart;
use Dancer::Plugin::Interchange6::Routes::Checkout;

=head1 NAME

Dancer::Plugin::Interchange6::Routes - Routes for Interchange6 Shop Machine

=head2 ROUTES

The following routes are provided by this plugin.

Active routes are automatically installed by the C<shop_setup_routes> keyword:

=over 4

=item cart (C</cart>)

Route for displaying and updating the cart.

=item checkout (C</checkout>)

Route for the checkout process (not B<active> and not recommended).

=item login (C</login>)

Login route.

=item logout (C</logout>)

Logout route.

=item navigation

Route for displaying navigation pages, for example
categories and menus.

The number of products shown on the navigation page can
be configured with the C<records> option:

  plugins:
    Interchange6::Routes:
      navigation:
        records: 20

=item product

Route for displaying products.

=back

=head2 CONFIGURATION

The template for each route type can be configured:

    plugins:
      Interchange6::Routes:
        account:
          login:
            template: login
            uri: login
            success_uri:
          logout:
            template: logout
            uri: logout
        cart:
          template: cart
          uri: cart
          active: 1
        checkout:
          template: checkout
          uri: checkout
          active: 0
        navigation:
          template: listing
          records: 0
        product:
          template: product

This sample configuration shows the current defaults.

=head2 HOOKS

The following hooks are available to manipulate the values
passed to the templates:

=over 4

=item before_product_display

The hook sub receives a hash reference, where the Product object
is the value of the C<product> key.

=item before_cart_display

=item before_checkout_display

=item before_navigation_display

The hook sub receives the navigation data as hash reference.
The list of products is the value of the C<products> key.

=item before_login_display

=back

=head3 EXAMPLES

Disable parts of layout on the login view:

    hook 'before_login_display' => sub {
        my $tokens = shift;

        $tokens->{layout_noleft} = 1;
        $tokens->{layout_noright} = 1;
    };

=cut

register shop_setup_routes => sub {
    _setup_routes();
};

register_hook (qw/before_product_display before_navigation_display/);
register_plugin;

our $object_autodetect = 0;

our %route_defaults = (
    account => {login => {template => 'login',
                          uri => 'login',
                          success_uri => '',
                      },
                logout => {template => 'logout',
                           uri => 'logout',
                       },
            },
    cart => {template => 'cart',
             uri => 'cart',
             active => 1,
         },
    checkout => {template => 'checkout',
                 uri => 'checkout',
                 active => 0,
             },
    navigation => {template => 'listing',
                   records => 0,
               },
    product => {template => 'product'},
);

sub _setup_routes {
    my $sub;
    my $plugin_config = plugin_setting;

    # update settings with defaults
    my $routes_config = _config_routes($plugin_config, \%route_defaults);

    # display warnings
    _config_warnings($routes_config);

    # check whether template engine has object autodetect
    if (config->{template} eq 'template_flute') {
        $object_autodetect = 1;
    }

    # account routes
    my $account_routes = Dancer::Plugin::Interchange6::Routes::Account::account_routes($routes_config);

    get '/' . $routes_config->{account}->{login}->{uri}
        => $account_routes->{login}->{get};

    post '/' . $routes_config->{account}->{login}->{uri}
        => $account_routes->{login}->{post};

    any ['get', 'post'] => '/' . $routes_config->{account}->{logout}->{uri}
        => $account_routes->{logout}->{any};

    if ($routes_config->{cart}->{active}) {
        # routes for cart
        my $cart_sub = Dancer::Plugin::Interchange6::Routes::Cart::cart_route($routes_config);
        get '/' . $routes_config->{cart}->{uri} => $cart_sub;
        post '/' . $routes_config->{cart}->{uri} => $cart_sub;
    }

    if ($routes_config->{checkout}->{active}) {
        # routes for checkout
        my $checkout_sub = Dancer::Plugin::Interchange6::Routes::Checkout::checkout_route($routes_config);
        get '/' . $routes_config->{checkout}->{uri} => $checkout_sub;
        post '/' . $routes_config->{checkout}->{uri} => $checkout_sub;
    }

    # fallback route for flypage and navigation
    get qr{/(?<path>.+)} => sub {
        my $path = captures->{'path'};
        my $product;

        # check for a matching product by uri
        my $product_result = shop_product->search({uri => $path});

        if ($product_result > 1) {
            die "Ambigious result on path $path.";
        }

        if ($product_result == 1) {
            $product = $product_result->next;
        }
        else {
            # check for a matching product by sku
            $product = shop_product($path);

            if ($product) {
                if ($product->uri
                    && $product->uri ne $path) {
                    # permanent redirect to specific URL
                    debug "Redirecting permanently to product uri ", $product->uri,
                        " for $path.";
                    return redirect(uri_for($product->uri), 301);
                }
            }
            else {
                # no matching product found
                undef $product;
            }
        }

        if ($product) {
            if ($product->active) {
                # flypage
                my $tokens = {product => $product};

                execute_hook('before_product_display', $tokens);

                my $output = template $routes_config->{product}->{template}, $tokens;

                # temporary way to erase cart errors from missing variants
                session shop_cart_error => undef;

                return $output;
            }
            else {
                # discontinued
                status 'not_found';
                forward 404; 
            }
        }

        # check for page number
        my $page;

        if ($path =~ s%/([1-9][0-9]*)$%%) {
            $page = $1;
        }
        else {
            $page = 1;
        }

        # first check for navigation item
        my $navigation_result = shop_navigation->search({uri => $path});

        if ($navigation_result > 1) {
            die "Ambigious result on path $path.";
        }

        if ($navigation_result == 1) {
            # navigation item found
            my $nav = $navigation_result->next;

            # search parameters
            my $search_args = {
                conditions => {
                    # only active items
                    active => 1,
                },
                attributes => {
                    rows => $routes_config->{navigation}->{records},
                    page => $page},
            };

            my $products;

            my $nav_products = $nav->search_related('NavigationProduct')->search_related(
                'Product',
                $search_args->{conditions},
                $search_args->{attributes},
            );

            if ($object_autodetect) {
                $products = $nav_products;
            }
            else {
                while (my $rec = $nav_products->next) {
                    push @$products, $rec;
                    next if @$products > 200;
                }
            }

            # retrieve navigation attribute for template
	    my $template = $routes_config->{navigation}->{template};

	    if (my $attr_value = $nav->find_attribute_value('template')) {
		$template = $attr_value;
	    }

            my $tokens = {navigation => $nav,
			  template => $template,
                          products => $products,
                          count => $nav_products->count,
                          pager => $nav_products->pager,
                         };

            execute_hook('before_navigation_display', $tokens);

            return template $tokens->{template}, $tokens;
        }

        # display not_found page
        status 'not_found';
        forward 404;
    };
}

sub _config_routes {
    my ($settings, $defaults) = @_;
    my ($key, $vref, $name, $value, $set_value);

    unless (ref($defaults)) {
        return;
    }

    while (($key, $vref) = each %$defaults) {
        if (exists $settings->{$key}) {
            # recurse
            _config_routes($settings->{$key}, $defaults->{$key});
        }
         else {
            $settings->{$key} = $defaults->{$key};
        }
    }

    return $settings;
}

sub _config_warnings {
    my ($settings) = @_;

    if ($settings->{navigation}->{records} == 0) {
        warn __PACKAGE__, ": Maximum number of navigation records is zero.\n";
    }
}

1;
