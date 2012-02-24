package OpenInteract2::Action::SystemDoc;

# $Id: SystemDoc.pm,v 1.17 2005/10/31 02:33:07 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use File::Spec::Functions    qw( catdir catfile );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Package;
use Pod::POM;

$OpenInteract2::Action::SystemDoc::VERSION = sprintf("%d.%02d", q$Revision: 1.17 $ =~ /(\d+)\.(\d+)/);

my ( $log );

# class variable,  holds something like:
#   OpenInteract2::Action => /usr/lib/perl5/site_perl/.../OpenInteract2/Action.pm
my %POD_CACHE = ();


# Classpaths we want to manually find and add for viewing
my @check_subclass = (
    [ qw/ OpenInteract2 App / ],
    [ qw/ OpenInteract2 Manual / ],
    [ qw/ SPOPS Manual / ],
    [ qw/ Template Manual / ],
);


sub home {
    my ( $self ) = @_;
    return $self->generate_content();
}

sub module_list {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    # Copy %INC plus manual items to local cache
    unless ( keys %POD_CACHE ) {
        $self->_read_classpath();
    }

    my @top_level = ();

    # and group the modules into sections, with the top-level
    # namespace as the first item and an arrayref of all children as
    # the second

    my @curr_group = ();
    foreach my $module ( sort keys %POD_CACHE ) {
        my ( $namespace ) = split /::/, $module;
        if ( $namespace ne $curr_group[0] ) {
            $log->is_debug &&
                $log->debug( "Module ($namespace) != parent ($curr_group[0])" );
            if ( ref $curr_group[1] ) {
                push @top_level, [ @curr_group ];
            }
            @curr_group = ( $namespace, [] );
        }
        push @{ $curr_group[1] }, $module;
    }
    if ( ref $curr_group[1] ) {
        push @top_level, \@curr_group;
    }
    $log->is_debug &&
        $log->debug( "# module parents found: ", scalar @top_level );
    return $self->generate_content({ module_list => \@top_level });
}


my $DISPLAY_INITIALIZED = 0;

sub display {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );
    my $module = $self->param( 'module' )
                 || CTX->request->param( 'module' );

    unless ( $DISPLAY_INITIALIZED ) {
        eval "require Pod::Perldoc";
        if ( $@ ) {
            return "Sorry, cannot display module without Pod::Perldoc " .
                   "installed.";
        }
        unless ( Pod::Perldoc->can( 'grand_search_init' ) ) {
            return "Sorry, cannot display module without a recent " .
                   "version of Pod::Perldoc. (Where 'recent' means " .
                   "'since 2002'.";
        }
        $DISPLAY_INITIALIZED++;
    }

    # NOTE: This is an undocumented use found by reading the
    # Pod::Perldoc source; if you just call $pod->process() it'll
    # print to STDOUT the file you're interested in rather than
    # returning it...
    

    my $pod = Pod::Perldoc->new();
    my ( $pod_file ) = $pod->grand_search_init( [ $module ] );
    $log->is_info &&
        $log->info( "Found POD file '$pod_file' for module '$module'" );

    my ( $content );
    if ( -f $pod_file ) {
        $content = $self->_show_pod( $pod_file );
    }
    else {
        $self->add_error_key(
            'sys_doc.error.cannot_find_module_doc', $module
        );
        $content = '';
    }
    my $title = $self->_msg( 'sys_doc.module.doc_title', $module );
    return $self->generate_content({
        content => $content, title => $title, pod_file => $pod_file,
    });
}


sub _read_classpath {
    my ( $self ) = @_;
    eval {
        # First, copy everything from %INC...
        while ( my ( $inc_module, $inc_path ) = each %INC ) {
            my $module = $inc_module;
            $module =~ s|\.(\w+)$||;
            $module =~ s|/|::|g;
            next if ( $module =~ m|^::| );
            $POD_CACHE{ $module } = $inc_path;
            $log->info( "POD cache from INC: $module => $inc_path" );
        }

        my @file_extensions = qw( .pm .pod );

        # Then seek out our modules/POD that won't be in %INC...
        foreach my $top_dir ( @INC ) {
            foreach my $subclass_info ( @check_subclass ) {

                # Finds stuff like OpenInteract2/Manual.pod
                foreach my $ext ( @file_extensions ) {
                    my $top_file =
                        catfile( $top_dir, @{ $subclass_info } ) . $ext;
                    if ( -f $top_file ) {
                        my $module = join( '::', @{ $subclass_info } );
                        $POD_CACHE{ $module } = $top_file;
                    }
                }

                my $full_subclass_dir =
                    catdir( $top_dir, @{ $subclass_info } );
                next unless ( -d $full_subclass_dir );
                opendir( INCDIR, $full_subclass_dir )
                    || die "Cannot read from '$full_subclass_dir': $!\n";
                my @pod_from = grep /\.(pm|pod)$/, readdir( INCDIR );
                closedir( INCDIR );
                foreach my $pod_src ( @pod_from ) {
                    my $full_path = catfile( $full_subclass_dir, $pod_src );
                    $pod_src =~ s/\.\w+$//;
                    my $pod_key = join( '::', @{ $subclass_info }, $pod_src );
                    $POD_CACHE{ $pod_key } ||= $full_path;
                    $log->info( "POD cache from manual: $pod_key => $full_path" );
                }
            }
        }
    };
    if ( $@ ) {
        %POD_CACHE = ();
        die "Error reading modules from %INC: $@\n";
    }
}


sub _show_pod {
    my ( $self, $pod_file ) = @_;
    $log->is_debug &&
        $log->debug( "Trying to view pod in '$pod_file'" );
    my $parser = Pod::POM->new();
    my $pom = $parser->parse( $pod_file );
    unless ( $pom ) {
        $log->error( "Pod::POM did not return an object: ",
                     $parser->error() );
        $self->add_error_key( 'sys_doc.error.pod_parse', $parser->error() );
        return '';
    }

    eval { require OpenInteract2::PodView };
    if ( $@ ) {
        my $error = $@;
        $log->error( "No POD viewer: $error" );
        $self->add_error_key( 'sys_doc.error.pod_viewer', $error );
        return '';
    }

    my $content = eval { OpenInteract2::PodView->print( $pom ) };
    if ( $@ ) {
        my $error = $@;
        $log->error( "Failed to output html from pod: $error" );
        $self->add_error_key(
            'sys_doc.pod.cannot_display_module', $error );
    }
    else {
        $content =~ s/^.*<BODY>//sm;
        $content =~ s|</BODY>.*$||sm;
    }
    return $content;
}

1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::SystemDoc - Display system documentation in HTML format

=head1 SYNOPSIS

=head1 DESCRIPTION

Display documentation for the OpenInteract system, SPOPS modules, and any
other perl modules used.

=head1 METHODS

C<home()>

Display main menu.

C<module_list()>

List the OpenInteract system documentation and all the modules used by
the system -- we display both the C<OpenInteract> modules and the
C<SPOPS> modules first.

B<module_list()>

B<display()>

Display a particular document or module, filtering through
L<Pod::POM|Pod::POM> using
L<OpenInteract2::PodView|OpenInteract2::PodView>.

Parameters:

=over 4

=item *

B<filename>: Full filename of document to extract POD from.

=item *

B<module>: Perl module to extract POD from; we match up the module to
a file using %INC

=back

=head1 TO DO

B<Get more meta information>

System documentation needs more meta information so we can better
display title and other information on the listing page.

=head1 SEE ALSO

L<Pod::Perldoc> - We use an undocumented method of this to find the
location of the requested POD.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
