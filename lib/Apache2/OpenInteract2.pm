package Apache2::OpenInteract2;

# $Id: OpenInteract2.pm,v 1.5 2005/03/18 04:09:48 lachoy Exp $

use strict;
use Apache::RequestRec ();
use Apache::URI ();
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Auth;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Request;
use OpenInteract2::Response;

$Apache2::OpenInteract2::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

my ( $log );
my ( $done );

sub handler : method {
    my ( $class, $r ) = @_;
    $log ||= get_logger( LOG_OI );
    unless ( $done ) {
        require APR::SockAddr;
        require Apache::Connection;
        $done++;
    }
    my $c = $r->connection->remote_addr;
    $log->is_info &&
        $log->info( scalar( localtime ), ": request from ",
                    "'", $c->ip_get, "' for URL ",
                    "'", $r->construct_url, '?', $r->args , "' ",
                    "running under '$ENV{MOD_PERL}'" );

    my $response = OpenInteract2::Response->new({ apache => $r });
    my $request  = OpenInteract2::Request->new({ apache => $r });

    # 1.x stuff
    #my $http_auth_user = $r->pnotes( 'login_user' );
    #my $auth = OpenInteract2::Auth->new({ user => $http_auth_user });

    OpenInteract2::Auth->new()->login();

    my $controller = eval {
        OpenInteract2::Controller->new( $request, $response )
    };
    if ( $@ ) {
        $response->content( $@ );
    }
    else {
        $controller->execute;
    }
    $response->send;
    return $response->status;
}

1;

__END__

=head1 NAME

Apache2::OpenInteract2 - OpenInteract2 Content handler for Apache 2.x

=head1 SYNOPSIS

 # Need to tell Apache to run an initialization script

 PerlRequire /path/to/my/site/conf/startup.pl

 # In httpd.conf file (or 'Include'd virtual host file)
 <Location />
    SetHandler perl-script
    PerlHandler Apache2::OpenInteract2
</Location>

=head1 DESCRIPTION

This external interface to OpenInteract2 just sets up the
L<OpenInteract2::Request|OpenInteract2::Request> and
L<OpenInteract2::Response|OpenInteract2::Response> objects, creates an
L<OpenInteract2::Controller|OpenInteract2::Controller> and retrieves
the content from it, then sets the content in the response and returns
the proper error code to make Apache2 happy.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
