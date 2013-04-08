package Amon2::Web::Dispatcher::RouterSimple::Extended;
use strict;
use warnings;

our $VERSION = "0.01";

use Router::Simple 0.03;

sub import {
    my $class = shift;
    my %args = @_;
    my $caller = caller(0);

    my $router = Router::Simple->new;

    my $connect = sub {
        if (@_ == 2 && !ref $_[1]) {
            my ($path, $dest_str, $opt) = @_;
            my ($controller, $action) = split('#', $dest_str);
            my $dest = { controller => $controller };
            $dest->{action} = $action if defined $action;
            $router->connect($path, $dest, $opt || {});
        } else {
            $router->connect(@_);
        }
    };

    no strict 'refs';

    # functions
    *{"${caller}::connect"} = $connect;
    my @methods = qw/GET POST PUT DELETE/;
    my %procs;
    for my $method (@methods) {
        *{"${caller}::@{[lc $method]}"} = $procs{$method} = sub {
            $connect->($_[0], $_[1], { method => $method });
        };
    }

    use strict 'refs';

    my $submapper = sub {
        if ($_[2] && ref($_[2]) eq 'CODE') {
            my ($path, $controller, $callback) = @_;
            my $submap = $router->submapper($path, { controller => $controller });
            my $new_connect = sub {
                if (@_ >= 2 && !ref $_[1]) {
                    my ($path, $action, $opt) = @_;
                    $submap->connect($path, { action => $action }, $opt || {});
                } else {
                    $submap->connect(@_);
                }
            };
            no strict 'refs';
            no warnings 'redefine';
            *{"${caller}::connect"} = $new_connect;
            for my $method (@methods) {
                *{"${caller}::@{[lc $method]}"} = sub {
                    my ($path, $action) = @_;
                    $submap->connect($path, { action => $action }, { metod => $method });
                };
            }
            use strict 'refs';
            use warnings 'redefine';
            $callback->();
            no strict 'refs';
            no warnings 'redefine';
            *{"${caller}::connect"} = $connect;
            *{"${caller}::@{[ lc $_ ]}"} = $procs{$_} for (@methods);
        }
        else {
            $router->submapper(@_);
        }
    };

    no strict 'refs';

    *{"${caller}::submapper"} = $submapper;
    # class methods
    *{"${caller}::router"} = sub { $router };
    for my $meth (qw/match as_string/) {
        *{"$caller\::${meth}"} = sub {
            my $self = shift;
            $router->$meth(@_)
        };
    }
    *{"$caller\::dispatch"} = \&_dispatch;
}

sub _dispatch {
    my ($class, $c) = @_;
    my $req = $c->request;
    if (my $p = $class->match($req->env)) {
        my $action = $p->{action};
        $c->{args} = $p;
        "@{[ ref Amon2->context ]}::C::$p->{controller}"->$action($c, $p);
    } else {
        $c->res_404();
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Amon2::Web::Dispatcher::RouterSimple::Extended - extending Amon2::Web::Dispatcher::RouterSimple

=head1 SYNOPSIS


    package MyApp::Web::Dispatcher;
    use strict;
    use warnings;
    use utf8;
    use Amon2::Web::Dispatcher::RouterSimple::Extended;
    connect '/' => 'Root#index';
    # API
    submapper '/api/' => API => sub {
        get  'foo' => 'foo';
        post 'bar' => 'bar';
    };
    # user
    submapper '/user/' => User => sub {
        get     '',           'index';
        connect '{uid}',      'show';
        post    '{uid}/hoge', 'hoge';
        connect 'new',        'create';
    };
    1;

=head1 DESCRIPTION

This is an extension of Amon2::Web::Dispatcher::RouterSimple. 100% compatible, and it provides useful functions.


=head1 METHODS

=over 4

=item get $path, "${controller}#${action}"

this is equivalent to 'connect $path, { controller => $controller, action => $action }, { method => 'GET' };'

=item post $path, "${controller}#${action}"

this is equivalent to 'connect $path, { controller => $controller, action => $action }, { method => 'POST' };'

=item put $path, "${controller}#${action}"

this is equivalent to 'connect $path, { controller => $controller, action => $action }, { method => 'PUT' };'

=item delete $path, "${controller}#${action}"

this is equivalent to 'connect $path, { controller => $controller, action => $action }, { method => 'DELETE' };'

=item submapper $path, $controller, sub {}

this is main feature of this module. In subroutine of the third argument, connect/get/post/put/delete method fits in submapper. As a results, in submapper you can be described in the same interface. If this third argument not exists, this function behave in the same way as Amon2::Web::Dispatcher::RouterSimple.

=back


=head1 LICENSE

Copyright (C) taiyoh

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

taiyoh

=head1 SEE ALSO

L<Amon2::Web::Dispatcher::RouterSimple>
