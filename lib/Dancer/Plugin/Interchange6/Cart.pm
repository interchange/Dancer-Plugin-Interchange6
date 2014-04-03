use utf8;

package Dancer::Plugin::Interchange6::Cart;

=head1 NAME

Dancer::Plugin::Interchange6::Cart

=head1 DESCRIPTION

Extends L<Interchange6::Cart> to tie cart to L<Interchange6::Schema::Result::Cart>.

=cut

use strict;
use warnings;

use Dancer qw(:syntax !before !after);
use Dancer::Plugin::DBIC;

use Moo;
use Interchange6::Types;
extends 'Interchange6::Cart';

use namespace::clean;

=head1 ATTRIBUTES

=head2 database

The database name as defined in the L<Dancer::Plugin::DBIC> configuration.

Attribute is required.

=cut

has database => (
    is       => 'rw',
    isa      => Str,
    required => 1,
);

=head2 sessions_id

Extends inherited sessions_id attribute.

Attribute is required.

=cut

has '+sessions_id' => ( required => 1, );

=head1 INHERITED METHODS

=head2 get_sessions_id

=head2 BUILDARGS

Sets default values for name, database and sessions_id if not given and loads other attribute values from DB cart. If DB cart does not exist then create new one.

=cut

sub BUILDARGS {
    my $self = shift;

    my %args;

    # can be passed a hashref or a hash

    if ( @_ % 2 == 1 ) {

        # hashref
        %args = %{ $_[0] };
    }
    else {

        # hash
        %args = @_;
    }

    $args{'database'}    = 'default'   unless $args{'database'};
    $args{'name'}        = 'main'      unless $args{'name'};
    $args{'sessions_id'} = session->id unless $args{'sessions_id'};

    my $cart = schema( $args{'database'} )->resultset('Cart')->find_or_new(
        {
            name        => $args{'name'},
            sessions_id => $args{'sessions_id'},
        },
        { key => 'carts_name_sessions_id' }
    );

    if ( $cart->in_storage ) {
        debug( "Existing cart: ", $cart->carts_id, " ", $cart->name, "." );
    }
    else {
        $cart->insert;
        debug( "New cart ", $cart->carts_id, " ", $cart->name, "." );
    }

    $args{'created'}       = $cart->created;
    $args{'id'}            = $cart->carts_id;
    $args{'last_modified'} = $cart->last_modified;

    return \%args;
}

=head2 BUILD

Load existing cart from the database along with any products it contains and add cart hooks.

=cut

sub BUILD {
    my $self = shift;
    my @products;

    my $rset = schema( $self->database )->resultset('Cart')->find(
        {
            name        => $self->name,
            sessions_id => $self->sessions_id,
        },
        { key => 'carts_name_sessions_id' }
      )
      ->search_related( 'CartProduct', {},
        { join => 'Product', prefetch => 'Product', } );

    while ( my $record = $rset->next ) {

        push @products,
          {
            cart_products_id => $record->cart_products_id,
            sku              => $record->sku,
            name             => $record->Product->name,
            quantity         => $record->quantity,
            price            => $record->Product->price,
            uri              => $record->Product->uri,
          };
    }

    # use seed to avoid hooks
    $self->seed( \@products );

    # pull in hooks from Interchange6::Cart
    hook 'after_cart_add'    => sub { $self->_after_cart_add(@_) };
    hook 'after_cart_update' => sub { $self->_after_cart_update(@_) };
    hook 'after_cart_remove' => sub { $self->_after_cart_remove(@_) };
    hook 'after_cart_rename' => sub { $self->_after_cart_rename(@_) };
    hook 'after_cart_clear'  => sub { $self->_after_cart_clear(@_) };
    hook 'after_cart_set_users_id' =>
      sub { $self->_after_cart_set_users_id(@_) };
    hook 'after_cart_set_sessions_id' =>
      sub { $self->_after_cart_set_sessions_id(@_) };
}

=head1 METHODS

=head2 execute_hook

Ties Interchange6 hooks into Dancer's hook system.

=cut

sub execute_hook {
    my $self = shift;
    Dancer::Factory::Hook->instance->execute_hooks(@_);
}

=head2 load_saved_products

Pulls old cart items into current cart - used after user login.

=cut

sub load_saved_products {
    my ( $self, %args ) = @_;
    my ( $uid, $result, $code );

    # should not be called unless user is logged in
    return unless $self->users_id;

    # grab the resultset for current cart so we can update products easily if
    # we find old saved cart products

    my $current_cart_rs = schema( $self->database )->resultset('Cart')->search(
        {
            'me.name'        => $self->name,
            'me.users_id'    => $self->users_id,
            'me.sessions_id' => $self->sessions_id,
        }
    )->search_related( 'CartProduct', {}, );

    # now find old carts and see if they have products we should move into
    # our new cart + remove the old carts as we go

    $result = schema( $self->database )->resultset('Cart')->search(
        {
            'me.name'        => $self->name,
            'me.users_id'    => $self->users_id,
            'me.sessions_id' => [ undef, { '!=', $self->sessions_id } ],
        }
    );

    while ( my $cart = $result->next ) {

        my $related = $cart->search_related(
            'CartProduct',
            {},
            {
                join     => 'Product',
                prefetch => 'Product',
            }
        );
        while ( my $record = $related->next ) {

            # look for this sku in our current cart

            my $new_rs = $current_cart_rs->search( { sku => $record->sku } );

            if ( $new_rs->count > 0 ) {

                # we have this sku in our new cart so update quantity
                my $product = $new_rs->next;
                $product->update(
                    {
                        quantity => $product->quantity + $record->quantity
                    }
                );
            }
            else {

                # move product into new cart
                $record->update( { carts_id => $self->id } );
            }
        }

        # delete the old cart (cascade deletes related cart products)
        $cart->delete;
    }

}

sub _find_and_update {
    my ( $self, $sku, $new_product ) = @_;

    my $cp = schema( $self->database )->resultset('CartProduct')->find(
        {
            carts_id => $self->{id},
            sku      => $sku
        }
    );

    $cp->update($new_product);
}

# hook methods
sub _after_cart_add {
    my ( $self, @args ) = @_;
    my ( $product, $update, $record );

    unless ( $self eq $args[0] ) {

        # not our cart
        return;
    }

    $product = $args[1];
    $update  = $args[2];

    unless ( $self->id ) {
        $self->_create_cart;
    }

    # first check whether product exists
    if ( !resultset('Product')->find( $product->{sku} ) ) {
        $self->set_error("Item $product->{sku} doesn't exist.");
        return;
    }

    if ($update) {

        # update product in database
        $record = { quantity => $product->quantity };
        $self->_find_and_update( $product->sku, $record );
    }
    else {
        # add new product to database
        $record = {
            carts_id      => $self->id,
            sku           => $product->{sku},
            quantity      => $product->{quantity},
            cart_position => 0
        };
        resultset('CartProduct')->create($record);
    }
}

sub _after_cart_update {
    my ( $self, @args ) = @_;
    my ( $product, $new_product, $count );

    unless ( $self eq $args[0] ) {

        # not our cart
        return;
    }

    $product     = $args[1];
    $new_product = $args[2];

    $self->_find_and_update( $product->{sku}, $new_product );

    #session products => $self->products;
}

sub _after_cart_remove {
    my ( $self, @args ) = @_;
    my ($product);

    unless ( $self eq $args[0] ) {

        # not our cart
        return;
    }

    $product = $args[1];

    my $cp = schema( $self->database )->resultset('CartProduct')->find(
        {
            carts_id => $self->{id},
            sku      => $product->{sku}
        }
    );
    $cp->delete;
}

sub _after_cart_rename {
    my ( $self, @args ) = @_;

    unless ( $self eq $args[0] ) {

        # not our cart
        return;
    }

    schema( $self->database )->resultset('Cart')->find( $self->id )
      ->update( { name => $args[2] } );
}

sub _after_cart_clear {
    my ( $self, @args ) = @_;

    unless ( $self eq $args[0] ) {

        # not our cart
        return;
    }

    # delete all products from this cart
    my $rs =
      schema( $self->database )->resultset('Cart')
      ->search( { 'CartProduct.carts_id' => $self->id } )
      ->search_related( 'CartProduct', {} )->delete_all;
}

sub _after_cart_set_users_id {
    my ( $self, @args ) = @_;

    unless ( $self eq $args[0] ) {

        # not our cart
        return;
    }

    # skip if cart is not yet stored in the database
    return unless $self->id;

    # change users_id
    my $data = $args[1];

    Dancer::Logger::debug( "Change users_id of $self->id to: ", $data );

    schema( $self->database )->resultset('Cart')->find( $self->id )
      ->update($data);
}

sub _after_cart_set_sessions_id {
    my ( $self, @args ) = @_;

    unless ( $self eq $args[0] ) {

        # not our cart
        return;
    }

    # skip if cart is not yet stored in the database
    return unless $self->{id};

    # change sessions_id
    my $data = $args[1];

    Dancer::Logger::debug( "Change sessions_id of $self->{id} to: ", $data );

    schema( $self->database )->resultset('Cart')->find( $self->{id} )
      ->update($data);
}

=head1 AUTHOR

Stefan Hornburg (Racke), <racke@linuxia.de>

=head1 LICENSE AND COPYRIGHT

Copyright 2011-2014 Stefan Hornburg (Racke) <racke@linuxia.de>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
