package OpenInteract2::ResultsManage;

# $Id: ResultsManage.pm,v 1.14 2005/03/18 04:09:48 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast );
use File::Basename           qw( basename );
use File::Spec::Functions    qw( catfile );
use IO::File;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::ResultsIterator;
use Scalar::Util             qw( blessed );
use SPOPS::Utility;

$OpenInteract2::ResultsManage::VERSION = sprintf("%d.%02d", q$Revision: 1.14 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant FILENAME_WIDTH => 10;

my $LOCK_EXT         = 'lock';
my $RECORD_SEP       = ' // ';
my $EXTRA_NAME_SEP   = ',';

my @FIELDS  = qw(
    search_id filename keywords
    min max per_page page_num
    num_records time date extra_name result_list
);
__PACKAGE__->mk_accessors( @FIELDS );


# NOTE: All internal methods should die() instead of throwing an
# exception, since we wrap everything that could fail in an eval at
# the user entrance level

########################################
# CLASS METHODS

sub new {
    my ( $pkg, $params ) = @_;
    my $class = ref $pkg || $pkg;
    my %data = map { $_ => $params->{ $_ } } @FIELDS;
    return bless( \%data, $class );
}

sub find_page_boundaries {
    my ( $class, $page_num, $per_page ) = @_;
    return ( 0, 0 ) unless ( $page_num and $per_page );
    my $max = $page_num * $per_page;
    my $min = $max - $per_page;
    return ( $min, $max );
}

sub set_page_boundaries {
    my ( $self, $page_num, $per_page ) = @_;
    $self->page_num( $page_num );
    $self->per_page( $per_page );
    my ( $min, $max ) = $self->find_page_boundaries( $page_num, $per_page );
    $self->min( $min );
    $self->max( $max );
}

# Note that $item can be a class or an object -- if object, we'll take
# the number of records from it.

sub find_total_page_count {
    my ( $item, $per_page, $num_records ) = @_;
    if ( blessed( $item ) ) {
        $per_page    ||= $item->per_page;
        $num_records ||= $item->num_records;
    }
    return 0 unless ( $per_page and $num_records );

    my $num_pages = $num_records / $per_page;
    return ( int $num_pages != $num_pages )
             ? int( $num_pages ) + 1 : int $num_pages;
}

sub get_metadata {
    my ( $item, $search_id ) = @_;
    $log ||= get_logger( LOG_APP );

    my $self = ( ref( $item ) )
                 ? $item : $item->new();
    $self->search_id( $search_id );
    my $results_filename = $self->_build_results_filename;

    return {} unless ( -f $results_filename );
    eval {
        open( META, $results_filename ) || die "Cannot open '$results_filename': $!"
    };
    if ( $@ ) {
        $log->error( "Error opening file '$results_filename' to ",
                     "read metadata. $@" );
        return {};
    }
    my %meta_info = ();
    while ( <META> ) {
        chomp;
        s/^\s+//;
        s/\s+$//;
        last unless ( s/^\#\s*// );
        my ( $k, $v ) = split /\s*:\s*/, $_, 2;
        if ( $k =~ /^extra/ ) {
            push @{ $meta_info{extra_field} }, $v;
        }
        else {
            $meta_info{ $k } = $v;
        }
    }
    close( META );
    $meta_info{date} = scalar localtime( $meta_info{time} );
    return \%meta_info;
}


########################################
# OBJECT METHODS

# Clear out all information in an object

sub clear {
    my ( $self ) = @_;
    $self->{ $_ } = undef  for ( keys %{ $self } );
    return $self;
}

sub assign_metadata {
    my ( $self, $metadata ) = @_;
    for my $field ( @FIELDS ) {
        $self->$field( $metadata->{ $field } ) if ( $metadata->{ $field } );
    }
}

########################################
# SAVE RESULTS

sub save {
    my ( $self, $to_save, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    if ( ! $to_save
         || ( ref $to_save eq 'ARRAY' && ! scalar @{ $to_save } )
         || ( UNIVERSAL::isa( $to_save, 'SPOPS::Iterator' ) && ! $to_save->has_next ) ) {
        $log->error( "Bailing out of saving search results -- nothing to save!" );
        return $self;
    }

    $log->is_info &&
        $log->info( "Trying to store search results" );

    my %params = ( extra_name  => $p->{extra_name} );

    # First ensure we have a results directory in the object

    unless ( -d $self->directory ) {
        oi_error "No configured results directory exists. ",
                 "(Tried: ", $self->directory, "). Please ensure that ",
                 "the server configuration key 'dir.overflow' is defined.";
    }

    # Generate a search ID and get the filename, then lock the
    # filename from further use while we're working

    $params{search_id} = $self->generate_search_id;
    $log->is_debug &&
        $log->debug( "Generated search ID '$params{search_id}'" );
    $self->_lock_results( $params{search_id} );
    my ( $num_records );
    my $out = IO::File->new();

    # First write out the actual data, then write out the metadata

    eval {
        my $results_file = $self->_build_results_filename( $params{search_id} );
        $self->filename( basename( $results_file ) );
        $out->open( "> $results_file" )
                    || die "Cannot open '$results_file' for writing: $!\n";
        $num_records = $self->_persist( $out, $to_save, \%params );
        $out->close();
    };

    # If we find an error anywhere along the way, be sure the files
    # are closed (paranoid, since falling out of scope should do it),
    # clear the lockfile and die.

    if ( $@ ) {
        $log->error( "Search result save failure. $@" );
        $out->close();
        $self->_clear_results( $params{search_id} );
        oi_error "Search result save failure: $@";
    }

    # Clear out the lockfile

    $self->_unlock_results( $params{search_id} );

    # Set various information into the object

    $log->is_info &&
        $log->info( "Results ($num_records) saved ok under ID $params{search_id}" );
    $self->num_records( $num_records );
    $self->search_id( $params{search_id} );
    return $self;
}


sub _persist {
    my ( $self, $out, $to_save, $params ) = @_;

    my ( $results );

    # First we have to generate the content to write out

    if ( ref $to_save eq 'ARRAY' ) {
        $results = $self->_generate_records_from_list( $to_save, $params );
    }
    elsif ( UNIVERSAL::isa( $to_save, 'SPOPS::Iterator' ) ) {
        $results = $self->_generate_records_from_iterator( $to_save, $params );
    }
    else {
        die "Item to be saved must either be arrayref or iterator!\n";
    }

    my $num_results = scalar( @{ $results } );
    # next, start writing the file with the metadata...

    $out->print(
        join( "\n",
              "# time:        " . time,
              "# num_records: " . $num_results,
              "# filename:    " . $self->filename,
              "# directory:   " . $self->directory,
              "# search_id:   " . $params->{search_id} ),
        "\n",
    );

    my $extra_name = $params->{extra_name} || [];
    my $num_extra = 0;
    foreach my $name ( @{ $extra_name } ) {
        $num_extra++;
        $out->print( "# extra $num_extra: ", $name, "\n" );
    }

    # ...and then the actual records

    $out->print( join( "\n", @{ $results } ) );

    return $num_results;
}


sub _generate_records_from_list {
    my ( $self, $record_list ) = @_;

    my @all_records = ();
    foreach my $item ( @{ $record_list } ) {
        next unless ( $item );
        my @result_info = ();
        if ( blessed( $item ) ) {
            push @result_info, ref( $item ), $item->id;
        }
        elsif ( ref( $item ) eq 'ARRAY' ) {
            @result_info = @{ $item };
        }
        else {
            die "Record #", scalar( @all_records ), " is neither an object ",
                "nor an arrayref. (Record: $item )\n";
        }
        push @all_records, join( $RECORD_SEP, @result_info );
    }
    $log->is_debug &&
        $log->debug( "Generated ", scalar( @all_records ), " records ",
                     "from list" );
    return \@all_records;
}


sub _generate_records_from_iterator {
    my ( $self, $iterator ) = @_;
    my @all_records = ();
    while ( my $item = $iterator->get_next ) {
        push @all_records, join( $RECORD_SEP, ref( $item ), scalar( $item->id ) );
    }
    return \@all_records;
}



########################################
# RETRIEVE RESULTS

sub retrieve {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $self->search_id ) {
        oi_error "Cannot retrieve results without a search_id! Please ",
                 "set at object initialization or as a property of the ",
                 "object before running retrieve().";
    }

    my $return_type = lc $p->{return_type} || 'list';

    # 'min' and 'max' can be properties or passed in

    my $min = $p->{min} || $self->min;
    my $max = $p->{max} || $self->max;
    $self->min( $min );
    $self->max( $max );

    # Clear out the number of records

    $self->num_records(0);

    $log->is_info &&
        $log->info( "Retrieving raw search results for ",
                     "ID '", $self->search_id, "'" );

    my $raw_results = $self->_retrieve_raw_results;
    $log->is_info &&
        $log->info( "Found: ", scalar @{ $raw_results }, " results; asked ",
                    "to return '$return_type'" );

    return ( $return_type eq 'iterator' )
             ? $self->_retrieve_iterator( $raw_results, $p )
             : $raw_results;
}

# Retrieve the results and store them in the object, respecting the
# min/max set in the object.

sub _retrieve_raw_results {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $self->search_id ) {
        oi_error "No search_id defined in object!";
    }

    my $meta_info = $self->get_metadata( $self->search_id );
    $self->assign_metadata( $meta_info );

    $log->is_debug &&
        $log->debug( "[Run on: $meta_info->{date}] ",
                     "[Saved: $meta_info->{num_records}] ",
                     "[Type: $meta_info->{record_class}]" );
    if ( $self->num_records <= 0 ) {
        return []
    }

    my $filename = $self->_build_results_filename;
    eval {
        open( RESULTS, $filename )
            || die "Cannot open '$filename' for reading: $!"
    };
    if ( $@ ) {
        $log->error( "Search result retrieval failure. $@" );
        return [];
    }

    my @records = ();

    my ( $min, $max ) = ( $self->min, $self->max );
    my $count = 1;

    while ( <RESULTS> ) {
        next if ( /^\#/ );
        if ( $min and $count < $min ) { $count++; next; }
        if ( $max and $count > $max ) { last; }
        chomp;
        push @records, [ split /$RECORD_SEP/, $_ ];
        $count++;
    }
    close( RESULTS );

    # Reset these since we've already got the data...

    $self->min(0);
    $self->max(0);

    $self->result_list( \@records );
    return $self->result_list;
}


# Note that this only works on saved SPOPS objects

sub _retrieve_iterator {
    my ( $self, $raw_results, $p ) = @_;
    return OpenInteract2::ResultsIterator->new({
        results       => $raw_results,
        extra_name    => $self->extra_name,
        skip_security => $p->{skip_security}
    });
}


sub assign_results_to_object {
    my ( $self, $result_info ) = @_;
    for ( @FIELDS ) {
        $self->$_( $result_info->{ $_ } );
    }
    return $self;
}


#######################################
# FILENAME/DIRECTORY METHODS

sub directory {
    my ( $self, $directory ) = @_;
    if ( $directory ) {
    }
    unless ( $self->{directory} ) {
        $self->{directory} = CTX->lookup_directory( 'overflow' );
    }
    return $self->{directory};
}

sub _build_results_filename {
    my ( $self, $p_search_id ) = @_;
    my $search_id = $self->search_id || $p_search_id;
    unless ( $search_id ) {
        oi_error "Cannot build a results filename without a ",
                 "search_id as property or parameter!";
    }
    return catfile( $self->directory, $search_id );
}


sub _build_lock_filename {
    my ( $self, $p_search_id ) = @_;
    my $search_id = $self->search_id || $p_search_id;
    unless ( $search_id ) {
        oi_error "Cannot build a lock filename without a search_id ",
                 "as property or parameter!";
    }
    return catfile( $self->directory, "$search_id.$LOCK_EXT" );
}


sub get_all_result_filenames {
    my ( $self ) = @_;
    opendir( RESULTS, $self->directory )
             || oi_error "Cannot open results directory '", $self->directory, "': $!";
    my @results_files = grep ! /\./, grep { length $_ == FILENAME_WIDTH } readdir( RESULTS );
    closedir( RESULTS );
    return \@results_files;
}


# Clear out the results, including the lockfile. This is called if we
# encounter some sort of error in the middle of writing. Don't die
# during this method because if this is called we have bigger
# problems...

sub _clear_results {
    my ( $self, $search_id ) = @_;
    eval { $self->_unlock_results( $search_id ) };
    unlink( $self->_build_results_filename( $search_id ) );
}


########################################
# SEARCH ID
########################################

# Don't save the 'search_id' parameter into the object yet, since
# this method only ensures that we *can* create a file with the
# search_id

sub generate_search_id {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $results_dir = $self->directory;
    unless ( -d $results_dir ) {
        $log->error( "Search results directory '$results_dir'",
                      "is not a directory" );
        oi_error "Configuration option for writing search results ",
                 "'$results_dir' is not a directory";
    }
    unless ( -w $results_dir ) {
        $log->error( "Search results directory '$results_dir' ",
                     "is not writeable" );
        oi_error "Configuration option for writing search results ",
                 "'$results_dir' exists but is not writeable";
    }
    my $iterations = 0;
    my ( $search_id );
FIND_ID:
    while ( 1 ) {
        $search_id = SPOPS::Utility->generate_random_code( FILENAME_WIDTH );
        my $filename = $self->_build_results_filename( $search_id );
        my $lockfile = $self->_build_lock_filename( $search_id );
        if ( $iterations > 20 ) {
            oi_error "Tried 20 times to get a search ID in '$results_dir'; ",
                     "this indicates that either the random number generator ",
                     "is malfunctioning or there are so many files in the ",
                     "directory that we cannot generate a unique ID.";
        }
        $iterations++;
        next if ( -f $filename || -f $lockfile );
        $log->is_debug && $log->debug( "Found unused search filename ",
                                       "in '$results_dir': '$search_id'" );
        last FIND_ID;
    }
    return $search_id;
}


########################################
# LOCKING
########################################

# Lock the results file using another file

sub _lock_results {
    my ( $self, $search_id ) = @_;
    my $lock_file = $self->_build_lock_filename( $search_id );
    open( LOCK, "> $lock_file" )
        || oi_error "Cannot open lockfile '$lock_file' for writing: $!";
    print LOCK scalar localtime;
    close( LOCK );
}


# Unlock the results file by deleting the lockfile.

sub _unlock_results {
    my ( $self, $search_id ) = @_;
    my $lock_file = $self->_build_lock_filename( $search_id );
    return unless ( -f $lock_file );
    unlink( $lock_file )
          || oi_error "Cannot remove lockfile '$lock_file': $!";
}

1;

__END__

=head1 NAME

OpenInteract2::ResultsManage - Save and retrieve generic search results

=head1 SYNOPSIS

 use OpenInteract2::ResultsManage;
 
 # Basic usage
 
 ... perform search ...
 
 my $results = OpenInteract2::ResultsManage->new();
 $results->save( \@id_list );
 $request->session->{this_search_id} = $results->{search_id};
 
 ... another request from this user ...
 
 my $results = OpenInteract2::ResultsManage->new({
     search_id => $request->session->{this_search_id}
 });
 my $result_list = $results->retrieve();
 
 # Use with paged results
 
 my $results = OpenInteract2::ResultsManage->new();
 $results->save( \@id_list );
 $request->session->{this_search_id} = $results->{search_id};
 my $page_num = $request->param( 'pagenum' );
 my ( $min, $max ) = $results->find_page_boundaries( $page_num, $HITS_PER_PAGE );
 my ( $results, $total_count ) = $results->retrieve({ min => $min, max => $max } );
 my $total_pages = $results->find_total_page_count( $HITS_PER_PAGE );
 my $total_hits = $results->{num_records};
 
 # Can now print "Page $page_num of $total_pages" or you
 # can pass this information to the template and use the
 # 'page_count' component and pass it 'total_pages',
 # 'current_pagenum', and a 'url' to get back to this page:
 
 [%- PROCESS page_count( total_pages     = 5,
                         current_pagenum = 3,
                         url             = url ) -%]
 
 Displays:
 
 Page [<<] [1] [2] 3 [4] [5] [>>]
 
 (Where the items enclosed by '[]' are links.)

=head1 DESCRIPTION

This class has methods to enable you to easily create paged result
lists. This includes saving your results to disk, retrieving them
easily and some simple calculation functions for page number
determination.

=head1 PUBLIC METHODS

The following methods are public and available for OpenInteract
application developers.

B<save( $stuff_to_save, \%params )>

Saves a list of things to be retrieved later. The C<$stuff_to_save>
can be an arrayref of ID values (simple scalars), an arrayref of SPOPS
objects, or an L<SPOPS::Iterator|SPOPS::Iterator> implementation all
primed and ready to go. If objects are passed in via a list or an
iterator, we call C<-E<gt>id()> on each to get the ID value to save.

If objects are used, we also query each one for its class and save
that information in the search results. Whether you have a homogenous
resultset or not affects the return values. If it is a homogenous
resultset we note the class for all objects in the search results
metadata, which is saved in a separate file from the results
themselves. This enables us to create an iterator from the results if
needed.

Parameters:

=over 4

=item *

B<class> ($) (optional)

You can force all the IDs passed in to be of a particular class.

=item *

B<extra> (\@) (optional)

Each item represents extra information to save along with each
result. Each item must be either a scalar (which saves one extra item)
or an arrayref (which saves a number of extra items).

=item *

B<extra_name> (\@)  (optional)

If you specify extra information you need to give each one a name.

=back

Returns: an ID you can use to retrieve the search results using
the C<retrieve()> or C<retrieve_iterator()> methods. If
you misplace the ID, you cannot get the search results back.

Side effects: the ID returned is also saved in the 'search_id' key of
the object itself.

Example:

 my $results = OpenInteract2::ResultsManage->new();
 my $search_id = $results->save({ \@results,
                                  { force_mixed => 1,
                                    extra       => \@extra_info,
                                    extra_name  => [ 'hit_count', 'weight' ] });

The following parameters are set in the object after a successful
results save:

 search_id
 num_records

Returns: the ID of the search just saved.

B<retrieve( $search_id, \%params )>

Retrieve previously saved search results using the parameter
'search_id' which should be set on initialization or before this
method is run.

Parameters:

=over 4

=item *

B<min>: Where we should start grabbing the results. Generally used if
you are using a paged results scheme, (page 1 is 1 - 25, page 2 26 -
50, etc.). (Can be set at object creation.)

=item *

B<max>: Where should we stop grabbing the results. See B<min>. (Can be
set at object creation.)

=back

Returns:

=over 4

=item *

B<In list context>: an array with the first element an arrayref of the
results (or IDs of the results), the second element an arrayref of the
classes used in the results, the third element being the total number
of items saved. (The total number of items can be helpful when
creating pagecounts.)

=item *

B<In scalar context>: an arrayref of the results.

=back

Note: The interface for this method may change, and we might split
apart the different return results into two methods (particularly
whether classes are involved).

Also sets the object parameters:

'num_records' - total number of results in the original search

'date' - date the search was run

'num_extra' - number of 'extra' records saved

'extra_name' (\@) - list of fields matching extra values saved

B<retrieve_iterator( $search_id, \%params )>

Retrieves an iterator to walk the results. You can use min/max to
pre-separate or you can simply grab all the results and screen them
out yourself.

Parameters: same as C<retrieve()>

B<get_metadata( $search_id )>

Fetch metadata only about a search. Returns a hashref with the
following keys:

=over 4

=item *

B<time> - results storage time in epoch seconds

=item *

B<date> - results storage time in human-readable format

=item *

B<num_records> - number of records stored

=item *

B<filename> - name of file (only the filename)

=item *

B<directory> - 

=back

B<find_total_page_count( $records_per_page, [ $num_records ] )>

If called as an object then use 'num_records' property of object. If
'num_records' is not in the object, or if you call this as a class
method, then we use the second parameter for the total number of
records.

Returns: Number of pages required to display C<$num_records> at
C<$records_per_page>.

Example:

 my $page_count = $class->find_total_page_count( 289, 25 );
 # $page_count = 11
 
 my $page_count = $class->find_total_page_count( 289, 75 );
 # $page_count = 4

B<find_page_boundaries( $page_number, $records_per_page )>

Returns: An array with the floor and ceiling values to display the
given page with $records_per_page on the page.

Example:

 my ( $min, $max ) = $class->find_page_boundaries( 3, 75 );
 # $min is 226, $max is 300

 my ( $min, $max ) = $class->find_page_boundaries( 12, 25 );
 # min is 301, $max is 325

=head1 INTERNAL METHODS

B<_build_results_filename()>

B<generate_search_id()>

B<_lock_results()>

B<_unlock_results()>

B<_clear_results()>

B<_retrieve_raw_results()>

=head1 DATA FORMAT

Here is an example of a saved resultset. This one happens to be
generated by the L<OpenInteract2::FullText|OpenInteract2::FullText>
module.

 Thu Jul 12 17:19:05 2001-->3-->-->1-->fulltext_score
 -->3d5676e0af1f1cc6b539fb08a5ee67b7-->2
 -->c3d72c3c568d99a796b23e8efc75c00f-->1
 -->8f10f3a91c3f10c876805ab1d76e1b94-->1

Here are all the pieces:

B<First>, the separator is C<--E<gt>>. This is configurable in this
module.

B<Second>, the first line has:

=over 4

=item *

C<Thu Jul 12 17:19:05 2001>

The date the search was originally run.

=item *

C<3>

The number of items in the entire search resultset.

=item *

C<> (empty)

If it were filled it would be either a classname (e.g.,
'MySite::User') or the keyword 'MIXED' which tells this class that the
results are of multiple classes.

=item *

C<1>

The number of 'extra' fields.

=item *

C<fulltext_score>

The name of the first 'extra' field. If there wore than one extra
field they would be separated with commas.

=back

B<Third>, the second and remaining line have three pieces:

=over 4

=item *

C<> (empty)

The class name for this result. Since these IDs are not from a class,
there is no class name.

C<3d5676e0af1f1cc6b539fb08a5ee67b7>

The main value returned, also the ID of the object returned that, when
matched with the class name (first item) would be able to define an
object to be fetched.

C<2>

The first 'extra' value. Successive 'extra' values are separated by
'--E<gt>' like the other fields.

=back

=head1 BUGS

None known, although the API may change in the near future.

=head1 TO DO

B<Review API>

The API is currently unstable but should solidify quickly as we get
more use out of this module.

 - Keep 'mixed' stuff in there, or maybe always treat the resultset as
 potentially heterogeneous objects?

 - Test with saving different types of non-object data as well as
 objects and see if the usage holds up (including with the
 ResultsIterator).

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
