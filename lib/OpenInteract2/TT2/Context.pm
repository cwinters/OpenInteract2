package OpenInteract2::TT2::Context;

# $Id: Context.pm,v 1.3 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( Template::Context );
use Template::Constants qw( STATUS_ERROR ERROR_FILE );

$OpenInteract2::TT2::Context::VERSION  = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

# Overriding Template::Context so we can get around the issue of the
# template name 'x::y' being interpreted as a directive to have a
# particular provider parse it (yuck)

sub template {
    my ( $self, $name ) = @_;
    my ( $template );

    # Template::Document (or sub-class) objects, or CODE refs are
    # assumed to be pre-compiled templates and are returned intact

    if ( UNIVERSAL::isa( $name, 'Template::Document' ) || ref( $name ) eq 'CODE' ) {
        return $name;
    }

    unless ( ref $name ) {

        # we first look in the BLOCKS hash for a BLOCK that may have
        # been imported from a template (via PROCESS)

        return $template      if ( $template = $self->{ BLOCKS }->{ $name } );

        # then we iterate through the BLKSTACK list to see if any of the
        # Template::Documents we're visiting define this BLOCK

        foreach my $blocks (@{ $self->{ BLKSTACK } }) {
            return $template  if ( $blocks && ( $template = $blocks->{ $name } ) );
        }
    }

    my $providers = $self->{ PREFIX_MAP }->{ default } || $self->{ LOAD_TEMPLATES };

    # Finally we try the regular template providers which will
    # handle references to files, text, etc., as well as templates
    # reference by name

    foreach my $provider ( @{ $providers } ) {
        my ( $error );
        ( $template, $error ) = $provider->fetch( $name );
        return $template unless ( $error );
        if ( $error == STATUS_ERROR)  {
            $self->throw( $template ) if ( ref $template );
            $self->throw( ERROR_FILE, $template );
        }
    }
    $self->throw( ERROR_FILE, "$name: not found" );
}

1;

__END__

=head1 NAME

OpenInteract2::TT2::Context - Provide a custom context for templates in OpenInteract

=head1 SYNOPSIS

    # In OpenInteract2::ContentGenerator::TT2Process->initialize()

    $Template::Config::CONTEXT = 'OpenInteract2::TT2::Context';
    my $template = Template->new( ... );
    my ( $output );
    $template->process( 'package::template', \%params, \$output );

=head1 DESCRIPTION

Kind of a hack -- remove the TT check for prefixes when serving up
templates since it uses '::' as a delimiter. Everything else about the
TT context is the same.

=head1 METHODS

B<template( $name )>

Override the method from L<Template::Context|Template::Context> and
replicate its functionality, except the check for a template prefix is
removed.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<Template::Context|Template::Context>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
