package OpenInteract2::Setup::DependencySource;

# $Id: DependencySource.pm,v 1.2 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( Algorithm::Dependency::Source );
use Algorithm::Dependency::Item;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_INIT );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Setup;

$OpenInteract2::Setup::DependencySource::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub _load_item_list {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );
    my @all_actions = OpenInteract2::Setup->list_actions;
    $log->info( "Setup lists '", scalar( @all_actions ), "' actions available" );
    my @ad_items = ();
    foreach my $action ( @all_actions ) {
        next unless ( $action ); # just in case...
        my $item = eval { OpenInteract2::Setup->new( $action ) };
        if ( $@ ) {
            $log->warn( "Cannot instantiate setup task '$action' ($@); ",
                        "this won't be used to determine dependencies" );
            next;
        }
        my @dep_names = $item->get_dependencies;
        my $dep_name_listing = join( ', ', @dep_names );
        my $dep_item = Algorithm::Dependency::Item->new( $action, @dep_names );
        unless ( $dep_item ) {
            oi_error "Failed to create dep item from '$action' and ",
                     "'$dep_name_listing' (no error given)";
        }
        $log->debug( "Adding setup '$action' with dependencies ",
                     "'$dep_name_listing'" );
        push @ad_items, $dep_item;
    }
    return \@ad_items;
}

1;

__END__

=head1 NAME

OpenInteract2::Setup::DependencySource - Provide dependency information for Algorithm::Dependency

=head1 SYNOPSIS

 my $dep = Algorithm::Dependency::Ordered->new(
     source => OpenInteract2::Setup::DependencySource->new(),
 );

=head1 DESCRIPTION

This class subclasses L<Algorithm::Dependency::Source> so it can
provide setup task names and dependencies to L<Algorithm::Dependency>.

Most of the heavy lifting is done by L<OpenInteract2::Setup> as all
the tasks are registered there. We simply ask that class for all the
tasks, iterate through them and get their dependencies, then return
all that information in a format L<Algorithm::Dependency::Source> can
understand.

=head1 SEE ALSO

L<Algorithm::Dependency>

L<Algorithm::Dependency::Source>

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

