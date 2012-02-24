package OpenInteract2::Manage::Website::UpdateNewsLinkedList;

# $Id: UpdateNewsLinkedList.pm,v 1.1 2005/10/28 03:20:10 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );

$OpenInteract2::Manage::Website::UpdateNewsLinkedList::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'news_linked_list';
}

sub get_brief_description {
    return "Update the news object fields 'previous_id' and 'next_id' to point to the correct items.";
}

sub run_task {
    my ( $self ) = @_;
    my $action = 'update links';
    my $news_items = eval {
        OpenInteract2::News->fetch_group({
            order => 'posted_on ASC'
        })
    };
    if ( $@ ) {
        $self->_fail( $action, "Error trying to fetch news items: $@" );
        return;
    }

    my $num_items = scalar @{ $news_items };
    unless ( $num_items > 0 ) {
        $self->_fail( "No news objects to update. All done." );
        return;
    }

    $self->notify_observers( progress => "Updating $num_items news items" );

    # Do the first item...

    $news_items->[0]->{next_id} = $news_items->[1]->id;
    eval { $news_items->[0]->save({ skip_security => 1 }) };
    if ( $@ ) {
        my $error = "$@";
        $self->_fail(
            sprintf( "Failed to modify the first item [ID: %s] Error: %s",
                     $news_items->[0]->id, $error )
        );
        return;
    }

    # The middle items...

    for ( my $i = 1; $i < ( $num_items - 1 ); $i++ ) {
        $news_items->[ $i ]->{previous_id} = $news_items->[ $i - 1 ]->id;
        $news_items->[ $i ]->{next_id}     = $news_items->[ $i + 1 ]->id;
        eval { $news_items->[ $i ]->save({ skip_security => 1 }) };
        if ( $@ ) {
            my $error = "$@";
            $self->_fail(
                sprintf( "Failed to modify news item $i [ID: %s] Error: %s",
                         $news_items->[$i]->id, $error )
            );
            return;
        }
    }

    # And the last item

    $news_items->[ $num_items - 1 ]->{previous_id} = $news_items->[ $num_items - 2 ]->id;
    eval { $news_items->[ $num_items - 1 ]->save({ skip_security => 1 }) };
    if ( $@ ) {
        my $error = "$@";
        $self->_fail(
            sprintf( "Failed to modify last news item [ID: %s] Error: %s",
                     $news_items->[ $num_items - 1 ]->id, $error )
        );
    }
    else {
        $self->_add_status({
            is_ok    => 'yes',
            action   => $action,
            message  => "Updated $num_items news objects",
        });
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::UpdateNewsLinkedList - Update all news items with the proper previous/next IDs

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my %PARAMS = ( website_dir => $website_dir );
 my $task = OpenInteract2::Manage->new(
                      'news_linked_list', \%PARAMS );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 REQUIRED OPTIONS

Nothing beyond the website definition.

=head1 STATUS INFORMATION

Each status hashref includes nothing extra.

=head1 COPYRIGHT

Copyright (C) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters, E<lt>chris@cwinters.comE<gt>

