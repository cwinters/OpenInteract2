package OpenInteract2::ContentGenerator::TextTemplate;

# $Id: TextTemplate.pm,v 1.10 2005/03/17 14:58:01 sjn Exp $

use strict;
use base qw( OpenInteract2::ContentGenerator );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::ContentGenerator::TemplateSource;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Text::Template;

$OpenInteract2::ContentGenerator::TextTemplate::VERSION  = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

my ( $log );

# Text::Template doesn't seem to use the same architecture as TT, so
# it doesn't make sense to create a template object in initialize()
# and reuse it.

sub initialize {
    my $log_init = get_logger( LOG_INIT );
    $log_init->is_info &&
        $log_init->info( "Called initialize() for Text::Template CG (no-op)" );
}

sub generate {
    my ( $self, $template_config, $template_vars, $template_source ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );

    # TODO: Check for cached content...

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
            $log->debug( "Loading from source $source_type" );
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

    # TODO: Cache content before returning

    return $content;
}

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator::TextTemplate - Content generator using Text::Template

=head1 SYNOPSIS

 my $generator = CTX->content_generator( 'TextTemplate' );
 $generator->generate( \%template_config, \%params, { name => 'mypkg::mytemplate' } );

=head1 DESCRIPTION

Content generator for L<Text::Template>. May be horribly inefficient.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
