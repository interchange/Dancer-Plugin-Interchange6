package Dancer::Plugin::Interchange6::Cart::DBIC;

use strict;
use warnings;

=head1 NAME

Dancer::Plugin::Interchange6::Cart::DBIC - DBIC cart backend for Interchange6

=cut

use Dancer qw/session hook/;
use Dancer::Plugin::DBIC;
use Moo;
use Interchange6::Types;

extends 'Interchange6::Cart';

use namespace::clean;

=head1 METHODS

=cut

has settings => (
    is => 'rw',
    isa => HashRef,
    default => sub { {} },
);

has sqla => (
    is => 'rw',
    default => sub { schema('default') },
);

sub BUILD {
    my $self = shift;
    hook 'after_cart_add' => sub {$self->_after_cart_add(@_)};
    hook 'after_cart_update' => sub {$self->_after_cart_update(@_)};
    hook 'after_cart_remove' => sub {$self->_after_cart_remove(@_)};
    hook 'after_cart_rename' => sub {$self->_after_cart_rename(@_)};
    hook 'after_cart_clear' => sub {$self->_after_cart_clear(@_)};
    hook 'after_cart_set_users_id' => sub {$self->_after_cart_set_users_id(@_)};
    hook 'after_cart_set_sessions_id' => sub {$self->_after_cart_set_sessions_id(@_)};
}

sub init {
    my ($self, %args) = @_;
    my (%q_args);

    if ($args{settings}->{log_queries}) {
	$q_args{log_queries} = sub {
	    Dancer::Logger::debug(@_);
	};
    };

}

sub execute_hook {
    my $self = shift;
    Dancer::Factory::Hook->instance->execute_hooks(@_);
}

=head2 load

Loads cart from database. 

=cut

sub load {
    my ($self, %args) = @_;
    my ($uid, $name, $result, $code);

    Dancer::Logger::debug "in sub load";

    # check whether user is authenticated or not
    $uid = $args{users_id};

    if ($uid) {
        $self->{users_id} = $args{users_id};

        # determine cart code (from uid)
        $result = $self->{sqla}->resultset('Cart')->search({'me.name' => $self->name, 'me.users_id' => $args{users_id}});

        if ($result->count > 0) {
            $code = $result->next->id;
        }
    }
    elsif ($args{sessions_id}) {
        # determine cart code (from sessions_id)
        $result = $self->{sqla}->resultset('Cart')->search({'me.name' => $self->name, 'me.sessions_id' => $args{sessions_id}});
        if ($result->count > 0) {
            $code = $result->next->id;
        }
    }

    unless ($code) {
        $self->id;
        return;
    }
    $self->id($code);

    $self->_load_cart($result);
}

=head2 id

Return cart identifier.

=cut

around id => sub {
    my ( $orig, $self, $id ) = @_;

    Dancer::Logger::debug "in around id";

    if ($id && defined($id) && $id =~ /^[0-9]+$/) {
        $id = $orig->($self, $id);
    }
    else {
        $id = $orig->($self);
    }
    unless ( $id ) {

        # still no id - must be no cart so create one
        $self->_create_cart;
        $id = $orig->($self);
    }

    Dancer::Logger::debug "cart id is: $id";

    return $id;
};

=head2 save

No-op, as all cart changes are saved through hooks to the database.

=cut

sub save {
    return 1;
}

# creates cart in database
sub _create_cart {
    my $self = shift;
    my %cart;

    Dancer::Logger::debug "in sub _create_cart";

    %cart = (name => $self->name,
             created => $self->created,
             last_modified => $self->last_modified,
             sessions_id => $self->sessions_id,
             );

    if (defined $self->users_id) {
        $cart{users_id} = $self->users_id;
    }

    my $rs = resultset('Cart')->create(\%cart);
    
    Dancer::Logger::debug("New cart: ", $rs->id, " => ", \%cart);

    $self->id($rs->id);
}

# loads cart from database
sub _load_cart {
    my ($self, $result) = @_;
    my ($record, @products);

    Dancer::Logger::debug "in sub _load_cart";

    # retrieve products from database
    my $related = $result->search_related('CartProduct',
                                          {},
                                          {
                                           join => 'Product',
                                           prefetch => 'Product',
                                          })
        ;

    while (my $record = $related->next) {
        push @products, {sku => $record->Product->sku,
                      name => $record->Product->name,
                      price => $record->Product->price,
                      #uri => $record->Product->uri,
                      quantity => $record->quantity,
                      };
    }

    $self->seed(\@products);

}

sub _find_and_update {
    my ($self, $sku, $new_product) = @_;

    Dancer::Logger::debug "in sub _find_and_update";

    my $cp = $self->{sqla}->resultset('CartProduct')->find({carts_id => $self->{id},
                                                            sku => $sku});

    $cp->update($new_product);
}


# hook methods
sub _after_cart_add {
    my ($self, @args) = @_;
    my ($product, $update, $record);

    Dancer::Logger::debug "in sub _after_cart_add";

    unless ($self eq $args[0]) {
	# not our cart
	return;
    }

    $product = $args[1];
    $update = $args[2];

    unless ($self->id) {
        $self->_create_cart;
    }

    # first check whether product exists
    if (! resultset('Product')->find($product->{sku})) {
        $self->set_error("Item $product->{sku} doesn't exist.");
        return;
    }

    if ($update) {
        # update product in database
        $record = {quantity => $product->quantity};
        $self->_find_and_update($product->sku, $record);
    }
    else {
        # add new product to database
        $record = {carts_id => $self->id, sku => $product->{sku}, quantity => $product->{quantity}, cart_position => 0};
        resultset('CartProduct')->create($record);
    }
}

sub _after_cart_update {
    my ($self, @args) = @_;
    my ($product, $new_product, $count);

    Dancer::Logger::debug "in sub _after_cart_update";

    unless ($self eq $args[0]) {
	# not our cart
	return;
    }

    $product = $args[1];
    $new_product = $args[2];

    $self->_find_and_update($product->{sku}, $new_product);
}

sub _after_cart_remove {
    my ($self, @args) = @_;
    my ($product);

    Dancer::Logger::debug "in sub _after_cart_remove";

    unless ($self eq $args[0]) {
	# not our cart
	return;
    }

    $product = $args[1];

     my $cp = $self->{sqla}->resultset('CartProduct')->find({carts_id => $self->{id},
                                                            sku => $product->{sku}});
    $cp->delete;
}

sub _after_cart_rename {
    my ($self, @args) = @_;

    Dancer::Logger::debug "in sub _after_cart_rename";

    unless ($self eq $args[0]) {
	# not our cart
	return;
    }

    $self->{sqla}->resultset('Cart')->find($self->id)->update({name => $args[2]});
}

sub _after_cart_clear {
    my ($self, @args) = @_;

    Dancer::Logger::debug "in sub _after_cart_clear";

    unless ($self eq $args[0]) {
	# not our cart
	return;
    }

    # delete all products from this cart
    my $rs = $self->{sqla}->resultset('Cart')->search({'CartProduct.carts_id' => $self->id}, {join => 'CartProduct'})->delete_all;
}

sub _after_cart_set_users_id {
    my ($self, @args) = @_;

    Dancer::Logger::debug "in sub _after_cart_set_users_id";

    unless ($self eq $args[0]) {
        # not our cart
        return;
    }

    # skip if cart is not yet stored in the database
    return unless $self->id;

    # change users_id
    my $data = $args[1];

    Dancer::Logger::debug("Change users_id of $self->id to: ", $data);

    $self->{sqla}->resultset('Cart')->find($self->id)->update($data);
}

sub _after_cart_set_sessions_id {
    my ($self, @args) = @_;

    Dancer::Logger::debug "in sub _after_cart_set_sessions_id";

    unless ($self eq $args[0]) {
        # not our cart
        return;
    }

    # skip if cart is not yet stored in the database
    return unless $self->{id};

    # change sessions_id
    my $data = $args[1];

    Dancer::Logger::debug("Change sessions_id of $self->{id} to: ", $data);

    $self->{sqla}->resultset('Cart')->find($self->{id})->update($data);
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
