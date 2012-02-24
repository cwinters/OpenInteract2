package OpenInteract2::Action::SiteTemplate;

# $Id: SiteTemplate.pm,v 1.16 2005/10/18 01:34:10 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::SiteTemplate;
use SPOPS::Secure            qw( SEC_LEVEL_WRITE );

$OpenInteract2::Action::SiteTemplate::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub list {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_info && $log->info( "Listing templates in system" );
    my $website_dir = CTX->lookup_directory( 'website' );
    my $packages = CTX->repository->fetch_all_packages();
    my %templates = ();
    foreach my $pkg ( @{ $packages } ) {
        eval {
            $templates{ $pkg->name } =
                OpenInteract2::SiteTemplate->fetch_by_package( $pkg->name );
        };
        if ( $@ ) {
            my $msg = $self->add_error_key( '', $pkg->name, $@ );
            $log->error( $msg );
        }
    }

    # This looks weird but we're just finding the global templates
    eval {
        $templates{ '' } =
            OpenInteract2::SiteTemplate->fetch_by_package( '' )
    };
    if ( $@ ) {
        my $msg = $self->add_error_key( 'base_template.error.fetch_global', $@ );
        $log->error( $msg );
    }
    return $self->generate_content(
                    { package_templates => \%templates },
                    { name => 'base_template::template_list' } );
}

sub _set_package_info {
    my ( $self, $template_params ) = @_;
    my $packages = CTX->packages;
    for ( @{ $packages } ) {
        push @{ $template_params->{package_list} }, $_->{name};
        push @{ $template_params->{package_labels} }, $_->{name};
    }
}

sub display_form {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my %params = ( package_list   => [ '' ],
                   package_labels => [ 'Global Templates' ] );
    $self->_set_package_info( \%params );

    my $request = CTX->request;
    my $template = $self->param( 'template' );
    unless ( $template ) {
        my $package = $request->param( 'package' );
        my $name    = $request->param( 'name' );
        if ( $name ) {
            my $fq_name =
                OpenInteract2::SiteTemplate->create_name( $package, $name );
            $template = eval {
                OpenInteract2::SiteTemplate->fetch( $fq_name )
            };
            if ( $@ || ! $template ) {
                if ( $@ ) {
                    $self->add_error_key( 'base_template.error.fetch', $fq_name, $@ );
                }
                else {
                    $self->add_error_key( 'base_template.error.does_not_exist', $fq_name );
                }
                return $self->execute({ task => 'list' });
            }
        }
    }
    $log->is_info &&
        $log->info( "Display update form for: ", $template->create_name );
    $params{tmpl} = $template;
    return $self->generate_content(
                    \%params,
                    { name => 'base_template::template_form' } );
}

sub display_add {
    my ( $self ) = @_;

    # We might have one leftover from a failed 'add'...
    my $template = $self->param( 'template' )
                   || OpenInteract2::SiteTemplate->new;

    my %params = ( tmpl           => $template,
                   package_list   => [ '' ],
                   package_labels => [ 'Global Templates' ] );
    $self->_set_package_info( \%params );
    return $self->generate_content(
                    \%params,
                    { name => 'base_template::template_form' } );
}

sub update {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_info && $log->info( "Updating existing template" );
    CTX->response->return_url(
        OpenInteract2::URL->create_from_action( 'template' )
    );

    my $request = CTX->request;
    my $package = $request->param( 'package_original' );
    my $name    = $request->param( 'name_original' );

    my $fq_name = OpenInteract2::SiteTemplate
                      ->create_name( $package, $name );
    my $template = eval {
        OpenInteract2::SiteTemplate->fetch( $fq_name )
    };
    if ( $@ or ! $template ) {
        if ( $@ ) {
            $self->add_error_key( 'base_template.error.fetch', $fq_name, $@ );
        }
        else {
            $self->add_error_key( 'base_template.error.does_not_exist', $fq_name );
        }
        return $self->execute({ task => 'list' });
    }
    $template->package( $request->param( 'package' ) );
    $template->name( $request->param( 'name' ) );
    $template->set_contents( $request->param( 'contents' ) );
    eval { $template->save };
    if ( $@ ) {
        $self->add_error_key( 'base_template.error.update', $@ );
        $self->param( template => $template );
        return $self->execute({ task => 'display_form' });
    }
    else {
        my $new_name = $template->create_name;
        $self->add_status_key( 'base_template.status.update', $new_name );
        return $self->execute({ task => 'list' });
    }
}


sub add {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_info &&
        $log->info( "Adding new template" );

    CTX->response->return_url(
        OpenInteract2::URL->create_from_action( 'template' ) );

    my $request = CTX->request;

    my $template = OpenInteract2::SiteTemplate->new;

    my $package = $request->param( 'package' );
    my $name    = $request->param( 'name' );

    $template->package( $package );
    $template->name( $name );
    $template->set_contents( $request->param( 'contents' ) );
    $self->param( template => $template );

    my $fq_name = OpenInteract2::SiteTemplate
                      ->create_name( $package, $name );
    my $existing_template = eval {
        OpenInteract2::SiteTemplate->fetch( $fq_name )
    };
    if ( $existing_template ) {
        $self->add_error_key( 'base_template.error.create_exists', $fq_name );
        return $self->execute({ task => 'display_add' });
    }

    eval { $template->save };
    if ( $@ ) {
        $self->add_error_key( 'base_template.error.create', $fq_name, $@ );
        return $self->execute({ task => 'display_add' });
    }
    else {
        $self->add_status_key( 'base_template.status.create', $fq_name );
        return $self->execute({ task => 'list' });
    }
}


sub remove {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_info &&
        $log->info( "Removing existing template" );

    my $request = CTX->request;
    my $template = $self->param( 'template' );
    my ( $fq_name );
    if ( $template ) {
        $fq_name = $template->create_name;
    }
    else {
        my $package = $request->param( 'package' );
        my $name    = $request->param( 'name' );
        $fq_name = OpenInteract2::SiteTemplate->create_name( $package, $name );
        $template = eval {
            OpenInteract2::SiteTemplate->fetch( $fq_name )
        };
        if ( $@ ) {
            $self->add_error_key( 'base_template.error.fetch', $fq_name, $@ );
            return $self->execute({ task => 'list' });
        }
    }
    if ( $template ) {
        eval { $template->remove };
        if ( $@ ) {
            $self->add_error_key( 'base_template.error.remove', $fq_name, $@ );
        }
        else {
            $self->add_status_key( 'base_template.status.remove', $fq_name );
        }
    }
    else {
        $self->add_error_key( 'base_template.error.does_not_exist', $fq_name );
    }
    return $self->execute({ task => 'list' });
}

1;
