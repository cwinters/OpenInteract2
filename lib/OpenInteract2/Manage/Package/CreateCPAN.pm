package OpenInteract2::Manage::Package::CreateCPAN;

# $Id: CreateCPAN.pm,v 1.4 2005/10/22 21:56:03 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Package );
use Cwd                      qw( cwd );
use ExtUtils::Manifest;
use File::Basename           qw( dirname );
use File::Copy               qw( cp );
use File::Path               qw( mkpath rmtree );
use File::Spec::Functions    qw( catfile );
use Log::Log4perl            qw( get_logger );
use MIME::Base64             qw( encode_base64 );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Manage::Package::CreateCPAN::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my @BINARIES = qw( gz zip gif png jpg ico pdf doc );
my $DIST_DIR = "tmp-build-cpan";

sub get_name {
    return 'create_cpan';
}

sub get_brief_description {
    return 'Create a CPAN distribution from your package.';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
       package_dir => {
         description => q{Directory of package to export (default: pwd)},
         default     => cwd(),
         is_required => 'yes',
       },
       make_bin => {
           description => q{Binary for your "make" implementation (default: 'make')},
           default     => 'make',
           is_required => 'yes',
       },
       keep_dir => {
           description => q{If set to "yes" we keep the generated CPAN directory (default: 'no')},
           default     => 'no',
           is_required => 'yes',
       },
    };
}

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'package_dir' ) {
        return $self->_check_package_dir( $value );
    }
    return $self->SUPER::validate_param( $name, $value );
}

sub tear_down_task {
    my ( $self ) = @_;
    my $keep_dir = lc $self->param( 'keep_dir' );
    if ( -d $DIST_DIR && $keep_dir ne 'yes' ) {
        rmtree( $DIST_DIR );
    }
}

sub run_task {
    my ( $self ) = @_;
    my $package_dir = $self->param( 'package_dir' );
    my $package = OpenInteract2::Package->new({
        directory => $package_dir
    });

    my $subclass_name    = $package->name_as_class;
    my $brick_class_name = "OpenInteract2::Brick::$subclass_name";
    my $app_class_name   = "OpenInteract2::App::$subclass_name";

    my $config  = $package->config;
    my $modules = $config->module || [];

    my @author_names  = join( ', ', $config->author_names );
    my @author_emails = join( ', ', $config->author_emails );
    my ( @authors );
    for ( 0..scalar @author_names ) {
        push @authors, {
            name  => $author_names[$_],
            email => $author_emails[$_]
        };
    }

    $self->_create_dist_dir();

    my $module_file_specs = $package->get_module_files;
    my @module_files = map { join( '/', @{ $_ } ) } @{ $module_file_specs };
    my @package_modules = $self->_copy_package_modules(
        $package, \@module_files
    );
    my @brick_files = $self->_read_files_for_brick(
        $package, \@module_files
    );

    my %replacements = (
        package_name     => $package->name,
        brick_name       => $package->name,
        full_app_class   => $app_class_name,
        full_brick_class => $brick_class_name,
        subclass         => $subclass_name,
        authors          => \@authors,
        author_names     => \@author_names,
        abstract         => $config->description,
        required_modules => $modules,
        package_modules  => \@package_modules,
        package_version  => $package->version,
        package_files    => \@brick_files,
        package_pod      => '',
        invocation       => $self->invocation,
        date             => scalar( localtime ),
        oi2_version      => OpenInteract2::Context->version,
    );

    my $brick = OpenInteract2::Brick->new( 'package_cpan' );
    $brick->copy_all_resources_to( $DIST_DIR, \%replacements );
    my $dist_file = $self->_create_distribution( $subclass_name );
    $self->_ok(
        'create CPAN distribution',
        'Created distribution ok',
        filename => $dist_file,
    );
}

sub _create_dist_dir {
    my ( $self ) = @_;
    if ( -d $DIST_DIR ) {
        my $num_removed = rmtree( $DIST_DIR );
        unless ( $num_removed > 0 ) {
            oi_error "Failed to remove directory '$DIST_DIR'; please ",
                     "remove manually and re-run task.";
        }
    }
    mkdir( $DIST_DIR )
        || oi_error "Cannot create temporary directory '$DIST_DIR': $!";
}

# copy modules into cpan dist dir

sub _copy_package_modules {
    my ( $self, $package, $module_files ) = @_;
    my $package_dir = $package->directory;
    my @package_modules = ();
    foreach my $file ( @{ $module_files } ) {
        my $full_src  = catfile( $package_dir, $file );
        my $full_dest = catfile( $DIST_DIR, 'lib', $file );
        my $dest_dir  = dirname( $full_dest );
        unless ( -d $dest_dir ) {
            mkpath( $dest_dir );
        }
        cp( $full_src, $full_dest )
            || oi_error "Cannot copy '$full_src' to '$full_dest': $!";
        my $module = $file;
        $module =~ s/\.pm$//;
        $module =~ s|/|::|g;
        push @package_modules, $module;
    }
    return @package_modules;
}

# copy non-modules files into brick as resources

sub _read_files_for_brick {
    my ( $self, $package, $module_files ) = @_;
    my @brick_files = ();
    my $package_dir = $package->directory;
    my %module_check = map { $_ => 1 } @{ $module_files };
    my %seen_names   = ();
    my $package_files = $package->get_files;
    foreach my $file ( @{ $package_files } ) {
        next if ( $module_check{ $file } ); # modules are separate
        my @file_pieces = split /\//, $file;
        my $brick_name = $file_pieces[-1];
        if ( $seen_names{ $brick_name } ) {
            $brick_name = join ( '_', @file_pieces );
        }
        $seen_names{ $brick_name }++;
        my $inline_name = uc( $brick_name );
        $inline_name =~ s/\W/_/g;
        push @brick_files, {
            name        => $brick_name,
            inline_name => $inline_name,
            destination => join( ' ', @file_pieces ),
            evaluate    => 'no',
            contents    => $self->_read_package_file_contents( $package_dir, $file ),
        };
    }
    return @brick_files;
}

sub _read_package_file_contents {
    my ( $self, $package_dir, $file ) = @_;
    my $full_path = catfile( $package_dir, $file );
    my $binary_pat = join( '|', @BINARIES );
    if ( $full_path =~ /$binary_pat$/ ) {
        open( IN, '<', $full_path )
            || oi_error "Cannot read '$full_path': $!";
        my @content = ();
        my ( $buf );
        while ( read( IN, $buf, 60*57 ) ) {
            push @content, encode_base64( $buf );
        }
        return join( ', ', @content );
    }
    else {
        return OpenInteract2::Util->read_file( $full_path );
    }
}

sub _create_distribution {
    my ( $self, $subclass_name ) = @_;
    chdir( $DIST_DIR );

    ExtUtils::Manifest::mkmanifest();

    my ( $dist_file );
    eval {
        do './Makefile.PL';
        my $make_cmd = $self->param( 'make_bin' );
        system( $make_cmd, 'dist' );
        opendir( ARCHIVE, '.' )
            || die "Cannot open current directory for reading: $!\n";
        ( $dist_file ) = grep /$subclass_name/, grep /\.tar\.gz$/, readdir( ARCHIVE );
        closedir( ARCHIVE );
        rename( $dist_file, catfile( '..', $dist_file ) )
            || die "Cannot move archive: $!\n";
        chdir( '..' );
    };
    if ( $@ ) {
        chdir( '..' );
        oi_error( $@ );
    }
    return $dist_file;
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Package::CreateCPAN - Create a CPAN distribution from a package

=head1 SYNOPSIS

 # From command-line:
 
 $ oi2_manage create_cpan
 
 # Programmatically:
 
 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my %PARAMS = ( package_dir = '/path/to/my/package' );
 my $task = OpenInteract2::Manage->new(
                      'create_cpan', \%PARAMS );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     print "Status? $ok_label\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

This task creates a CPAN distribution from your package contents and
metadata. You should be able to send the generated distribution to
anyone else for them to run the standard install:

 perl Makefile.PL
 make
 make test
 make install

For installing directly to a webserver you can do:

 perl Makefile.PL WEBSITE_DIR=/path/to/mysite
 make
 make test
 make install

And the files will be copied to the right place.

=head1 OPTIONS

=head2 Required

=over 4

=item B<package_dir>=/path/to/package

Path to your package; defaults to current directory if not given.

=item B<make_bin>=nmake

Name of your 'make' command; defaults to 'make' if not given.

=back

=head2 Optional

=over 4

=item B<keep_dir>=yes/no

Whether to keep the directory we use to create the CPAN package;
defaults to 'no'.

=back

=head1 STATUS INFORMATION

Includes no additional status information.

=head1 COPYRIGHT

Copyright (C) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters, E<lt>chris@cwinters.comE<gt>

