package OpenInteract2::Action::ObjectActivity;

# $Id: ObjectActivity.pm,v 1.7 2004/02/18 05:25:25 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::CommonSearch );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Action::ObjectActivity::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my $DATE_FMT = '%Y-%m-%d';

# Add the class/name listings

sub _search_form_customize {
    my ( $self, $params ) = @_;
    my ( @names, @classes );
    my $spops_conf = CTX->spops_config;
    foreach my $object_key ( sort keys %{ $spops_conf } ) {
        push @classes, $spops_conf->{ $object_key }{class};
        push @names, $object_key;
    }
    $params->{class_name_list} = \@names;
    $params->{class_list}      = \@classes;
    return undef;
}

# Add date comparisons

sub _search_query_customize {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;

    my ( @add_where, @add_value );
    my $exact_date = $request->param_date( 'action_on' );
    if ( $exact_date ) {
        push @add_where, " ( action_on > ? AND action_on < ? ) ";
        my $date_before = $exact_date->clone->subtract( days => 1 );
        my $date_after  = $exact_date->clone->add( days => 1 );
        push @add_value, $date_before->strftime( $DATE_FMT ),
                         $date_after->strftime( $DATE_FMT );
        $log->is_debug &&
            $log->debug( "Setting criteria action_on to between ",
                         "[$date_before] and [$date_after] (no format)" );
    }

    else {
        my $start_date = $request->param_date( 'action_on_start' );
        my $end_date   = $request->param_date( 'action_on_end' );
        if ( $start_date ) {
            push @add_where, " action_on >= ? ";
            push @add_value, $start_date->strftime( $DATE_FMT );
            $log->is_debug &&
                $log->debug( "Setting criteria action_on to ",
                             "after [$start_date]" );
        }
        if ( $end_date ) {
            push @add_where, " action_on <= ?";
            push @add_value, $end_date->strftime( $DATE_FMT );
            $log->is_debug &&
                $log->debug( "Setting criteria action_on to ",
                             "before [$end_date]" );
        }
    }

    if ( scalar @add_where ) {
        my $where = $self->param( 'c_search_query_where' ) || [];
        my $value = $self->param( 'c_search_query_values' ) || [];
        push @{ $where }, @add_where;
        push @{ $value }, @add_value;
        $self->param( c_search_query_where => \@add_where );
        $self->param( c_search_query_values => \@add_value );
    }

    my $order = $self->param( 'order' )
                || $request->param( 'order' )
                || 'action_on DESC';
    $self->param( c_search_results_order => $order );
}

sub _search_customize {
    my ( $self, $template_params ) = @_;
    my $iter = $template_params->{iterator};
    my $stocked_activities = $self->_set_object_info( $iter );
    $template_params->{activity_list} = $stocked_activities;
    delete $template_params->{iterator};
    return undef;
}

sub _set_object_info {
    my ( $self, $activity_iter ) = @_;
    $log ||= get_logger( LOG_APP );

    my @new_activity = ();
    my $user_class = CTX->lookup_object( 'user' );
    my ( %user_cache );
    while ( my $rec = $activity_iter->get_next ) {
        my $info = $rec->as_data_only;
        my $object_class = $rec->{class};

        unless ( $user_cache{ $rec->{action_by} } ) {
            my $user = eval { $user_class->fetch( $rec->{action_by} ) };
            if ( $@ or ! $user ) {
                $info->{login_name} = 'unknown';
            }
            else {
                $user_cache{ $rec->{action_by} } = $user->object_description;
            }
        }
        if ( my $user = $user_cache{ $rec->{action_by} } ) {
            $info->{login_name}       = $user->{title};
            $info->{user_display_url} = $user->{url};
        }

        $info->{object_type} = $object_class->CONFIG->{object_name};

        if ( $info->{action} eq 'remove' ) {
            $info->{title} = $info->{object_id};
        }
        else {
            my $object = eval { $object_class->fetch( $rec->{object_id} ) };
            if ( $@ or ! $object ) {
                $info->{title}       = 'n/a';
            }
            else {
                my $object_info = $object->object_description;
                $info->{title}       = $object_info->{title};
                $info->{display_url} = $object_info->{url};
            }
        }
        $log->is_debug &&
            $log->debug( "Adding activity: [$info->{action}] [$info->{action_on}] ",
                         "[$info->{class}] [$info->{object_id}] by ",
                         "[$info->{login_name}]" );
        push @new_activity, $info;
    }
    return \@new_activity;
}

1;