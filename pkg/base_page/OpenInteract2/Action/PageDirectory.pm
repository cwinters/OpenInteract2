package OpenInteract2::Action::PageDirectory;

# $Id: PageDirectory.pm,v 1.7 2004/04/09 11:38:26 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::CommonUpdate
             OpenInteract2::Action::CommonAdd
             OpenInteract2::Action::CommonRemove );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure            qw( SEC_LEVEL_WRITE );

$OpenInteract2::Action::PageDirectory::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub list {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my %params = ();
    $params{iterator} = eval {
        CTX->lookup_object( 'page_directory' )->fetch_iterator;
    };
    if ( $@ ) {
        my $msg = "Failed to fetch directory handlers: $@";
        $log->error( $msg );
        $self->param_add( error_msg => $msg );
    }
    return $self->generate_content(
        \%params, { name => 'base_page::page_directory_handler_list' } );
}

# Just grab all the actions available

sub _display_add_customize {
    my ( $self, $params ) = @_;
    return $self->_display_customize( $params );
}

sub _display_form_customize {
    my ( $self, $params ) = @_;
    return $self->_display_customize( $params );
}

sub _display_customize {
    my ( $self, $params ) = @_;
    $log ||= get_logger( LOG_APP );

    $params->{action_list} = eval {
        CTX->lookup_object( 'page_directory' )->list_directory_actions
    };
    if ( $@ ) {
        my $msg = "Failed to lookup action types: $@";
        $log->error( $msg );
        $self->param_add( error_msg => $msg );
    }
    return undef;
}

sub _update_customize {
    my ( $self, $dir, $old_data, $update_options ) = @_;
    $log ||= get_logger( LOG_APP );

    # If the user changed the directory, then we need to set the ID so
    # the UPDATE works properly.

    if ( $old_data->{directory} and $dir->{directory} ne $old_data->{directory} ) {
        $log->is_debug &&
            $log->debug( "User changed directory from ",
                         "'$old_data->{directory}' ",
                         "to '$dir->{directory}'" );
        $update_options->{use_id} = $old_data->{directory};
    }
    return undef;
}

1;

