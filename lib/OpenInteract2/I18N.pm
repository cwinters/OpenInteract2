package OpenInteract2::I18N;

# $Id: I18N.pm,v 1.11 2005/04/12 18:38:13 infe Exp $

use strict;
use base qw( Locale::Maketext );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_TRANSLATE );

$OpenInteract2::I18N::VERSION   = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

my ( $log );

# Override so we can add the message key to the output as required
# TODO: This may be a performance bottleneck...

sub maketext {
    my ( $self, $key, @args ) = @_;
    $log ||= get_logger( LOG_TRANSLATE );

    $key =~ s/^\s+//;
    $key =~ s/\s+$//;

    my ( $msg );
    eval {
        if ( $log->is_debug ) {
            $msg = "[$key] " . $self->SUPER::maketext( $key, @args );
        }
        else {
            $msg = $self->SUPER::maketext( $key, @args );
        }
    };
    if ( $@ ) {
        if ( $log->is_debug ) {
            $log->debug( "Failed to translate '$key': $@" );;
            return "Message error for '$key'";
        }
        else {
            my $iteration = 1;
            while ( 1 ) {
                last unless $key =~ /\[_$iteration\]/;
                $key =~ s/\[_$iteration\]/$args[$iteration-1]/g;
                $iteration++;
            }
            return $key;
        }
    }
    $log->is_debug &&
        $log->debug( "Message for key '$key': '$msg'; given ",
                     "args [", join( '] [', @args ), "]" );
    return $msg;
}

1;

__END__

=head1 NAME

OpenInteract2::I18N - Base class for localized messages

=head1 SYNOPSIS

 # You should never need to access this class directly. Instead use
 # the OI2::Request object:

 my $request = CTX->request;
 my $lang_handle = $request->language_handle;
 print $lang_handle->maketext( 'company.num_employees', 55 );

=head1 DESCRIPTION

This is a base class for localized messages. In the
L<Locale::Maketext|Locale::Maketext> parlance this is your project
class. All localization subclasses generated in
L<OpenInteract2::I18N::Initializer|OpenInteract2::I18N::Initializer>
should subclass this.

=head1 SEE ALSO

L<OpenInteract2::Manual::I18N|OpenInteract2::Manual::I18N>

L<Locale::Maketext|Locale::Maketext>

=head1 COPYRIGHT

Copyright (c) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
