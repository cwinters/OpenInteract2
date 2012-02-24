package OpenInteract2::App;

# $Id: App.pm,v 1.3 2005/03/13 18:35:03 lachoy Exp $

use strict;
use base qw( Class::Factory Class::Accessor::Fast );
use OpenInteract2::Brick;
use OpenInteract2::Config::Package;
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Manage;
use OpenInteract2::Util;

$OpenInteract2::App::VERSION  = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw(
    name version module_dependencies
    author_names author_emails url has_sql_structures
);
__PACKAGE__->mk_accessors( @FIELDS );

# CLASS METHODS

sub list_apps {
    my ( $class ) = @_;
    return $class->list_registered_types;
}


# OBJECT METHODS

sub init {
    my ( $self ) = @_;
    my $brick = OpenInteract2::Brick->new( $self->get_brick_name );
    my $package_ini_info = $brick->load_resource( 'package.ini' );
    my $package_conf = OpenInteract2::Config::Package->new({
        content => $package_ini_info->{content},
    });
    $self->name( $package_conf->name );
    $self->version( $package_conf->version );
    $self->module_dependencies( $package_conf->module );
    $self->author_names( [ $package_conf->author_names ] );
    $self->author_emails( [ $package_conf->author_emails ] );
    $self->url( $package_conf->url );

    my $manifest_info = $brick->load_resource( 'MANIFEST' );
    my @struct_files = grep /^struct/, split /\r?\n/, $manifest_info->{content};
    $self->has_sql_structures( scalar @struct_files );
    return $self;
}


sub install        { _must_implement( 'install', @_ ) }
sub get_brick_name { _must_implement( 'get_brick_name', @_ ) }

sub _must_implement {
    my ( $method, $item ) = @_;
    my $class = ref( $item ) || $item;
    oi_error "Class '$class' must implement method '$method'";
}

OpenInteract2::Util->find_factory_subclasses( 'OpenInteract2::App' );

1;

__END__

=head1 NAME

OpenInteract2::App - Base class for CPAN-distributable OpenInteract application bundles

=head1 SYNOPSIS

 # Install to perl an application from CPAN:
 
   # using CPAN.pm:
   $ perl -MCPAN -e 'install OpenInteract2::App::MyApp'
 
   # manually:
   $ tar -zxf OpenInteract2-App-MyApp-1.02.tar.gz
   $ cd OpenInteract2-App-MyApp-1.02/
   $ perl Makefile.PL
   $ make
   $ make install
 
 # Install to website an application (aka package) from the command-line:
 perl -MOpenInteract2::App::MyApp -e 'install( "/path/to/my_website" )'
 
 # Same thing, but from the command-line using oi2_manage:
 oi2_manage install_package --package_class=OpenInteract2::App::MyApp
 
 # Programmatically:
 
 # Instantiate an application object
 my $app = OpenInteract2::App->new( 'myapp' )
               || die "No application 'myapp' installed";
 
 # Display some information about the application
 print "Application bundle info:\n",
       "Version:      ", $app->version, "\n",
       "Dependencies: ", join( ", ", $app->module_dependencies, "\n",
       "Authors:      ", join( ", ", $app->author_names ), "\n",
       "URL:          ", $app->url, "\n",
       "Has SQL DDL?  ", $app->has_sql_structures, "\n";
 
 # Install the application
 eval { $app->install( '/path/to/my_website' ) };
 if ( $@ ) {
     die "Cannot install application: $@\n";
 }
 else {
     print "Application installed ok!";
 }

=head1 DESCRIPTION

This is a base class for CPAN-distributable OpenInteract
applications. Previously the only way to distribute and install an
OpenInteract application was with a package bundled up into a zip
file. This class and supporting tools provide a more standard means of
distributing an application while taking advantage of all that CPAN
has to offer.

=head1 CLASS METHODS

B<new( $app_name )>

Create a new application object of type C<$app_name>.

B<list_apps()>

List all available applications installed on your system.

=head1 OBJECT METHODS

B<install( $website_dir )>

Installs the application to C<$website_dir>.

=head1 PROPERTIES

B<version>

B<module_dependencies>

B<author_names>

B<author_emails>

B<url>

B<has_sql_structures>

=head1 SEE ALSO

L<OpenInteract2::Brick>

L<OpenInteract2::Manage::Package::CreateCPAN>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
