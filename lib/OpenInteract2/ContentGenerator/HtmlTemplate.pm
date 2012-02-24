package OpenInteract2::ContentGenerator::HtmlTemplate;

# $Id: HtmlTemplate.pm,v 1.8 2005/03/17 14:58:00 sjn Exp $

use strict;
use base qw( OpenInteract2::ContentGenerator );

use HTML::Template;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::ContentGenerator::TemplateSource;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::ContentGenerator::HtmlTemplate::VERSION  = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

my ( $log );

# HTML::Template doesn't seem to use the same architecture as TT, so
# it doesn't make sense to create a template object in initialize()
# and reuse it.

sub initialize {
    my $log_init = get_logger( LOG_INIT );
    $log_init->is_info &&
        $log_init->info( "Called initialize() for HTML::Template CG (no-op)" );
}

sub generate {
    my ( $self, $template_config, $template_vars, $template_source ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );

    # TODO: Check for cached content...

    my %init_params = ( die_on_bad_params => 0 );

    my ( $source_type, $source ) =
        OpenInteract2::ContentGenerator::TemplateSource->identify( $template_source );
    if ( $source_type eq 'NAME' ) {
        my ( $template, $filename, $modified ) =
            OpenInteract2::ContentGenerator::TemplateSource->load_source( $source );
        $log->is_debug &&
            $log->debug( "Loading from name $source" );
        $init_params{scalarref} = ( ref $template eq 'SCALAR' )
                                    ? $template : \$template;
        $init_params{option}    = 'value';
    }
    elsif ( $source_type eq 'FILE' ) {
        $init_params{filename} = $source;
        $init_params{option}   = 'value';
    }
    else {
        $log->error( "Don't know how to load from source $source_type" );
        return "Cannot process template from source $source_type";
    }

    my $template = HTML::Template->new( %init_params );
    $template->param( $template_vars );
    my $content = $template->output;
    unless ( $content ) {
        my $msg = "Failed to fill in template for some unknown reason...";
        $log->error( $msg );
        oi_error $msg ;
    }

    # TODO: Cache content before returning

    return $content;
}

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator::HtmlTemplate - Content generator using HTML::Template

=head1 SYNOPSIS

 my $generator = CTX->content_generator( 'HTMLTemplate' );
 $generator->generate( \%template_config, \%params, { name => 'mypkg::mytemplate' } );

=head1 DESCRIPTION

Content generator for L<HTML::Template>. May be horribly inefficient.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
