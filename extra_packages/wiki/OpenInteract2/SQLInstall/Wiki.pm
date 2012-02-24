package OpenInteract2::SQLInstall::Wiki;

# $Id: Wiki.pm,v 1.1 2004/06/03 13:04:43 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );
use File::Path;
use OpenInteract2::Context;

my %VALID_DRIVERS = (
    mysql  => 'CGI::Wiki::Setup::MySQL',
    Pg     => 'CGI::Wiki::Setup::Pg',
    SQLite => 'CGI::Wiki::Setup::SQLite',
);

sub install_structure {
    my ( $self ) = @_;
    my $ctx = OpenInteract2::Context->instance;
    my $wiki_action = $ctx->lookup_action( 'wiki' );
    my $ds_name = $wiki_action->param( 'datasource' );
    my $ds_info = $ctx->lookup_datasource_config( $ds_name );
    my $ds = $ctx->datasource( $ds_name );

    my $wiki_setup_class = $VALID_DRIVERS{ $ds_name };
    eval "require $wiki_setup_class";
    if ( $@ ) {
        $self->_set_state( 'wiki structures',
                           undef,
                           "Error requiring setup class '$wiki_setup_class': $@",
                           undef );
        return;
    }

    {
        no strict 'refs';
        my $setup_sub = *{ $wiki_setup_class . '::setup' };
        $setup_sub->( $ds );
    }
    $self->_set_state( 'wiki structures',
                       1,
                       undef,
                       "Structures setup ok using $wiki_setup_class" );

    # Also sneak in the creation of the wiki indices...
    my $index_dir = $wiki_action->param( 'index_dir' );
    my $full_index_dir =
        join( '/', $ctx->lookup_directory( 'website' ), $index_dir );
    File::Path::mkpath( $full_index_dir );
    $self->_set_state( 'wiki index dir',
                       1,
                       undef,
                       "Created wiki index directory at '$full_index_dir'" );
}

1;
