package Dancer::Plugin::Interchange6;

use strict;
use warnings;

use Dancer qw(:syntax !before !after);
use Dancer::Plugin;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use Interchange6::Class;
use Interchange6::Cart;

=head1 NAME

Dancer::Plugin::Interchange6 - Interchange6 Shop Plugin for Dancer

=head1 VERSION

Version 0.002

=cut

our $VERSION = '0.002';

=head1 HOOKS

This plugin installs the following hooks:

=head2 Add to cart

The functions registered for these hooks receive the cart object
and the item to be added as parameters.

=over 4

=item before_cart_add_validate

Triggered before item is validated for adding to the cart.

=item before_cart_add

Triggered before item is added to the cart.

=item after_cart_add

Triggered after item is added to the cart.
Used by DBI backend to save item to the database.

=back

=head2 Update cart

The functions registered for these hooks receive the cart object,
the current item in the cart and the updated item.

=over 4

=item before_cart_update

Triggered before cart item is updated (changing quantity).

=item after_cart_update

Triggered after cart item is updated (changing quantity).
Used by DBI backend to update item to the database.

=back

=head2 Remove from cart

The functions registered for these hooks receive the cart object
and the item to be added as parameters.

=over 4

=item before_cart_remove_validate

Triggered before item is validated for removal.
Receives cart object and item SKU.

=item before_cart_remove

Triggered before item is removed from the cart.
Receives cart object and item.

=item after_cart_remove

Triggered after item is removed from the cart.
Used by DBI backend to delete item from the database.
Receives cart object and item.

=back

=head2 Clear cart

=over 4

=item before_cart_clear

Triggered before cart is cleared.

=item after_cart_clear

Triggered after cart is cleared.

=back

=head2 Rename cart

The functions registered for these hooks receive the cart object,
the old name and the new name.

=over 4

=item before_cart_rename

Triggered before cart is renamed.

=item after_cart_rename

Triggered after cart is renamed.

=back

=cut

register_hook(qw/before_cart_add_validate
                 before_cart_add after_cart_add
                 before_cart_update after_cart_update
                 before_cart_remove_validate
                 before_cart_remove after_cart_remove
                 before_cart_rename after_cart_rename
                 before_cart_clear after_cart_clear
                /);

register shop_navigation => sub {
    _shop_resultset('Navigation', @_);
};

register shop_product => sub {
    _shop_resultset('Product', @_);
};

register shop_product_class => sub {
    _shop_resultset('ProductClass', @_);
};

register cart => sub {
    my $name = 'main';
    my ($user_ref, $cart);

    if (@_ == 1) {
        $name = $_[0];
    }

    $cart = Interchange6::Class->instantiate('Dancer::Plugin::Interchange6::Cart::DBIC',
                                       name => $name,
                                       session_id => session->id,
                                       run_hooks => sub {execute_hook(@_)});

    if ($user_ref = logged_in_user) {
        $cart->load(users_id => $user_ref->users_id,
                    session_id => session->id);
    }
    else {
        $cart->load(session_id => session->id);
    }

    return $cart;
};

sub _shop_resultset {
    my ($name, $key) = @_;

    if (defined $key) {
        return resultset($name)->find($key);
    }

    return resultset($name);
};

register_plugin;

=head1 ACKNOWLEDGEMENTS

The L<Dancer> developers and community for their great application framework
and for their quick and competent support.

=head1 LICENSE AND COPYRIGHT

Copyright 2010-2013 Stefan Hornburg (Racke).

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=head1 SEE ALSO

L<Interchange6>, L<Interchange6::Schema>

=cut

1;
