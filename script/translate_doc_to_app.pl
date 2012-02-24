#!/usr/bin/perl

use strict;
use File::Basename        qw( dirname );
use File::Path            qw( mkpath );
use File::Spec::Functions qw( rel2abs splitdir );
use OpenInteract2::Util;
use Template;

unless ( -f 'package.ini' ) {
    die "Run this script in your package's topmost directory.\n";
}

my @full_dirs = splitdir( rel2abs( '.' ) );
my $pkg_name  = pop( @full_dirs );
my $class_name = ucfirst $pkg_name;
$class_name =~ s/_(\w)/\U$1\U/g;
my $doc_file = "doc/$pkg_name.pod";
my $pod = ( -f $doc_file ) ? OpenInteract2::Util->read_file( $doc_file ) : '';
my $app_file = "OpenInteract2/App/$class_name.pm";
mkpath( dirname( $app_file ) );

my $template = Template->new();
$template->process( \*DATA, {
    class_name   => $class_name,
    package_name => $pkg_name,
    pod          => $pod
}, $app_file ) || die "Cannot generate App file: ", $template->error();
print "Created $app_file ok\n";

__DATA__
package OpenInteract2::App::[% class_name %];

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::[% class_name %]::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::[% class_name %]::EXPORT  = qw( install );

sub get_brick_name {
    return '[% package_name %]';
}

# Not a method, just an exported sub
sub install {
    my ( $website_dir ) = @_;
    my $manage = OpenInteract2::Manage->new( 'install_package' );
    $manage->param( website_dir   => $website_dir );
    $manage->param( package_class => __PACKAGE__ );
    return $manage->execute;
}

__END__

=pod

=head1 NAME

OpenInteract2::App::[% class_name %] - This application will do everything!

[% pod %]

=cut
