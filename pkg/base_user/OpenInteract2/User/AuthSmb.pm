package OpenInteract2::User::AuthSmb;

# $Id: AuthSmb.pm,v 1.8 2005/03/18 04:09:46 lachoy Exp $

# Note: You MUST specify OpenInteract2::User in your object's 'isa'

use strict;
use base qw( OpenInteract2::User );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

# We create these constants since as of v. 0.91 the exported constants
# are broken in Authen::Smb

use constant SMB_NO_ERROR       => 0;
use constant SMB_SERVER_ERROR   => 1;
use constant SMB_PROTOCOL_ERROR => 2;
use constant SMB_LOGON_ERROR    => 3;

$OpenInteract2::User::AuthSmb::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub check_password {
    my ( $self, $check_pw ) = @_;
    $log ||= get_logger( LOG_APP );

    return undef unless ( $check_pw );
    require Authen::Smb;
    my $conf = $self->CONFIG;
    my $PDC    = $conf->{smb_pdc};
    my $BDC    = $conf->{smb_bdc};
    my $DOMAIN = $conf->{smb_domain};
    $log->is_debug &&
        $log->debug( "Trying to check SMB password for ",
                     "[$self->{login_name}] using [PDC: $PDC] [BDC: $BDC] ",
                     "[DOMAIN: $DOMAIN]" );
    my $rv = Authen::Smb::authen( $self->{login_name}, $check_pw,
                                  $PDC, $BDC, $DOMAIN );
    return 1 if ( $rv == SMB_NO_ERROR );
    my $error_status = undef;
    $error_status = "Logon Error"     if ( $rv == SMB_LOGON_ERROR );
    $error_status = "Server Error"    if ( $rv == SMB_SERVER_ERROR );
    $error_status = "Protocol Error"  if ( $rv == SMB_PROTOCOL_ERROR );
    $log->error( "Error found trying to login: $error_status" );
    if ( $conf->{smb_use_internal_auth} ) {
        $log->is_debug &&
            $log->debug( "Internal password being checked since ",
                         "SMB check failed." );
        return $self->SUPER::check_password( $check_pw );
    }
    return undef;
}

1;

__END__

=head1 NAME

OpenInteract2::User::AuthSmb - Provide the means to authenticate OI users against a SMB domain

=head1 SYNOPSIS

 # In your conf/spops.perl

 'user' => {
   ...,
   code_class            => 'OpenInteract2::User::AuthSmb',
   isa                   => [ qw/ OpenInteract2::User ... / ],
   smb_pdc               => 'MyPDC',
   smb_bdc               => 'MyBDC',
   smb_domain            => 'MyNTDomain',
   smb_use_internal_auth => 1,
 }
 
 # Check a user's password in the code
 
 if ( $user->check_password( $password ) ) {
   print "User logged in!";
 }
 else {
   print "User cannot login: bad password or other error!";
 }

=head1 DESCRIPTION

This subclass of C<OpenInteract2::User> overrides the C<check_password>
method with one that authenticates against an SMB domain using the
L<Authen::Smb> module.

To use this module properly, you need to create a few configuration
settings to tell the module how to authenticate. The following keys
are necessary in the configuration file for your object
(conf/spops.perl):

=over 4

=item *

B<smb_pdc>: The Windows name of the Primary Domain Controller

=item *

B<smb_bdc>: The Windows name of the Backup Domain Controller (optional
as long as you are comfortable with a single point of failure).

=item *

B<smb_domain>: The name of the domain you are authenticating against.

=item *

B<smb_use_internal_auth>: If the password check fails for any reason,
try to use the normal OpenInteract method for checking passwords. A
true value enables this behavior, a false value disables it.

=back

In your C<conf/spops.perl> you also need to modify:

=over 4

=item *

B<isa>: Add C<OpenInteract2::User> to the beginning of your 'isa' list

=item *

B<code_class>: Set to C<OpenInteract2::User::AuthSmb>.

=back

=head1 OBJECT METHODS

B<check_password( $pw )>

Overrides the method found in C<OpenInteract2::User>.

Returns a 1 if the authentication is successful, undef if not.

=head1 TO DO

B<Other tests>

It would be great if this could be tested against various SMB
authentication scenarios. I have only been able to do so against an
NT4 domain -- testing in an internal workgroup network, against a
Samba server or other sources would be excellent.

=head1 BUGS

B<Need to List SMB Hosts in /etc/hosts>

Under Unix systems, the module L<Authen::Smb|Authen::Smb> seems to
require you to list your PDC/BDC by the Windows (WINS) names in the
'/etc/hosts' file. For example:

 192.168.1.20	   mypdc.myco.com	mypdc
 192.168.1.21	   mybdc.myco.com	mybdc

In configuration:

 ...
 smb_pdc => 'mypdc',
 smb_bdc => 'mybdc',
 ...

B<Changing Passwords via Web>

(not really a bug, more of a notice)

When a user changes his/her password via the web form, he/she is
changing the password in the B<internal OpenInteract database>, not on
the SMB server. Such a capability is (I think) beyond the means of
mere mortals, unless MS decides to open up their administration
scheme...

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

Thanks to Optiron, Inc. (http://www.optiron.com/) for donating the
time necessary to create and test this module.
