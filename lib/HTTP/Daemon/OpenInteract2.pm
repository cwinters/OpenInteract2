# $Id: OpenInteract2.pm,v 1.13 2005/03/18 04:09:48 lachoy Exp $

# This is just the daemon with a product token...

package HTTP::Daemon::OpenInteract2Daemon;

use strict;

use base qw( HTTP::Daemon );
use OpenInteract2::Context qw( CTX );

$HTTP::Daemon::OpenInteract2Daemon::VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub product_tokens {
    my ( $self ) = @_;
    return join( ' ', 'OpenInteract/ ', CTX->version,
                      $self->SUPER::product_tokens );
}

# Now the interesting stuff...

package HTTP::Daemon::OpenInteract2;

use strict;
use base qw( Class::Accessor::Fast Class::Observable );
use File::Basename           qw( dirname );
use File::Spec::Functions    qw( catfile );
use HTTP::Response;
use HTTP::Status;
use IO::File;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Auth;
use OpenInteract2::Config::IniFile;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Controller;
use OpenInteract2::DatasourceManager;
use OpenInteract2::File;
use OpenInteract2::Log;
use OpenInteract2::Request;
use OpenInteract2::Response;
use POSIX qw( WNOHANG setsid );

my $PID_FILE = 'oi2.pid';

$SIG{CHLD} = \&_reaper;
$SIG{TERM} = $SIG{INT} = sub { exit(0); };

my @FIELDS = qw(
    website_dir daemon daemon_config daemon_config_file
    deploy_url pid pid_file server_name static_path url
);
__PACKAGE__->mk_accessors( @FIELDS );

sub new {
    my ( $class, $params ) = @_;
    my $website_dir = $params->{website_dir};
    unless ( $website_dir and -d $website_dir ) {
        die "Parameter 'website_dir' must refer to an existing directory\n";
    }
    my $self = bless( {}, $class );
    foreach my $field ( @FIELDS ) {
        next unless ( $params->{ $field } );
        $self->$field( $params->{ $field } );
    }
    $self->_init_oi2_base;
    $self->_init_read_daemon_options;
    $self->_init_create_daemon;
    $self->_init_environment;
    $self->_start_daemon;
    return $self;
}

sub accept {
    my ( $self ) = @_;
    return $self->daemon->accept;
}

sub close {
    my ( $self ) = @_;
    return $self->daemon->close;
}

sub interact {
    my ( $self, $client ) = @_;
    $log ||= get_logger( LOG_OI );

    my $deploy_url = $self->deploy_url;

    $log->is_info &&
        $log->info( "New client attached from: ", $client->peerhost );

REQUEST:
    while ( my $lwp_request = $client->get_request ) {
        my $path = $lwp_request->uri->path;
        $log->info( "Client request: '$path'" );

        # HEAD requests (who cares?)
        if ( $lwp_request->method eq 'HEAD' ) {
            my $lwp_response = HTTP::Response->new( RC_OK );
            $client->send_response( $lwp_response );
            $log->info( "Sent HEAD response ok" );
        }

        # Static requests
        elsif ( $self->_is_static_path( $path ) ) {
            my $lwp_response = $self->_get_static_response( $path );
            $client->send_response( $lwp_response );
            $log->info( "Sent static file corresponding to '$path' ok" );
        }

        # OI2 requests
        elsif ( ! $deploy_url or ( $deploy_url and $path =~ /^$deploy_url/ ) ) {
            my $response = OpenInteract2::Response->new(
                                   { client => $client });
            my $request  = OpenInteract2::Request->new(
                                   { client      => $client,
                                     request     => $lwp_request,
                                     server_name => $self->server_name } );
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
            eval {
                $response->send;
            };
            if ( $@ ) {
                $log->logcroak( "Caught error from response: $@" );
            }
            else {
                $log->info( "Sent OI request for '$path' ok" );
            }
        }

        # Non-deployment context requests
        else {
            my $lwp_response = $self->_get_non_context_response( $path );
            $client->send_response( $lwp_response );
            warn "daemon: Sent non context response to '$path' ",
                 "'Deploy: $deploy_url' ok\n";
        }
    }
    $log->info( "Client finished." );
}

########################################
# INITIALIZATION

sub _init_oi2_base {
    my ( $self ) = @_;
    OpenInteract2::Log->init_from_website( $self->website_dir );
    my $ctx = OpenInteract2::Context->create(
        { website_dir => $self->website_dir });
    $ctx->assign_request_type( 'lwp' );
    $ctx->assign_response_type( 'lwp' );
    $self->deploy_url( $ctx->DEPLOY_URL );
}

sub _init_read_daemon_options {
    my ( $self ) = @_;

    # Already done?
    my $config = $self->daemon_config;
    return if ( ref $config eq 'HASH' and scalar keys %{ $config } );

    my $daemon_config_file = $self->daemon_config_file;
    unless ( $daemon_config_file ) {
        $daemon_config_file = catfile( $self->website_dir,
                                       'conf', 'oi2_daemon.ini' );
        $self->notify_observers(
                'log', "Using daemon configuration from website directory" );
        $self->daemon_config_file( $daemon_config_file );
    }
    $config = OpenInteract2::Config::IniFile->read_config({
        filename => $self->daemon_config_file });
    unless ( ref $config->{socket} eq 'HASH' ) {
        die "No options specified under 'socket' section of ",
            "configuration file '", $self->daemon_conf_file, "'\n";
    }
    return $self->daemon_config( $config );
}

sub _init_create_daemon {
    my ( $self ) = @_;
    unless ( ref $self->daemon_config->{socket} eq 'HASH' ) {
        die "Daemon configuration is not setup properly: no ",
            "entries under 'socket'\n";
    }
    my %socket_config = %{ $self->daemon_config->{socket} };
    my $daemon = HTTP::Daemon::OpenInteract2Daemon->new( %socket_config )
                    || die "Cannot create daemon! $!\n";
    $self->url( $daemon->url );
    $self->notify_observers(
        'log', "OpenInteract2 now running at URL '", $daemon->url, "'" );
    return $self->daemon( $daemon );
}

sub _init_environment {
    my ( $self ) = @_;

    # We need to close all database handle created in the
    # initialization process so the child doesn't try to use it.

    OpenInteract2::DatasourceManager->shutdown;

    # Entries in 'static_path' are not handled by OI2 (no security,
    # templating, etc.), we just give the file to the client.

    my $config = $self->daemon_config;
    if ( $config->{content}{static_path} ) {
        my @paths = ( ref $config->{content}{static_path} eq 'ARRAY' )
                      ? @{ $config->{content}{static_path} }
                      : ( $config->{content}{static_path} );
        $self->static_path( \@paths );
    }

    # The 'server.name' entry is used by OI as a replacement for the
    # server name reported by Apache/mod_perl in the 'ServerName'
    # directive

    $self->server_name( $config->{server}{name} );
}

sub _open_pid_file {
    my ( $self ) = @_;
    my $dir = dirname( $self->daemon_config_file );
    $log ||= get_logger( LOG_OI );

    my $full_pid_file = catfile( $dir, $PID_FILE );
    if ( -e $full_pid_file ) {
        my $fh = IO::File->new( $full_pid_file ) || return;
        my $pid = <$fh>;
        if ( $pid ) {
            if ( kill 0 => $pid ) {
                die "Server already running with PID '$pid'";
            }
            $log->info( "daemon: Removing PID file for defunct server process '$pid'" );
        }
        else {
            $log->info( "daemon: Removing empty stale PID file" );
        }
        unless ( -w $full_pid_file && unlink $full_pid_file ) {
            die "Cannot remove PID file '$full_pid_file'\n";
        }
    }
    $self->pid_file( $full_pid_file );
    return IO::File->new( $full_pid_file, O_WRONLY|O_CREAT|O_EXCL, 0644 )
                    || die "Cannot create PID file '$full_pid_file': $!";
}

sub _start_daemon {
    my ( $self ) = @_;
    my $fh = $self->_open_pid_file;
    my $pid = $self->_become_daemon;
    $self->pid( $pid );
    $fh->print( $pid );
    $fh->close();

}

sub _become_daemon {
    my ( $self ) = @_;
    my $child = fork();
    die "Cannot fork\n" unless ( defined $child );
    exit(0) if ( $child );
    setsid();
    open( STDIN,  "</dev/null" );
    open( STDOUT, ">daemon.log" );
    open( STDERR, ">&STDOUT" );
    chdir( '/' );
    umask(0);
    $ENV{PATH} = '/bin:/usr/bin:/sbin:/usr/sbin';
    return $$;
}

sub _reaper {
    $log ||= get_logger( LOG_OI );
    while ( my $kid = waitpid( -1, WNOHANG ) > 0 ) {
        $log->info( "Reaped child with PID '$kid'" );
    }
}

sub _is_static_path {
    my ( $self, $path ) = @_;
    my $static_paths = $self->static_path || [];
    foreach my $check_path ( @{ $static_paths } ) {
        if ( $path =~ /$check_path/ ) {
            return 1;
        }
    }
    return 0;
}

sub _get_static_response {
    my ( $self, $path ) = @_;
    $log ||= get_logger( LOG_OI );

    my @parts = split /\/+/, $path;
    my $file_path = catfile( CTX->lookup_directory( 'html' ), @parts );
    $log->debug( "Trying to map '$path' -> '$file_path'" );
    my ( $lwp_response );
    if ( -f $file_path ) {
        eval { open( STATIC, '<', $file_path ) || die $! };
        if ( $@ ) {
            $log->error( "Cannot open file '$file_path': $@" );
            $lwp_response = HTTP::Response->new( RC_INTERNAL_SERVER_ERROR );
            $lwp_response->content( "Failed to open file for request '$path'" );
        }
        else {
            $log->info( "Opened file '$file_path' ok" );
            $lwp_response = HTTP::Response->new( RC_OK );
            my $mime_type = OpenInteract2::File->get_mime_type(
                                   { filename => $file_path } );
            $log->debug( "Got MIME type '$mime_type' for file" );
            $lwp_response->content_type( $mime_type );
            my $file_length = (stat $file_path)[7];
            $log->debug( "Got file length '$file_length' for file" );
            $lwp_response->content_length( $file_length );

            # TODO: It would be nice to stream this instead...
            local $/ = undef;
            my $data = <STATIC>;
            CORE::close( STATIC );
            $lwp_response->content( $data );
        }
    }
    else {
        $log->error( "Cannot map static file to request '$path'" );
        $lwp_response = HTTP::Response->new( RC_NOT_FOUND );
        $lwp_response->content( "File not found for request '$path'" );
    }
    return $lwp_response;
}

sub _get_non_context_response {
    my ( $self, $path ) = @_;
    my $lwp_response = HTTP::Response->new( RC_OK );
    my $deploy_url = $self->deploy_url;
    my $invalid_page = <<INVALID;
<h1>Invalid Request</h1>
<p>This web server cannot fill your request for <b><tt>$path</tt></b>.
It can only serve requests under the URL space
<b><tt>$deploy_url</tt></b>. Good luck!</p>
INVALID
    $lwp_response->content( $invalid_page );
    $lwp_response->content_type( 'text/html' );
    return $lwp_response;
}

1;

__END__

=head1 NAME

HTTP::Daemon::OpenInteract2 - Standalone HTTP daemon for OpenInteract 2

=head1 SYNOPSIS

 my $daemon = HTTP::Daemon::OpenInteract2->new(
                  { website_dir => $website_dir });
 print "OpenInteract2 now running at URL '", $daemon->url, "'\n";
 
 while (1) {
     my $client = $daemon->accept;
     next unless ( $client );
     my $child = fork();
     unless ( defined $child ) {
         die "Cannot fork child: $!\n";
     }
     if ( $child == 0 ) {
         $daemon->interact( $client );
         $daemon->close;
         exit(0);
     }
     $client->close();
 }
 $daemon->run;

=head1 DESCRIPTION

This module uses L<HTTP::Daemon|HTTP::Daemon> to implement a
standalone web server running OpenInteract 2. Once it's started you
shouldn't be able to tell the difference between its OpenInteract or
the same application running on Apache, Apache2, or CGI -- it will
have the same users, hit the same database, manipulate the same
packages, etc.

The daemon will respect the application deployment context if
specified in the server configuration. Any request outside the context
will generate a simple error page explaining that it cannot be served.

B<Performance note>: this daemon will not win any speed contests. It
will work fine for a handful of users, but if you are seriously
deploying an application you should look strongly at Apache and
mod_perl.

=head1 CONFIGURATION

The configuration file is a simple INI file. Here's an example:

  [socket]
  LocalAddr = localhost	
  LocalPort = 8080	
  Proto     = tcp	
 
  [content]	
  static_path = ^/images
  static_path = \.(css|pdf|gz|zip|jpg|gif|png)$

The entries under 'socket' are passed without modification to the
constructor for L<HTTP::Daemon|HTTP::Daemon>, so if you have
specialized needs related to the network consult that documentation.

Currently only one item is supported in 'content': 'static_path'. Each
declaration tells the daemon that if the request URL matches the
regular expression to serve the file under the website HTML directory
directly rather than hitting OpenInteract2. For instance, in the given
configuration the requested path: C</images/oi_logo.gif> will cause
the daemon to look for the file:

  /path/to/mysite/html/images/oi_logo.gif	

and serve it as-is to the client. If the file is not found the client
gets a standard 404 message. If the file is found its content type is
determined by the routines in L<OpenInteract2::File|OpenInteract2::File>.

If you define a deployment context (e.g., '/intranet') you may need to
modify entries under 'static_path' to match. So if we deployed this
application under '/intranet' you would need to change the static path
'^/images' to '^/intranet/images'. keep the static path as '/images'.

You can have as many static path declarations as needed.

=head2 Tracking Running Server

The parent server stores its process ID (pid) in a file at
startup. This file is called C<oi2.pid> and is stored in the same
directory where the daemon configuration file is kept. You can also
access the filename from the daemon object (C<pid_file>) as well as
the pid (C<pid>).

=head1 SEE ALSO

L<HTTP::Daemon|HTTP::Daemon>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
