package OpenInteract2::Constants;

# $Id: Constants.pm,v 1.11 2005/03/18 04:09:48 lachoy Exp $

use strict;
use base qw( Exporter );

$OpenInteract2::Constants::VERSION  = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

# TODO: Are these used?

use constant OI_OK       => 1;
use constant OI_REDIRECT => 3;
use constant OI_DECLINED => 4;
use constant OI_STOP     => 5;
use constant OI_ERROR    => 255;
my @OI_STATUS = qw( OI_OK OI_REDIRECT OI_DECLINED OI_STOP OI_ERROR );

use constant LALL   => 50;
use constant LDEBUG => 5;
use constant LINFO  => 4;
use constant LWARN  => 3;
use constant LERROR => 2;
use constant LFATAL => 1;
use constant LOFF   => 0;
my @LOG_LEVEL = qw( LALL LDEBUG LINFO LWARN LERROR LFATAL LOFF );

# Log4perl categories

use constant LOG_OI        => 'OI2';
use constant LOG_ACTION    => 'OI2.ACTION';
use constant LOG_APP       => 'OI2.APP';
use constant LOG_AUTH      => 'OI2.AUTH';
use constant LOG_CACHE     => 'OI2.CACHE';
use constant LOG_CONFIG    => 'OI2.CONFIG';
use constant LOG_DS        => 'OI2.DATASOURCE';
use constant LOG_INIT      => 'OI2.INITIALIZE';
use constant LOG_REQUEST   => 'OI2.REQUEST';
use constant LOG_RESPONSE  => 'OI2.RESPONSE';
use constant LOG_SECURITY  => 'OI2.SECURITY';
use constant LOG_SESSION   => 'OI2.SESSION';
use constant LOG_SPOPS     => 'OI2.SPOPS';
use constant LOG_TEMPLATE  => 'OI2.TEMPLATE';
use constant LOG_TRANSLATE => 'OI2.TRANSLATE';
my @LOG_CATEGORY = qw(
    LOG_OI LOG_ACTION LOG_APP LOG_AUTH LOG_CACHE LOG_CONFIG
    LOG_DS LOG_INIT LOG_REQUEST LOG_RESPONSE LOG_SESSION
    LOG_SECURITY LOG_SPOPS LOG_TEMPLATE LOG_TRANSLATE
);

use constant BOOTSTRAP_CONF_DIR  => 'conf';
use constant BOOTSTRAP_CONF_FILE => 'bootstrap.ini';
my @FILE = qw( BOOTSTRAP_CONF_DIR BOOTSTRAP_CONF_FILE );

use constant ACTION_KEY     => 'ACTION';
use constant REQUEST_KEY    => 'REQUEST';
use constant RESPONSE_KEY   => 'RESPONSE';
my @TEMPLATE_KEYS = qw( ACTION_KEY REQUEST_KEY RESPONSE_KEY );

use constant SESSION_COOKIE => 'oi2ssn';

@OpenInteract2::Constants::EXPORT_OK   = (
        @OI_STATUS, @LOG_LEVEL, @LOG_CATEGORY, @FILE, @TEMPLATE_KEYS, 'SESSION_COOKIE',
);
%OpenInteract2::Constants::EXPORT_TAGS = (
    'all'      => [ @OpenInteract2::Constants::EXPORT_OK ],
    'oi'       => [ @OI_STATUS ],
    'log'      => [ @LOG_LEVEL, @LOG_CATEGORY ],
    'file'     => [ @FILE ],
    'template' => [ @TEMPLATE_KEYS ],
);

1;

__END__

=head1 NAME

OpenInteract2::Constants - Define codes used throughout OpenInteract

=head1 SYNOPSIS

 # Just bring in a couple
 
 use OpenInteract2::Constants qw( OI_OK OI_ERROR LOG_ACTION );
 
 # Bring in all OI status constants
 
 use OpenInteract2::Constants qw( :oi );
 
 # Bring in all logging constants
 
 use OpenInteract2::Constants qw( :log );
 
 # Open the gates, bring them all in
 
 use OpenInteract2::Constants qw( :all );
 
 # Using constants when generating content
 
 sub blah {
   return ( "I'm the man!", OI_OK );
 }
 
 sub barf {
   return ( "So it goes, I've failed", OI_ERROR );
 }

=head1 DESCRIPTION

This module defines constants used throughout OpenInteract. Most often
you will see the various status constants returned from actions that
generate content.

=head2 Logging Constants

The different logging levels are listed below in order from highest to
lowest. The low levels include all other levels above them. See
L<OpenInteract2::Context|OpenInteract2::Context> for how the different
levels are used in conjunction with the C<log()> method of the context
object.

B<LALL>

The C<LALL> level has the highest possible rank and is intended to turn
on all logging.

B<LDEBUG>

The C<LDEBUG> level designates fine-grained informational events that
are most useful to debug an application.

B<LINFO>

The C<LINFO> level designates informational messages that highlight
the progress of the application at coarse-grained level.

B<LWARN>

The C<LWARN> level designates potentially harmful situations.

B<LERROR>

The C<LERROR> level designates error events that might still allow the
application to continue running.

B<LFATAL>

The C<LFATAL> level designates very severe error events that will
presumably lead the application to abort.

B<LOFF>

The C<LOFF> level has the lowest possible rank and is intended to
turn off logging.

=head2 File Constants

These are default filenames and directories for various items in OI2:

B<BOOTSTRAP_CONF_DIR>: This is the default directory under the website where
you can find the bootstrap configuration. This is normally 'conf'.

B<BOOTSTRAP_CONF_FILE>: This is the default filename for the
bootstrap configuration. It is normally 'bootstrap.ini'.

=head2 Template Keys

Agreed-upon strings used for storing standard items in template
variables.

B<ACTION_KEY>: Retrieve the action spawning this generation request

B<REQUEST_KEY>: Retrieve the L<OpenInteract2::Request|OpenInteract2::Request> object

B<RESPONSE_KEY>: Retrieve the L<OpenInteract2::Response|OpenInteract2::Response> object

TODO: Do we need request/response?

=head1 METHODS

None, just exported constants.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
