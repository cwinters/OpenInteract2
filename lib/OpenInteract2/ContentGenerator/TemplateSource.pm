package OpenInteract2::ContentGenerator::TemplateSource;

# $Id: TemplateSource.pm,v 1.16 2007/03/09 03:52:41 a_v Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::ContentGenerator::TemplateSource::VERSION  = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

my $REQUIRED = 0;

my ( $log );

sub identify {
    my ( $class, $template_source ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    $REQUIRED || require OpenInteract2::SiteTemplate && $REQUIRED++;

    unless ( ref $template_source eq 'HASH' ) {
        $log->error( "Template source not hashref: ", ref $template_source );
        oi_error "Template source description must be passed as hashref";
    }

    my ( $source_type, $source, $name );

    if ( my $key = $template_source->{message_key} ) {
        my $lh = CTX->request->language_handle;
        my $template_name = $lh->maketext( $key );
        unless ( $template_name ) {
            oi_error "No template found for message key '$key'";
        }
        $template_source->{name} = $template_name;
    }

    # don't make this an elsif since the previous condition sets a
    # template name

    if ( $template_source->{name} ) {
        $source_type = 'NAME';
        $name        = $template_source->{name};
        $source      = $name;
        $log->is_debug &&
            $log->debug( "Source template from name [$source]" );
    }

    elsif ( $template_source->{text} ) {
        $source_type = 'STRING';
        $source      = ( ref $template_source->{text} eq 'SCALAR' )
                         ? $template_source->{text}
                         : \$template_source->{text};
        $name        = '_anonymous_';
        $log->is_debug &&
            $log->debug( "Source template from raw text" );
    }

    elsif ( $template_source->{filehandle} ) {
        $source_type = 'FILE';
        $source      = $template_source->{filehandle};
        $log->is_debug &&
            $log->debug( "Source template from filehandle" );
    }

    elsif ( $template_source->{object} ) {
        $source_type = 'STRING';
        $source      = \$template_source->{object}{template};
        $name        = $template_source->{object}->create_name;
        $log->is_debug &&
            $log->debug( "Source template from template object [$name]" );
    }

    elsif ( $template_source->{db} ) {
        oi_error "Please declare your template using the 'name = pkg::name' ",
                 "syntax rather than the 'db = name, package = pkg' one. ",
                 "(Given db: $template_source->{db}; ",
                 "$template_source->{package}";
    }

    # Uh oh...

    else {
        require Data::Dumper;
        $log->error( "No template to process! Information given for ",
                     "source:\n", Data::Dumper->Dumper( $template_source ) );
        oi_error "No template to process!";
    }

    if ( $name and CTX->controller and CTX->controller->can( 'add_template_used' ) ) {
        CTX->controller->add_template_used( $name );
    }
    return ( $source_type, $source );
}

sub load_source {
    my ( $class, $name ) = @_;
    my $content_template = OpenInteract2::SiteTemplate->fetch( $name );
    unless ( $content_template ) {
       oi_error "Template with name [$name] not found.";
    }
    return ( $content_template->contents,
             $content_template->full_filename,
             $content_template->modified_on );
}

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator::TemplateSource - Common routines for loading content from OI2 templates

=head1 SYNOPSIS

 # Sample from Text::Template content generator
 
 sub generate {
    my ( $self, $template_config, $template_vars, $template_source ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    my ( $source_type, $source ) =
        OpenInteract2::ContentGenerator::TemplateSource->identify( $template_source );
    if ( $source_type eq 'NAME' ) {
        my ( $template, $filename, $modified ) =
            OpenInteract2::ContentGenerator::TemplateSource->load_source( $source );
        $source_type = 'STRING';
        $source      = $template;
        $log->is_debug &&
            $log->debug( "Loading from name $source" );
    }
    else {
        $log->is_debug &&
            $Log->Debug( "Loading from source $source_type" );
    }
    $template_config->{TYPE}   = $source_type;
    $template_config->{SOURCE} = ( ref $source eq 'SCALAR' )
                                   ? $$source : $source;
    my $template = Text::Template->new( %{ $template_config } );
    unless ( $template ) {
        my $msg = "Failed to create template parsing object: " .
                  $Text::Template::ERROR;
        $log->error( $msg );
        oi_error $msg;
    }
    my $content = $template->fill_in( HASH => $template_vars );
    unless ( $content ) {
        my $msg = "Failed to fill in template: $Text::Template::ERROR";
        $log->error( $msg );
        oi_error $msg ;
    }
    return $content;
 }

=head1 CLASS METHODS

B<identify( \%template_source )>

Checks C<\%template_source> for template information and returns a
source type and source. Here are the types of information we check for
in C<\%template_source> and what is returned:

=over 4

=item *

Key B<name>: Set source type to 'NAME' and source to the value of the
C<name> key. (This is the most common condition.)

=item *

Key B<message_key>: If we can lookup a template name from the language
handle retured by the L<OpenInteract2::Request}OpenInteract2::Request>
object set source type to 'NAME' and source to the value of the
message key found from the language handle.

Throws an exception if the language handle does not return a value for
the message key lookup (that is, you do not have the key defined in
any of your message files).

=item *

Key B<text>: Set source type to 'STRING' and source to a scalar
reference with the value of the C<text> key. If C<text> is already a
reference it just copies the reference, otherwise it takes a reference
to the text in the key.

=item *

Key B<filehandle>: Set source type to 'FILE' and source to the
filehandle in C<filehandle>.

=item *

Key B<object>: Set source type to 'STRING' and source to a reference to
the content of the C<template> key of the
L<OpenInteract2::SiteTemplate|OpenInteract2::SiteTemplate> object in
C<object>.

=back

If none of these are found an exception is thrown. (We throw a
different exception if you use the ancient 'db'/'package' syntax.)

Additionally, if we are able to pull a name from the template source
and the current L<OpenInteract2::Controller|OpenInteract2::Controller>
object can handle it, we call C<add_template_used()> on it, passing it
the template name.

Returns: two item list of source type and source.

B<load_source( $template_name )>

Fetches the template with the fully-qualified name C<$template_name>
and returns a three-item list with: contents, full filename, and the last
modified time.

If the template is not found we throw an exception, and any exception
thrown from the fetch propogates up.

Returns: a three-item list with: contents, full filename, and the last
modified time (which is a L<DateTime|DateTime> object).

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
