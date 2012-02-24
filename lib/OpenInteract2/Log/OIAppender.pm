package OpenInteract2::Log::OIAppender;

# $Id: OIAppender.pm,v 1.5 2005/03/17 14:58:02 sjn Exp $

use strict;
use DateTime;
use OpenInteract2::Context qw( CTX );
use OpenInteract2::ErrorStorage;

$OpenInteract2::Log::OIAppender::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub new {
    my ( $class ) = @_;
    return bless( {}, $class );
}

sub log {
    my ( $self, %params ) = @_;
    my ( $m_category, $m_class, $m_line, $m_msg ) =
        split /\s*&&\s*/, $params{message};

    # DO NOT log messages from OI2::ErrorStorage, otherwise we'll get
    # in an infinite loop...
    return if ( $m_class eq 'OpenInteract2::ErrorStorage' );

    $self->{store} = OpenInteract2::ErrorStorage->new();
    my %request_info = ();
    my $req = ( CTX ) ? CTX->request : undef;
    if ( $req ) {
        my $user = $req->auth_user;
        %request_info = (
            host     => $req->remote_host,
            user_id  => scalar( $user->id ),
            username => $user->login_name,
            session  => $req->session->{_session_id},
            browser  => $req->user_agent,
            referer  => $req->referer,
            url      => $req->url_absolute
        );
    }
    eval {
        $self->{store}->save({
            category => $m_category,
            class    => $m_class,
            line     => $m_line,
            message  => $m_msg,
            time     => ( CTX ) ? CTX->create_date() : DateTime->now(),
            %request_info,
        })
    };
    if ( $@ ) {
        warn "Failed to save error object: $@";
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Log::OIAppender - Appender to put error message in OI error log

=head1 SYNOPSIS

 # Define the appender -- any messages with ERROR or FATAL levels will
 # have an object created in the error log -- we depend on this
 # ConversionPattern!
  
 log4perl.appender.OIAppender                          = OpenInteract2::Log::OIAppender
 log4perl.appender.OIAppender.layout.ConversionPattern = %c && %C && %L && %m
 log4perl.appender.OIAppender.layout                   = Log::Log4perl::Layout::PatternLayout
 log4perl.appender.OIAppender.Threshold                = ERROR
 
 # Add the appender to the root category
 
 log4perl.logger = ERROR, FileAppender, OIAppender

=head1 DESCRIPTION

Capture certain errors for use by the OI error log. These errors get
serialized to disk -- see L<OpenInteract2::ErrorStorage> and
L<OpenInteract2::Error> for details.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

