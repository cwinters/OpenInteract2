package OpenInteract2::SiteTemplate;

# $Id: SiteTemplate.pm,v 1.13 2005/03/18 04:09:44 lachoy Exp $

use strict;
use base qw( Exporter Class::Accessor::Fast );
use File::Basename           qw();
use File::Path               qw();
use File::Spec;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::SiteTemplate::VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my $NAME_SEPARATOR = '::';
sub NAME_SEPARATOR { return $NAME_SEPARATOR }

@OpenInteract2::SiteTemplate::EXPORT_OK = qw( NAME_SEPARATOR );

my @FIELDS = qw( package name filename directory modified_on is_package is_global );
OpenInteract2::SiteTemplate->mk_accessors( @FIELDS );

my @TEMPLATE_EXTENSIONS = ( '', '.tmpl', '.tt' );

########################################
# CLASS METHODS
########################################

# Parse a combined 'package::name' label into the package and
# name. If label is simply 'name' we return ( undef, $label )

sub parse_name {
    my ( $class, $full_name ) = @_;
    if ( $full_name =~ /$NAME_SEPARATOR/ ) {
        return split /$NAME_SEPARATOR/, $full_name, 2;
    }
    return ( undef, $full_name );
}


# Create a combined 'package::name' label. If no package exists,
# return 'name' by itself

sub create_name {
    my ( $item, $package, $name ) = @_;
    if ( ref $item eq __PACKAGE__ ) {
        $package = $item->{package};
        $name    = $item->{name};
    }
    if ( $package and $name ) {
        return join $NAME_SEPARATOR, $package, $name;
    }
    return $name;
}


sub name_from_file {
    my ( $class, $filename ) = @_;
    my $base = File::Basename::basename( $filename );
    $base =~ s/\.\w+$//;
    return $base;
}

########################################
# CONSTRUCTOR
########################################

sub new {
    my ( $class, $params ) = @_;
    my $self = bless( {}, $class );
    for ( @FIELDS ) {
        $self->$_( $params->{ $_ } ) if ( $params->{ $_ } );
    }
    if ( $params->{full_name} ) {
        my ( $package, $name ) = $class->parse_name( $params->{full_name} );
        $self->package( $package );
        $self->name( $name );
    }
    if ( $params->{contents} ) {
        $self->set_contents( $params->{contents} )
    }
    return $self;
}


########################################
# FIND OBJECTS
########################################

sub fetch {
    my ( $class, $given_name, $params ) = @_;
    my ( $package, $name ) = $class->parse_name( $given_name );
    $params ||= {};

    if ( my $filename = $class->_find_in_global( $package, $name ) ) {
        $params->{is_global}  = 1;
        $params->{is_package} = 0;
        return $class->_create_from_file( $filename, $package, $params );
    }
    elsif ( my $pkg_filename = $class->_find_in_package( $package, $name ) ) {
        $params->{is_global}  = 0;
        $params->{is_package} = 1;
        return $class->_create_from_file( $pkg_filename, $package, $params );
    }
    return undef;
}


sub fetch_by_package {
    my ( $class, $package_name, $params ) = @_;
    my @template_dir = $class->_lookup_site_template_dir( $package_name );
    if ( $package_name ) {
        push @template_dir,
                 $class->_lookup_package_template_dir( $package_name );
    }
    my %by_name = ();
    foreach my $dir ( @template_dir ) {
        foreach my $file ( $class->_get_all_templates_in_directory( $dir ) ) {
            $by_name{ $class->name_from_file( $file ) }++;
        }
    }
    my @templates = ();
    foreach my $tmpl_name ( sort keys %by_name ) {
        my $fq_name = $class->create_name( $package_name, $tmpl_name );
        push @templates, $class->fetch( $fq_name );
    }
    return \@templates;
}


# Finds the file corresponding to the package/name given in the global
# template directory. Return undef if not found.

sub _find_in_global {
    my ( $class, $package_name, $name ) = @_;
    my $template_dir = $class->_lookup_site_template_dir( $package_name );
    return $class->_find_template_in_directory( $template_dir, $name );
}


# Finds the file corresponding to the package/name given in the
# package template directory. Return undef if not found.

sub _find_in_package {
    my ( $class, $package_name, $name ) = @_;
    my $template_dir =
        $class->_lookup_package_template_dir( $package_name );
    return $class->_find_template_in_directory( $template_dir, $name );
}

# Finds a template file in a particular directory -- cycles through
# the different template extensions to see if one exists.

sub _find_template_in_directory {
    my ( $class, $dir, $name ) = @_;
    for ( @TEMPLATE_EXTENSIONS ) {
        my $try_file = File::Spec->catfile( $dir, "$name$_" );
        return $try_file if ( -f $try_file );
    }
    return undef;
}


sub _create_from_file {
    my ( $class, $full_filename, $package_name, $params ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );

    my ( $filename, $directory ) = File::Basename::fileparse( $full_filename );
    my $modified_on =
        DateTime->from_epoch( epoch => (stat( $full_filename ))[9] );
    if ( $log->is_debug ) {
        my $human_time = $modified_on->strftime( '%Y-%m-%d %H:%M:%S' );
        $log->debug( "Template '$full_filename' last modified '$human_time'" );
    }
    return $class->new({ package     => $package_name,
                         name        => $class->name_from_file( $filename ),
                         directory   => $directory,
                         filename    => $filename,
                         modified_on => $modified_on,
                         is_package  => $params->{is_package},
                         is_global   => $params->{is_global} });
}


sub _get_all_templates_in_directory {
    my ( $class, $dir ) = @_;

    # No penalties for checking a directory that might not yet exist
    return () unless ( -d $dir );

    opendir( TMPL, $dir )
                    || oi_error "Error scanning '$dir' for templates: $!";
    my @files = grep { -f "$dir/$_" } readdir( TMPL );
    closedir( TMPL );

    my @good_files = ();
    foreach my $file ( sort @files ) {
        next if ( $file =~ /(~|\.bak|\.meta)$/ or $file =~ /^(\.|tmp)/ );
        push @good_files, File::Spec->catfile( $dir, $file );
    }
    return @good_files
}


########################################
# SAVE OBJECT
########################################

sub save {
    my ( $self, $params ) = @_;
    unless ( $self->name ) {
        oi_error "Cannot save template - property 'name' must be defined";
    }
    my $template_dir = CTX->lookup_directory( 'template' );
    unless ( $self->filename ) {
        $self->filename( $self->name );
    }

    # Always ensure that we're saving to the global directory

    if ( $self->package ) {
        $self->directory(
            File::Spec->catdir( $template_dir, $self->package ) );
        $self->is_global(1);
        $self->is_package(0);
    }
    else {
        $self->directory( $template_dir );
        $self->is_global(1);
        $self->is_package(0);
    }
    $self->_save_contents();
    $self->modified_on(
        DateTime->from_epoch( epoch => (stat( $self->full_filename ))[9] )
    );
    return $self;
}


########################################
# REMOVE OBJECT
########################################

sub remove {
    my ( $self, $params ) = @_;
    my $full_filename = $self->full_filename;
    unlink( $full_filename )
                    || oi_error "Cannot remove '$full_filename': $!";
}


########################################
# ACCESSORS/PROPERTY METHODS
########################################

sub full_filename {
    my ( $self ) = @_;
    return File::Spec->catfile( $self->directory, $self->filename );
}

sub contents {
    my ( $self ) = @_;
    $self->_load_contents() unless ( $self->{_contents} );
    return $self->{_contents} ;
}


sub set_contents {
    my ( $self, $contents ) = @_;
    return $self->{_contents} = $contents;
}


sub _load_contents {
    my ( $self ) = @_;
    my $full_filename = $self->full_filename;
    open( IN, '<', $full_filename )
                    || oi_error "Cannot open template '$full_filename': $!";
    local $/ = undef;
    $self->{_contents} = <IN>;
    close( IN );
}


# Don't fall into the trap of writing to the same file and leaving it
# inconsistent, even though the open/write/close is only three lines.
# (Thanks to merlyn for the friendly reminder!)
#
# If you call this from anywhere else, be sure that 'directory' and
# 'name' properties are defined

sub _save_contents {
    my ( $self ) = @_;
    my $full_filename = $self->full_filename;

    # First make sure the write path exists

    File::Path::mkpath( $self->directory );

    # Then open a temp version of the relevant file

    my $open_filename = ( -f $full_filename )
                          ? $full_filename . '_tmp' : $full_filename;
    open( OUT, '>', $open_filename )
        || oi_error "Cannot open template for writing '$open_filename': $!";
    print OUT $self->{_contents};
    close( OUT );

    # ...and rename the temp version to the real thing

    if ( $full_filename ne $open_filename ) {
        rename( $open_filename, $full_filename )
            || oi_error "Cannot rename '$open_filename' -> '$full_filename': $!";
    }
}


########################################
# DIRECTORY
########################################

sub _lookup_site_template_dir {
    my ( $class, $package_name ) = @_;
    my $template_dir = CTX->lookup_directory( 'template' );
    if ( $package_name ) {
        return File::Spec->catfile( $template_dir, $package_name );
    }
    return $template_dir;
}


sub _lookup_package_template_dir {
    my ( $class, $package_name ) = @_;
    return undef unless ( $package_name );
    $log ||= get_logger( LOG_TEMPLATE );
    my $package = CTX->repository
                     ->fetch_package( $package_name );
    unless ( $package ) {
        $log->warn( "Trying to lookup package template directory for ",
                    "'$package_name' but the repository didn't return ",
                    "a package for that name" );
        return undef;
    }
    return File::Spec->catfile( $package->directory, 'template' );
}

1;

__END__

=head1 NAME

OpenInteract2::SiteTemplate - Object to represent templates

=head1 SYNOPSIS

 # Retreive a single template based on name
 
 my $tmpl = eval { CTX->lookup_class( 'template' )
                      ->fetch( 'base_box::user_info_box' ) };
 die "Cannot retrieve box: $@" if ( $@ );
 print "Template contents: ", $tmpl->contents, "\n";
 
 # Retrieve multiple templates from a package, using the template class directly
 
 my $tmpl_list = eval {
     OpenInteract2::SiteTemplate->fetch_by_package( 'base_box' )
 };
 die "Cannot retrieve templates from base_box: $@" if ( $@ );
 foreach my $tmpl ( @{ $tmpl_list } ) {
    print "Template contents: ", $tmpl->contents, "\n";
 }
 
 # Parse the common 'package::name' format
 
 my $full_name = 'base_box::main_box_shell';
 my ( $pkg, $name ) = CTX->lookup_class( 'template' )
                         ->parse_name( $full_name );
 
 # Template Toolkit usage
 
 # Include a template from a separate package. (See TT docs for the
 # difference between 'PROCESS' and 'INCLUDE')
 
 [% PROCESS mypkg::user_info( user = this_user ) %]
 [% INCLUDE mypkg::user_info( user = this_user ) %]

 ***** WARNING *****     ***** WARNING *****     ***** WARNING *****
 
 As of version 2.00+ of this package (included with version 1.50 of
 OpenInteract) templates will no longer be fetched from the
 database. They are only stored in the filesystem. A migration script
 is included with this package in C<script/migrate_to_filesystem.pl>.
 
 ***** WARNING *****     ***** WARNING *****     ***** WARNING *****

=head1 DESCRIPTION

Template objects are used throughout OpenInteract -- in fact, on every
single request multiple template objects will be used. (Sometimes
they're known as 'SiteTemplate' objects to distinguish them from the
template processing objects from the Template Toolkit or other
engine.)

Each object represents a template which can be interpreted by the
template processing engine (normally the L<Template|Template Toolkit>)
and replaced with information from the OpenInteract environment along
with data that you decide to display on a page.

However, most of the time you will not deal directly with template
objects. The core OpenInteract modules
L<OpenInteract2::Template::Process|OpenInteract2::Template::Process> and
the custom provider for the Template Toolkit
L<OpenInteract2::Template::Provider|OpenInteract2::Template::Provider>
will retrieve templates for you based on the name and package
specified.

=head1 METHODS

This module exports the constant C<NAME_SEPARATOR>. This will probably
never change from '::', but I have developed an allergy to hardcoding
such things.

=head2 Class Methods

B<parse_name( $full_template_name )>

Parse a full template name (in 'package::name' format) into the
package and name comprising it.

Returns a two-item list: C<( $package, $name )>. If there is no
package in C<$full_template_name>, the first item in the list is
C<undef>.

B<create_name( $package, $template_name )>

Create a fully-qualified template name.

Returns a string with the full template name using C<$package> and
C<$template_name>. If C<$package> is not defined, the fully-qualified
name is just C<$template_name>.

B<name_from_file( $filename )>

Return the template named by C<$filename>. This just strips off the
directory and the extension.

Returns: template name.

=head2 Constructor and Methods Returning Objects

B<new( \%params )>

Create a new object. The C<\%params> can be any of the properties,
plus C<full_name> which will be parsed into the proper C<package> and
C<name> object properties according to C<parse_name()>

B<fetch( $fully_qualified_template, \%params )>

B<fetch_by_package( $package_name, \%params )>

=head2 Object Methods

B<save( \%params )>

B<remove( \%params )>

B<contents()>

Loads contents of this template into the object. This is a
lazy-loading method -- we only read in the contents on demand.

Returns: contents of template

B<set_contents( $contents )>

Sets the contents of the template to C<$contents>. Note that you still
need to call C<save()> to serialize the contents to the filesystem.

B<full_filename()>

Returns a full path to this template.

=head1 PROPERTIES

All properties except 'contents' can be accessed and set by a method
of their property name, e.g.:

 # Get directory
 my $dir = $template->directory;

 # Set directory
 $template->directory( $dir );

B<contents>

This property is accessed through the method C<contents()> and
modified through the method C<set_contents()>; see L<Class Methods>.

B<package>

Package of this template.

B<name>

Name of this template. Usually this is the same as the filename, but
if your template has a filename 'foo.tmpl' the name will still be
'foo'.

B<directory>

Directory from where this template was loaded. After a C<save()> this
may change.

B<filename>

Filename from where this template was loaded. After a C<save()> this
may change.

B<modified_on>

L<DateTime|DateTime> object formed from the time the file was last
modified. (We get this from L<stat>.)

B<is_global>

Boolean defining whether this template came from the global template
directory, either from a package or not.

B<is_package>

Boolean defining whether this template came from a package template
directory.

=head1 TO DO

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
