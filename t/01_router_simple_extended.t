use strict;
use warnings;
use Test::More;
use Test::Requires 'Test::WWW::Mechanize::PSGI';

{
    package MyApp;
    use parent qw/Amon2/;
}

{
    package MyApp::Web;
    use parent -norequire, qw/MyApp/;
    use parent qw/Amon2::Web/;
    sub dispatch { MyApp::Web::Dispatcher->dispatch(shift) }
}

{
    package MyApp::Web::C::My;
    sub foo { Amon2->context->create_response(200, [], 'foo') }

    sub bar { Amon2->context->create_response(200, [], 'bar') }

    package MyApp::Web::C::Bar;
    sub poo { Amon2->context->create_response(200, [], 'poo') }

    package MyApp::Web::C::Root;
    sub index { Amon2->context->create_response(200, [], 'top') }

    package MyApp::Web::C::Blog;
    sub monthly {
        my ($class, $c, $args) = @_;
        Amon2->context->create_response(200, [], "blog: $args->{year}, $args->{month}")
    }

    package MyApp::Web::C::Account;
    use strict;
    use warnings;
    sub login { $_[1]->create_response(200, [], 'login') }

    sub logout { $_[1]->create_response(200, [], 'logout') }

    package MyApp::Web::Dispatcher;
    use Amon2::Web::Dispatcher::RouterSimple::Extended;

    ::isa_ok __PACKAGE__->router(), 'Router::Simple';

    connect '/', {controller => 'Root', action => 'index'};
    connect '/my/foo', 'My#foo';
    connect '/bar/:action', 'Bar';
    connect '/blog/{year}/{month}', {controller => 'Blog', action => 'monthly'};
    submapper('/account/', {controller => 'Account'})
        ->connect('login', {action => 'login'});

    submapper '/account', 'Account', sub {
        get '/logout', 'logout';
    };

    get '/my/bar', 'My#bar';
}

my $app = MyApp::Web->to_app();

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);
$mech->get_ok('/');
$mech->content_is('top');
$mech->get_ok('/my/foo');
$mech->content_is('foo');
$mech->get_ok('/bar/poo');
$mech->content_is('poo');
$mech->get_ok('/blog/2010/04');
$mech->content_is("blog: 2010, 04");
$mech->get_ok('/account/login');
$mech->content_is("login");
$mech->get_ok('/account/logout');
$mech->content_is("logout");
$mech->get_ok('/my/bar');
$mech->content_is('bar');

done_testing;

