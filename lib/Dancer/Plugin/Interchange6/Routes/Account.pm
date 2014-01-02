package Dancer::Plugin::Interchange6::Routes::Account;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Plugin::Interchange6;
use Dancer::Plugin::Auth::Extensible;

=head1 NAME

Dancer::Plugin::Interchange6::Routes::Account - Account routes for Interchange6 Shop Machine

=head1 DESCRIPTION

The Interchange6 account routes module installs Dancer routes for
login and logout

=cut

register_hook 'before_login_display';

=head1 FUNCTIONS

=head2 account_routes

Returns the account routes based on the passed routes configuration.

=cut

sub account_routes {
    my $routes_config = shift;
    my %routes;

    $routes{login}->{get} = sub {
        return redirect '/' if logged_in_user;

        my %values;

        # call before_login_display route so template tokens
        # can be injected
        execute_hook('before_login_display', \%values);
        template $routes_config->{account}->{login}->{template}, \%values;
    };

    $routes{login}->{post} = sub {
        return redirect '/' if logged_in_user;

        my $login_route = '/' . $routes_config->{account}->{login}->{uri};

        my $user = shop_user->find({ username => params->{username}});

        my ($success, $realm, $current_cart);

        if ($user) {
            # remember current cart object
            $current_cart = shop_cart;

            ($success, $realm) = authenticate_user( params->{username}, params->{password} );
        }

        if ($success) {
            session logged_in_user => $user->username;
            session logged_in_user_id => $user->id;
            session logged_in_user_realm => $realm;

            if (! $current_cart->users_id) {
                $current_cart->users_id($user->id);
            }

            return redirect '/' . $routes_config->{account}->{login}->{success_uri};
        } else {
            debug "Authentication failed for ", params->{username};

            var login_failed => 1;
            return forward $login_route, { return_url => params->{return_url} }, { method => 'get' };
        }
    };

    $routes{logout}->{any} = sub {
        shop_cart->sessions_id(undef);
        session->destroy;
        return redirect '/';
    };

    return \%routes;
}

true;
