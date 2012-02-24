package OpenInteract2::PageDirectory;

# $Id: PageDirectory.pm,v 1.10 2005/03/18 04:09:44 lachoy Exp $

use strict;
use File::Basename ();
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

@OpenInteract2::PageDirectory::ISA     = qw( OpenInteract2::PageDirectoryPersist );
$OpenInteract2::PageDirectory::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub list_directory_actions {
    my ( $class ) = @_;
    my $action_table = CTX->action_table;
    return [ sort grep { $action_table->{ $_ }{is_directory} eq 'yes' }
                  keys %{ $action_table } ];
}


# Ensures that we search only for directories with a '/' at the end,
# and also that we find parent directories that have 'subdirs_inherit'
# flagged on

sub fetch_by_directory {
    my ( $class, $dir_name ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $dir_name ) {
        oi_error "Must pass directory to fetch";
    }

    my $initial_dir_name = $class->_ensure_trailing_slash( $dir_name );
    $log->is_debug &&
        $log->debug( "Initial dir fetch attempt '$initial_dir_name'" );
    my $dir = $class->fetch( $initial_dir_name );
    if ( $dir ) {
        $log->is_debug &&
            $log->debug( "Directory object found matching ",
                         "'$initial_dir_name'" );
        return $dir;
    }

    # We only want parents that have inheritance enabled

    my $where = ' subdirs_inherit = ? ';
    my @value = ( 'yes' );

    my $all_parents = $class->explode_dir( $initial_dir_name );

    # First item is the directory itself -- don't need it

    if ( scalar @{ $all_parents } > 1 ) { shift @{ $all_parents } }

    $log->is_debug &&
        $log->debug( "Found parents of '$dir': [",
                     join( "' '", @{ $all_parents } ), "'" );


    # Form a WHERE clause from the parents

    my $parent_where = join( ' OR ', map { "directory = ?" }
                                         @{ $all_parents } );
    $where .= " AND ( $parent_where ) ";
    push @value, @{ $all_parents };
    $log->is_debug &&
        $log->debug( "Trying to find parents with '$where' and dirs: ",
                     join( ', ', @value ) );
    my $parent_dirs = $class->fetch_group({ where => $where,
                                            value => \@value });

    # No parents found (most of the time)

    return undef unless ( ref $parent_dirs eq 'ARRAY' );
    my $num_parents = scalar @{ $parent_dirs };
    return undef unless ( $num_parents > 0 );

    # Only one parent found (what happens most of the rest of the time)

    return $parent_dirs->[0] if ( $num_parents == 1 );

    # With multiple parents, we prefer to return the one with a longer
    # name since they're closer to the original directory.

    my ( $immediate_parent );
    my $max_dir_length = 0;
    foreach my $parent_dir ( @{ $parent_dirs } ) {
        my $this_dir_length = length $parent_dir->{directory};
        if ( $this_dir_length > $max_dir_length ) {
            $immediate_parent = $parent_dir;
            $max_dir_length = $this_dir_length;
        }
    }
    return $immediate_parent;
}



# TODO: Is there a reason we're not using 'split' here?

sub explode_dir {
    my ( $class, $dir ) = @_;
    $dir =~ s|\\|/|g;
    my @exploded = ( $dir );
    while ( $dir ne '/' ) {
        my $next_parent = File::Basename::dirname( $dir );
        $next_parent = "$next_parent/" unless ( $next_parent eq '/' );
        push @exploded, $next_parent;
        $dir = $next_parent;
    }
    return \@exploded;
}


sub _ensure_trailing_slash {
    my ( $class, $dir ) = @_;
    return unless ( $dir );
    $dir = "$dir/" unless ( $dir =~ m|/$| );
    return $dir;
}


########################################
# RULES
########################################

# Here we add a rule so we ensure that every directory has a '/' at
# the end

sub ruleset_factory {
    my ( $class, $rs_table ) = @_;
    push @{ $rs_table->{pre_save_action} }, \&check_directory_syntax;
    return __PACKAGE__;
}

sub check_directory_syntax {
    my ( $self ) = @_;
    die "No directory defined" unless ( $self->{directory} );
    return $self->{directory} = $self->_ensure_trailing_slash( $self->{directory} );
}

1;

__END__

=head1 NAME

OpenInteract2::PageDirectory - Methods supporting the directory handler objects

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

B<list_directory_actions()>

Scans the action table and finds all available actions known to be
directory handlers.

Returns an arrayref of action names.

B<fetch_by_directory( $dir )>

Try to retrieve a directory object by C<$dir>, or retrieve its closest
parent directory that has 'subdirs_inherit' set. If you are using the
directory to execute an action, you should B<always> use this.

B<explode_dir( $dir )>

Utility method that splits up C<$dir> into parent directories. So
given:

 my $dir_pieces = OpenInteract2::PageDirectory->explode_dir( '/path/to/my/home/' );

You would have:

 [ '/path/to/my/home/',
   '/path/to/my/',
   '/path/to/',
   '/path/',
   '/' ]

=head1 RULES

B<pre_save_action>

Ensure that every directory saved to the database has a '/' at the
end.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
