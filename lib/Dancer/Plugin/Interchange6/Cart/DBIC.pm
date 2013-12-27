package Dancer::Plugin::Interchange6::Cart::DBIC;

use strict;
use warnings;

=head1 NAME

Dancer::Plugin::Interchange6::Cart::DBIC - DBIC cart backend for Interchange6

=cut

use Dancer qw/session hook/;
use Dancer::Plugin::DBIC;

use base 'Interchange6::Cart';

=head1 METHODS

=head2 init

=cut

sub init {
    my ($self, %args) = @_;
    my (%q_args);

    if ($args{settings}->{log_queries}) {
	$q_args{log_queries} = sub {
	    Dancer::Logger::debug(@_);
	};
    };

    $self->{session_id} = $args{session_id} || '';
    $self->{settings} = $args{settings} || {};
    $self->{sqla} = schema('default');
    
    hook 'after_cart_add' => sub {$self->_after_cart_add(@_)};
    hook 'after_cart_update' => sub {$self->_after_cart_update(@_)};
    hook 'after_cart_remove' => sub {$self->_after_cart_remove(@_)};
    hook 'after_cart_rename' => sub {$self->_after_cart_rename(@_)};
    hook 'after_cart_clear' => sub {$self->_after_cart_clear(@_)};
}

=head2 load

Loads cart from database. 

=cut

sub load {
    my ($self, %args) = @_;
    my ($uid, $name, $result, $code);

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
    elsif ($args{session_id}) {
        # determine cart code (from session_id)
        $result = $self->{sqla}->resultset('Cart')->search({'me.name' => $self->name, 'me.sessions_id' => $args{session_id}});
        if ($result->count > 0) {
            $code = $result->next->id;
        }
    }

    unless ($code) {
        $self->{id} = 0;
        return;
    }
    $self->{id} = $code;

    $self->_load_cart($result);
}

=head2 id

Return cart identifier.

=cut

sub id {
    my $self = shift;

    if (@_ && defined ($_[0])) {
        my $id = $_[0];

        if ($id =~ /^[0-9]+$/) {
            $self->{id} = $id;
            $self->_load_cart;
        }
    }
    elsif (! $self->{id}) {
        # forces us to create entry in cart table
        $self->_create_cart;
    }

    return $self->{id};
}

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

    %cart = (name => $self->name,
             created => $self->created,
             last_modified => $self->last_modified,
             sessions_id => $self->{session_id},
             );

    if (defined $self->{users_id}) {
        $cart{users_id} = $self->{users_id};
    }

    my $rs = resultset('Cart')->create(\%cart);
    
    Dancer::Logger::debug("New cart: ", $rs->id, " => ", \%cart);

    $self->{id} = $rs->id;
}

# loads cart from database
sub _load_cart {
    my ($self, $result) = @_;
    my ($record, @items);

    # retrieve items from database
    my $related = $result->search_related('CartProduct',
                                          {},
                                          {
                                           join => 'Product',
                                           prefetch => 'Product',
                                          })
        ;

    while (my $record = $related->next) {
        push @items, {sku => $record->Product->sku,
                      name => $record->Product->name,
                      price => $record->Product->price,
                      quantity => $record->quantity,
                      };
    }

    $self->seed(\@items);
}

sub _find_and_update {
    my ($self, $sku, $new_item) = @_;

    my $cp = $self->{sqla}->resultset('CartProduct')->find({carts_id => $self->{id},
                                                            sku => $sku});

    $cp->update($new_item);
}


# hook methods
sub _after_cart_add {
    my ($self, @args) = @_;
    my ($item, $update, $record);

    unless ($self eq $args[0]) {
	# not our cart
	return;
    }

    $item = $args[1];
    $update = $args[2];

    unless ($self->{id}) {
        $self->_create_cart;
    }

    # first check whether item exists
    if (! resultset('Product')->find($item->{sku})) {
        $self->{error} = ("Item $item->{sku} doesn't exist.");
        return;
    }

    if ($update) {
        # update item in database
        $record = {quantity => $item->{quantity}};
        $self->_find_and_update($item->{sku}, $record);
    }
    else {
        # add new item to database
        $record = {carts_id => $self->{id}, sku => $item->{sku}, quantity => $item->{quantity}, cart_position => 0};
        resultset('CartProduct')->create($record);
    }
}

sub _after_cart_update {
    my ($self, @args) = @_;
    my ($item, $new_item, $count);

    unless ($self eq $args[0]) {
	# not our cart
	return;
    }

    $item = $args[1];
    $new_item = $args[2];

    $self->_find_and_update($item->{sku}, $new_item);
}

sub _after_cart_remove {
    my ($self, @args) = @_;
    my ($item);

    unless ($self eq $args[0]) {
	# not our cart
	return;
    }

    $item = $args[1];

     my $cp = $self->{sqla}->resultset('CartProduct')->find({carts_id => $self->{id},
                                                            sku => $item->{sku}});
    $cp->delete;
}

sub _after_cart_rename {
    my ($self, @args) = @_;

    unless ($self eq $args[0]) {
	# not our cart
	return;
    }

    $self->{sqla}->resultset('Cart')->find($self->id)->update({name => $args[2]});
}

sub _after_cart_clear {
    my ($self, @args) = @_;

    unless ($self eq $args[0]) {
	# not our cart
	return;
    }

    # delete all products from this cart
    my $rs = $self->{sqla}->resultset('Cart')->search({'CartProduct.carts_id' => $self->{id}}, {join => 'CartProduct'})->delete_all;
}

=head1 AUTHOR

Stefan Hornburg (Racke), <racke@linuxia.de>

=head1 LICENSE AND COPYRIGHT

Copyright 2011-2013 Stefan Hornburg (Racke) <racke@linuxia.de>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
