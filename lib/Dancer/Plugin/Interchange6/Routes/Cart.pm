package Dancer::Plugin::Interchange6::Routes::Cart;

use Data::Dumper::Concise;
use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Plugin::Interchange6;
use Dancer::Plugin::Auth::Extensible;
use Try::Tiny;

=head1 NAME

Dancer::Plugin::Interchange6::Routes::Cart - Cart routes for Interchange6 Shop Machine

=cut

register_hook 'before_cart_display';

=head1 FUNCTIONS

=head2 cart_route

Returns the cart route based on the passed routes configuration.

=cut

sub cart_route {
    my $routes_config = shift;

    return sub {
        my %values;
        my ($input, $product, $cart, $cart_item, $cart_name, $cart_input,
            $cart_product, $roles, @errors);

        if ($cart_name = param('cart') && scalar($cart_name)) {
            $cart = cart($cart_name);
        }
        else {
            $cart = cart;
        }

        debug "cart_route cart name: " . $cart->name;

        if ( param('remove') ) {

            # removing item from cart
            try {
                $cart->remove( param('remove') );
            }
            catch {
                warning "Cart add error: $_";
                push @errors, "Failed to add product to cart: $_";
            };
        }

        if ($input = param('sku')) {
            if (scalar($input)) {
                $product = shop_product($input);

                unless ( defined $product ) {
                    warning "sku not found in POST /cart: $input";
                    session shop_cart_error =>
                      { message => "Product not found with sku: $input" };
                    return redirect '/';
                }

                # retrieve product attributes for possible variants
                my $attr_ref = $product->attribute_iterator(hashref => 1);
                my %user_input;

                if (keys %$attr_ref) {
                    # find variant
                    for my $name (keys %$attr_ref) {
                        $user_input{$name} = param($name);
                    }

                    debug "Attributes for $input: ", $attr_ref, ", user input: ", \%user_input;
                    my %match_info;

                    unless ($cart_product = $product->find_variant(\%user_input, \%match_info)) {
                        warning "Variant not found for ", $product->sku;
                        session shop_cart_error => {message => 'Variant not found.', info => \%match_info};
                        return redirect $product->uri;
                    };
                }
                else {
                    # product without variants
                    $cart_product = $product;
                }

                my $quantity = 1;
                if ( param('quantity') ) {
                    $quantity = param('quantity');
                }

                try {
                    $cart_item = $cart->add(
                        { sku => $cart_product->sku, quantity => $quantity } );
                }
                catch {
                    warning "Cart add error: $_";
                    push @errors, "Failed to add product to cart: $_";
                };
            }
        }

        # add stuff useful for cart display
        $values{cart_subtotal} = $cart->subtotal;
        $values{cart_total} = $cart->total;
        $values{cart} = $cart->products;
        $values{cart_error} = join(". ", @errors);

        # call before_cart_display route so template tokens
        # can be injected
        execute_hook('before_cart_display', \%values);

        template $routes_config->{cart}->{template}, \%values;
    }
}

1;
