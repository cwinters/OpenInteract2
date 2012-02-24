package OpenInteract2::Log;

# $Id: Log.pm,v 1.8 2005/03/18 04:09:48 lachoy Exp $

use strict;
use base qw( Exporter );
use Log::Log4perl qw( :levels get_logger );
use Log::Log4perl::Appender;

@OpenInteract2::Log::EXPORT_OK = qw( uchk );
$OpenInteract2::Log::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);


# Create a logging message by treating the first argument as a sprintf
# string and the remainder of the arguments as the parameters to set,
# each of which will be undef-tested before processing

sub uchk {
    my ( $msg, @args ) = @_;
    return sprintf( $msg, map { ( defined $_ ) ? $_ : '' } @args );
}

my $DEFAULT_LEVEL     = $WARN;
my $DEFAULT_CONF_FILE = 'log4perl.conf';

sub init_from_website {
    my ( $class, $website_dir ) = @_;
    if ( -d $website_dir ) {
        my $conf_file = File::Spec->catfile(
                              $website_dir, 'conf', $DEFAULT_CONF_FILE );
        Log::Log4perl::init( $conf_file );
        return get_logger();
    }
    else {
        return $class->init_screen;
    }
}

sub init_file {
    my ( $class, $file, $level ) = @_;
    unless ( $file ) {
        return $class->init_screen( $level );
    }
    my $appender = Log::Log4perl::Appender->new(
                         'Log::Log4perl::Appender::File',
                         filename  => $file,
                         mode      => 'append',
                         autoflush => 1 );
    return $class->_create_with_appender( $appender, $level );
}

sub init_screen {
    my ( $class, $level ) = @_;
    my $appender = Log::Log4perl::Appender->new(
                         'Log::Log4perl::Appender::Screen' );
    return $class->_create_with_appender( $appender, $level );
}


sub _create_with_appender {
    my ( $class, $appender, $level ) = @_;
    $level ||= $DEFAULT_LEVEL;
    $appender->layout( $class->_get_default_layout() );
    my $log = Log::Log4perl->get_logger( '' );
    $log->level( $level );
    $log->add_appender( $appender );
    return $log;
}

sub _get_default_layout {
    require Log::Log4perl::Layout::PatternLayout;
    return Log::Log4perl::Layout::PatternLayout->new( "%d{HH:mm:ss} %p %c %C (%L) %m %n");
}

1;

__END__

=head1 NAME

OpenInteract2::Log - Initialization for log4p logger

=head1 SYNOPSIS

 # Use the log in a website
 OpenInteract2::Log->init_from_website( $website_dir );
  
 # Create a log on the fly, using the default level, saved to file
 # 'oi2_tests.log'
 my $logfile = 'oi2_tests.log';
 OpenInteract2::Log->init_file( $logfile );
 
 # Same, but using 'info' as level
 use Log::Log4perl qw( :levels );
 OpenInteract2::Log->init_file( $logfile, $INFO );
 
 # Create a log on the fly, sent to the screen
 OpenInteract2::Log->init_screen
 
 # Same, but using 'info' as level
 OpenInteract2::Log->init_screen( $INFO );

=head1 DESCRIPTION

This just contains some centralized initialization methods so that
L<Log::Log4perl|Log::Log4perl> is initialized and happy.

B<init_from_website( $website_dir )>

Reads in the configuration file at C<$website_dir/conf/log4perl.conf>
and initializes the logger with it.

B<init_file( $file, [ $root_logger_level ] )>

Initializes the root logger to append its messages to C<$file> at the
level C<$root_logger_level> (as exported by
L<Log::Log4perl|Log::Log4perl>. If the level is not provided '$WARN'
is used.

If C<$file> not given behaves as C<init_screen()>.

B<init_screen( [ $root_logger_level ] )>

Initializes the root logger to write its messages to the screen at the
level C<$root_logger_level> (as exported by
L<Log::Log4perl|Log::Log4perl>. If the level is not provided '$WARN'
is used.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
