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

        if ( vars->{login_failed} ) {
            $values{error} = "Login failed";
        }

        # record return_url in template tokens
        if (my $return_url = param('return_url')) {
            $values{return_url} = $return_url;
        }

        # call before_login_display route so template tokens
        # can be injected
        execute_hook('before_login_display', \%values);

        # record return_url in the session to reuse it in post route
        session return_url => $values{return_url};

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

            # mitigate against session fixation attacks
            # http://owasp.com/index.php/Session_Management_Cheat_Sheet#Renew_the_Session_ID_After_Any_Privilege_Level_Change

            my $old_session_id = session->id;
            my $session_data = session;

            session->destroy;
            session->create;

            foreach my $key ( keys %$session_data ) {
                next if $key eq 'id'; # we don't want the old id
                session $key => $session_data->{$key};
            }

            # now we have a new session we need to update cart

            $current_cart->update({ sessions_id => session->id });

            # all done - carry on as normal

            session logged_in_user => $user->username;
            session logged_in_user_id => $user->id;
            session logged_in_user_realm => $realm;

            if (! $current_cart->users_id) {
                $current_cart->users_id($user->id);
            }

            # now pull back in old cart items from previous authenticated
            # sessions were sessions_id is undef in db cart
            $current_cart->load_saved_products;

            if ( session('return_url') ) {
                my $url = session('return_url');
                session return_url => undef;
                return redirect $url;
            }
            else {
                return redirect '/'
                  . $routes_config->{account}->{login}->{success_uri};
            }
        } else {
            debug "Authentication failed for ", params->{username};

            var login_failed => 1;
            return forward $login_route, { return_url => params->{return_url} }, { method => 'get' };
        }
    };

    $routes{logout}->{any} = sub {
        my $cart = cart;
        if ( $cart->count > 0 ) {
            # save our items for next login
            shop_cart->sessions_id(undef);
        }
        # any empty cart with sessions_id matching our session id will be
        # destroyed here
        session->destroy;
        return redirect '/';
    };

    return \%routes;
}

true;
