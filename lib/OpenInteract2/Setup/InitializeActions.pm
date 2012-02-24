package OpenInteract2::Setup::InitializeActions;

# $Id: InitializeActions.pm,v 1.3 2005/03/29 16:58:46 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::InitializeActions::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'initialize actions';
}

sub get_dependencies {
    return ( 'read action table' );
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $action_table = $ctx->action_table;
    unless ( ref $action_table eq 'HASH' ) {
        $log->warn( "Cannot initialize actions: no action table ",
                    "available from context." );
        return;
    }
    $self->_require_action_classes( $action_table );
    $self->_initialize_action_classes( $action_table );
}


sub _require_action_classes {
    my ( $self, $action_table ) = @_;
    my %uniq_classes = ();
    while ( my ( $name, $action_info ) = each %{ $action_table } ) {
        my $class = $action_info->{class};
        next unless ( $class );
        $log->info( "Action '$name' is class '$class'" );
        $uniq_classes{ $class }++;
    }
    my @classes = keys %uniq_classes;
    my $req = OpenInteract2::Setup->new(
        'require classes',
        classes      => \@classes,
        classes_type => 'Action classes',
    )->run();
    $self->param( classes => \@classes );
}

sub _initialize_action_classes {
    my ( $self, $action_table ) = @_;
    my @success = ();
    while ( my ( $name, $action_info ) = each %{ $action_table } ) {
        my $action_class = $action_info->{class};
        next unless ( $action_class );
        $log->debug( "Initializing action '$name' class '$action_class'" );
        eval { $action_class->init_at_startup( $name ) };
        if ( $@ ) {
            $log->error( "Caught error initializing action class ",
                         "'$action_class': $@" );
        }
        else {
            $log->info( "Initialized action class '$action_class' ok" );
            push @success, $action_class;
        }
    }
    $self->param( initialized => \@success );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::InitializeActions - Include and initialize all OpenInteract2 actions

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'initialize actions' );
 $setup->run();

=head1 DESCRIPTION

This setup action brings in and initializes all action classes. Here's
the procedure:

=over 4

=item *

Find all actions from the action table with a 'class' property.

=item *

Call 'require()' on each of those found classes.

=item *

Once all classes are brought in, call 'init_at_startup()' on each
action class. Any exceptions thrown are caught and logged, but we
continue with the process. A class is considered successfully
initialized if it does not throw an exception.

=back

=head2 Setup Metadata

B<name> - 'initialize actions'

B<dependencies> - 'read action table'

=head1 SEE ALSO

L<OpenInteract2::Setup>

L<OpenInteract2::Action>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

