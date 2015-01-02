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
use Dancer::Plugin;
use Dancer::Plugin::Auth::Extensible;
use Dancer::Plugin::DBIC;
use Scalar::Util 'blessed';
use Try::Tiny;

use Moo;
use Interchange6::Types;
extends 'Interchange6::Cart';

use namespace::clean;

=head1 ATTRIBUTES

See L<Interchange6::Cart/ATTRIBUTES> for a full list of attributes
inherited by this module.

=head2 database

The database name as defined in the L<Dancer::Plugin::DBIC> configuration.

Attribute is required.

=cut

has database => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

=head2 sessions_id

Extends inherited sessions_id attribute.

Attribute is required.

=cut

has '+sessions_id' => ( required => 1, );

=head1 METHODS

See L<Interchange6::Cart/METHODS> for a full list of methods inherited by
this module.

=head2 get_sessions_id

=head2 BUILDARGS

Sets default values for name, database and sessions_id if not given and
loads other attribute values from DB cart. If DB cart does not exist then
create new one.

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

    $args{'id'} = $cart->carts_id;

    return \%args;
}

=head2 BUILD

Load existing cart from the database along with any products it contains and add cart hooks.

=cut

sub BUILD {
    my $self = shift;
    my ( @products, $roles );

    my $rset = schema( $self->database )->resultset('Cart')->find(
        {
            name        => $self->name,
            sessions_id => $self->sessions_id,
        },
        { key => 'carts_name_sessions_id' }
      )
      ->search_related( 'cart_products', {},
        { join => 'product', prefetch => 'product', } );

    if (logged_in_user) {
        $roles = user_roles;
        push @$roles, 'authenticated';
    }

    while ( my $record = $rset->next ) {

        push @products,
          {
            id            => $record->cart_products_id,
            sku           => $record->sku,
            name          => $record->product->name,
            quantity      => $record->quantity,
            price         => $record->product->price,
            uri           => $record->product->uri,
            selling_price => $record->product->selling_price(
                { quantity => $record->quantity, roles => $roles }
            ),
          };
    }

    # use seed to avoid hooks
    $self->seed( \@products );
}

=head1 METHODS

=head2 add

Add one or more products to the cart.

Possible arguments:

=over

=item * single product sku (scalar value)

=item * hashref with keys 'sku' and 'quantity' (quantity is optional and defaults to 1)

=item * an array reference of either of the above

=back

In list context returns an array of L<Interchange6::Cart::Product>s and in scalar context returns an array reference of the same.

=cut

around 'add' => sub {
    my ( $orig, $self, $args ) = @_;
    my ( @products, @ret );

    # convert to array reference if we don't already have one
    $args = [$args] unless ref($args) eq 'ARRAY';

    execute_hook( 'before_cart_add_validate', $self, $args );

    # basic validation + add each validated arg to @args

    foreach my $arg (@$args) {

        # make sure we have hasref
        unless ( ref($arg) eq 'HASH' ) {
            $arg = { sku => $arg };
        }

        die "Attempt to add product to cart without sku failed."
          unless defined $arg->{sku};

        my $result =
          schema( $self->database )->resultset('Product')->find( $arg->{sku} );

        die "Product with sku '$arg->{sku}' does not exist."
          unless defined $result;

        my $product = {
            name     => $result->name,
            price    => $result->price,
            sku      => $result->sku,
            uri      => $result->uri,
        };
        $product->{quantity} = $arg->{quantity}
          if defined( $arg->{quantity} );

        push @products, $product;
    }

    execute_hook( 'before_cart_add', $self, \@products );

    # add products to cart

    my $cart = schema( $self->database )->resultset('Cart')->find( $self->id );

    foreach my $product ( @products ) {

        # bubble up the add
        my $ret = $orig->( $self, $product );

        # update or create in db

        my $cart_product = $cart->cart_products->search(
            { carts_id => $self->id, sku => $product->{sku} },
            { rows     => 1 } )->single;

        if ( $cart_product ) {
            $cart_product->update({ quantity => $ret->quantity });
        }
        else {
            $cart_product = $cart->create_related(
                'cart_products',
                {
                    sku           => $ret->sku,
                    quantity      => $ret->quantity,
                    cart_position => 0,
                }
            );
        }

        # set selling_price

        my $query = { quantity => $ret->quantity };
        if ( logged_in_user ) {
            $query->{roles} = [ user_roles, 'authenticated' ];
        }
        $ret->selling_price( $cart_product->product->selling_price($query) );

        push @ret, $ret;
    }

    execute_hook( 'after_cart_add', $self, \@ret );

    return wantarray ? @ret : \@ret;
};

=head2 clear

Removes all products from the cart.

=cut

around clear => sub {
    my ( $orig, $self ) = @_;

    execute_hook( 'before_cart_clear', $self );

    $orig->( $self, @_ );

    # delete all products from this cart
    my $rs =
      schema( $self->database )->resultset('Cart')
      ->search( { 'cart_products.carts_id' => $self->id } )
      ->search_related( 'cart_products', {} )->delete_all;

    execute_hook( 'after_cart_clear', $self );

    return;
};

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
    )->search_related( 'cart_products', {}, );

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
            'cart_products',
            {},
            {
                join     => 'product',
                prefetch => 'product',
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

=head2 remove

Remove single product from the cart. Takes SKU of product to identify
the product.

=cut

around remove => sub {
    my ( $orig, $self, $arg ) = @_;

    execute_hook( 'before_cart_remove_validate', $self, $arg );

    my $index = $self->product_index( sub { $_->sku eq $arg } );

    die "Product sku not found in cart: $arg." unless $index >= 0;

    execute_hook( 'before_cart_remove', $self, $arg );

    my $ret = $orig->( $self, $arg );

    my $cp = schema( $self->database )->resultset('CartProduct')->find(
        {
            carts_id => $self->id,
            sku      => $ret->sku
        }
    );
    $cp->delete;

    execute_hook( 'after_cart_remove', $self, $arg );

    return $ret;
};

=head2 rename

Rename this cart. This is the writer method for L<Interchange6::Cart/name>.

Arguments: new name

Returns: cart object

=cut

around rename => sub {
    my ( $orig, $self, $new_name ) = @_;

    my $old_name = $self->name;

    execute_hook( 'before_cart_rename', $self, $old_name, $new_name );

    my $ret = $orig->( $self, $new_name );

    schema( $self->database )->resultset('Cart')->find( $self->id )
      ->update( { name => $new_name } );

    execute_hook( 'after_cart_rename', $ret, $old_name, $new_name );

    return $ret;
};

sub _find_and_update {
    my ( $self, $sku, $new_product ) = @_;

    my $cp = schema( $self->database )->resultset('CartProduct')->find(
        {
            carts_id => $self->id,
            sku      => $sku
        }
    );

    $cp->update($new_product);
}

=head2 set_sessions_id

Writer method for L<Interchange6::Cart/sessions_id>.

=cut

around set_sessions_id => sub {
    my ( $orig, $self, $arg ) = @_;

    execute_hook( 'before_cart_set_sessions_id', $self, $arg );

    my $ret = $orig->( $self, $arg );

    debug( "Change sessions_id of cart " . $self->id . " to: ", $arg );

    if ( $self->id ) {

        # cart is already in database so update sessions_id there
        schema( $self->database )->resultset('Cart')->find( $self->id )
          ->update($arg);
    }

    execute_hook( 'after_cart_set_sessions_id', $ret, $arg );

    return $ret;
};

=head2 set_users_id

Writer method for L<Interchange6::Cart/users_id>.

=cut

around set_users_id => sub {
    my ( $orig, $self, $arg ) = @_;

    execute_hook( 'before_cart_set_users_id', $self, $arg );

    debug("Change users_id of cart " . $self->id . " to: $arg");

    my $ret = $orig->( $self, $arg );

    if ( $self->id ) {
        # cart is already in database so update
        schema( $self->database )->resultset('Cart')->find( $self->id )
          ->update( { users_id => $arg } );
    }

    execute_hook( 'after_cart_set_users_id', $ret, $arg );

    return $ret;
};

=head2 update

Update quantity of products in the cart.

Parameters are pairs of SKUs and quantities, e.g.

  $cart->update(9780977920174 => 5,
                9780596004927 => 3);

Triggers before_cart_update and after_cart_update hooks.

A quantity of zero is equivalent to removing this product,
so in this case the remove hooks will be invoked instead
of the update hooks.

Returns updated products that are still in the cart. Products removed
via quantity 0 or products for which quantity has not changed will not
be returned.

=cut

around update => sub {
    my ( $orig, $self, @args ) = @_;
    my ( @products, $product, $new_product, $count );

  ARGS: while ( @args > 0 ) {

        my $sku = shift @args;
        my $qty = shift @args;

        die "Bad quantity argument to update: $qty" unless $qty =~ /^\d+$/;

        if ( $qty == 0 ) {

            # do remove instead of update
            $self->remove($sku);
            next ARGS;
        }

        execute_hook( 'before_cart_update', $self, $sku, $qty );

        my $ret = $orig->( $self, $sku => $qty );

        $self->_find_and_update( $sku, { quantity => $qty } );

        execute_hook( 'after_cart_update', $ret, $sku, $qty );
    }
};

=head1 HOOKS

The following hooks are available:

=over 4

=item before_cart_add_validate

Executed in L</add> before arguments are validated as being valid. Hook
receives the following arguments:

Receives: $cart, \%args

The args are those that were passed to L<add>.

Example:

    hook before_cart_add_validate => sub {
        my ( $cart, $args ) = @_;
        foreach my $arg ( @$args ) {
            my $sku = ref($arg) eq 'HASH' ? $arg->{sku} : $arg;
            die "bad product" if $sku eq "bad sku";
        }
    }

=item before_cart_add

Called in L</add> immediately before the products are added to the cart.

Receives: $cart, \@products

The products arrary ref contains simple hash references that will be passed
to L<Interchange6::Cart::Product/new>.

=item after_cart_add

Called in L</add> after products have been added to the cart.

Receives: $cart, \@product

The products arrary ref contains <Interchange6::Cart::Product>s.

=item before_cart_remove_validate

Called at start of L</remove> before arg has been validated.

Receives: $cart, $sku

=item before_cart_remove

Called in L</remove> before validated product is removed from cart.

Receives: $cart, $sku

=item after_cart_remove

Called in L</remove> after product has been removed from cart.

Receives: $cart, $sku

=item before_cart_update

Executed for each pair of sku/quantity passed to L<update> before the update is performed.

Receives: $cart, $sku, $quantity

=item after_cart_update

Executed for each pair of sku/quantity passed to L<update> after the update is performed.

Receives: $cart, $sku, $quantity

=item before_cart_clear

Executed in L</clear> before the clear is performed.

Receives: $cart

=item after_cart_clear

Executed in L</clear> after the clear is performed.

Receives: $cart

=item before_cart_set_users_id

Executed in L<set_users_id> before users_id is updated.

Receives: $cart, $userid

=item after_cart_set_users_id

Executed in L<set_users_id> after users_id is updated.

Receives: $cart, $userid

=item before_cart_set_sessions_id

Executed in L<set_sessions_id> before sessions_id is updated.

Receives: $cart, $sessionid

=item after_cart_set_sessions_id

Executed in L<set_sessions_id> after sessions_id is updated.

Receives: $cart, $sessionid

=item before_cart_rename

Executed in L</rename> before cart L<Interchange6::Cart/name> is updated.

Receives: $cart, $old_name, $new_name

=item after_cart_rename

Executed in L</rename> after cart L<Interchange6::Cart/name> is updated.

Receives: $cart, $old_name, $new_name

=back

=head1 AUTHORS

 Stefan Hornburg (Racke), <racke@linuxia.de>
 Peter Mottram (SysPete), <peter@sysnix.com>

=head1 LICENSE AND COPYRIGHT

Copyright 2011-2015 Stefan Hornburg (Racke) <racke@linuxia.de>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
