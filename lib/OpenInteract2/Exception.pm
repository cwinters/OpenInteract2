package OpenInteract2::Exception;

# $Id: Exception.pm,v 1.12 2005/03/17 14:57:58 sjn Exp $

use strict;
use Carp qw( carp );

$OpenInteract2::Exception::VERSION   = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

# Declare some of our exceptions

use Exception::Class (
   'OpenInteract2::Exception::Application' => {
      isa         => 'OpenInteract2::Exception',
      description => 'Generic application errors',
      fields      => [ 'oi_package' ],
   },
   'OpenInteract2::Exception::Datasource' => {
      isa         => 'OpenInteract2::Exception',
      description => 'Datasource errors',
      fields      => [ 'datasource_name', 'datasource_type', 'connect_params' ],
   },
);

@OpenInteract2::Exception::ISA = qw( Exporter Exception::Class::Base );
@OpenInteract2::Exception::EXPORT_OK = qw(
    oi_error oi_app_error oi_datasource_error oi_param_error oi_security_error
);

require OpenInteract2::Exception::Parameter;
require OpenInteract2::Exception::Security;

# Exported shortcuts

sub oi_error {
#    carp "throwing oi_error...";
    my ( $msg, %params ) = _massage( @_ );
    goto &Exception::Class::Base::throw( __PACKAGE__,
                                         message => $msg, %params );
}

sub oi_app_error {
#    carp "throwing oi_app_error...";
    my ( $msg, %params ) = _massage( @_ );
    goto &Exception::Class::Base::throw( 'OpenInteract2::Exception::Application',
                                         message => $msg, %params );
}

sub oi_datasource_error {
#    carp "throwing oi_datasource_error...";
    my ( $msg, %params ) = _massage( @_ );
    goto &Exception::Class::Base::throw( 'OpenInteract2::Exception::Datasource',
                                         message => $msg, %params );
}

sub oi_param_error {
#    carp "throwing oi_param_error...";
    my ( $msg, %params ) = _massage( @_ );
    goto &Exception::Class::Base::throw( 'OpenInteract2::Exception::Parameter',
                                         message => $msg, %params );
}

sub oi_security_error {
#    carp "throwing oi_security_error...";
    my ( $msg, %params ) = _massage( @_ );
    goto &Exception::Class::Base::throw( 'OpenInteract2::Exception::Security',
                                         message => $msg, %params );
}

# Override 'throw' so we can massage the message and parameters into
# the right format for E::C

sub throw {
    my $class = shift @_;
    my ( $msg, %params ) = _massage( @_ );
    goto &Exception::Class::Base::throw( $class, message => $msg, %params );
}

sub _massage {
    my @items = @_;
    my %params = ( ref $items[-1] eq 'HASH' )
                   ? %{ pop( @items ) } : ();
    my $msg    = join( '', @items );
    return ( $msg, %params );
}

1;

__END__

=head1 NAME

OpenInteract2::Exception - Base class for exceptions in OpenInteract

=head1 SYNOPSIS

 # Standard usage
 
 unless ( $user->check_password( $entered_password ) ) {
   OpenInteract2::Exception->throw( 'Bad login' );
 }
 
 # Pass a list of strings to form the message
 
 unless ( $user->check_password( $entered_password ) ) {
   OpenInteract2::Exception->throw( 'Bad login', $object->login_attempted )
 }
 
 # Using an exported shortcut
 
 use OpenInteract2::Exception qw( oi_error );
 oi_error "Bad login", $object->login_attempted;
 
 use OpenInteract2::Exception qw( oi_security_error );
 oi_security_error "Action failed due to security requirements",
                   { security_required => SEC_LEVEL_WRITE,
                     security_found    => SEC_LEVEL_READ };

=head1 DESCRIPTION

First, you should probably look at
L<Exception::Class|Exception::Class> for more usage examples, why we
use exceptions, what they are intended for, etc.

This is the base class for all OpenInteract exceptions. It declares a
handful of exceptions and provides shortcuts to make raising an
exception easier and more readable.

=head1 METHODS

B<throw( @msg, [ \%params ])>

This overrides B<throw()> from L<Exception::Class|Exception::Class> to
add a little syntactic sugar. Instead of:

 $exception_class->throw( message => 'This is my very long error message that I would like to pass',
                          param1  => 'Param1 value',
                          param2  => 'Param2 value' );

You can use:

 $exception_class->throw( 'This is my very long error message ',
                          'that I would like to pass',
                          { param1 => 'Param1 value',
                            param2 => 'Param2 value' } );

And everything will work the same. Combined with the L<SHORTCUTS> this
makes for very readable code.

=head1 DECLARED EXCEPTION CLASSES

B<OpenInteract2::Exception::Application>

Used for generic application errors.

Extra fields:

=over 4

=item *

B<oi_package> ($) (Optional)

Package from which the error was thrown.

=back

B<OpenInteract2::Exception::Datasource>

Used for errors related to datasources.

Extra fields:

=over 4

=item *

B<datasource_name> ($) (Optional)

Name of the datasource causing the error.

=item *

B<datasource_type> ($) (Optional)

Type of datasource causing the error -- 'DBI', 'LDAP', etc.

=item *

B<connect_params> (\%) (Optional)

Parameters used to connect. NOTE: There may be sensitive information
(such as passwords) here.

=back

B<OpenInteract2::Exception::Parameter>

Used for parameter validation errors, including if a parameter is not
found.

Extra fields:

=over 4

=item *

B<parameter_fail> ($) (Optional)

Name of the parameter that failed.

=back

=head1 SHORTCUTS

You can import shortcuts for these methods

=head1 SEE ALSO

L<Exception::Class|Exception::Class>

L<OpenInteract2::Exception::Security|OpenInteract2::Exception::Security>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
