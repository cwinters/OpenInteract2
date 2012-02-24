package OpenInteract2::Manage::Website::ReindexObjects;

# $Id: ReindexObjects.pm,v 1.7 2005/03/18 04:09:50 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Manage::Website::ReindexObjects::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'reindex_objects';
}

sub get_brief_description {
    return "Add all objects of a class, or objects matching a " .
           "particular query, to the full-text index. This can " .
           "be an intensive operation if you have a lot of objects.";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        spops => {
            description =>
                  "Tag for class you'd like to index -- for example " .
                  "use 'news' for 'OpenInteract2::News'",
            is_required => 'yes',
        },
        query => {
            description =>
                  "WHERE clause used to filter objects to add to the " .
                  "index. This is passed directly to the database.",
        },
    }
}

# cannot define validate_param() for 'spops' since we need the context
# to be created... wait for run_task()

sub run_task {
    my ( $self ) = @_;
    my $action = 'reindex objects';
    my $object_tag = $self->param( 'spops' );

    my $obj_class = eval { $self->_check_spops_key( $object_tag ) };
    if ( $@ ) {
        return $self->_fail( $action, "$@" );
    }

    # Ensure the object class is currently indexable

    unless ( $obj_class->isa( 'OpenInteract2::FullTextRules' ) ) {
        my $msg = "Failed! The class '$obj_class' is not indexable. " .
                  "Please set its 'is_searchable' configuration key " .
                  "to 'yes' and list its content field(s) in " .
                  "'fulltext_field'.";
        return $self->_fail( $action, $msg );
    }

    my $where_clause = $self->param( 'query' );
    my $indexer = CTX->fulltext_indexer;
    my ( $count );
    eval {
        $indexer->create_class_index(
            $obj_class, { skip_security => 1,
                          where         => $where_clause })
    };
    if ( $@ ) {
        return $self->_fail( $action, "$@" );
    }
    return $self->_ok( $action, "Added $count objects to index" );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ReindexObjects - Index objects for a particular class

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
     'reindex_objects', { spops => 'news' });
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label = ( $s->{is_ok} eq 'yes' )
                      ? 'OK' : 'NOT OK';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 REQUIRED OPTIONS

=over 4

=item B<spops>=object-key

The key used for the SPOPS object you're trying to reindex. For
instance, 'news' if you're trying to reindex the objects from the
'OpenInteract2::News' class.

=back

=head1 OPTIONAL OPTIONS

=over 4

=item B<query>=where-clause

A WHERE clause that will be sent directly to the database. This will
limit the objects you're trying to reindex.

=back

=head1 STATUS INFORMATION

Each status hashref includes:

=over 4

=item B<is_ok>

Set to 'yes' if the task succeeded, 'no' if not.

=item B<message>

Success/failure message.

=back

=head1 COPYRIGHT

Copyright (C) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

