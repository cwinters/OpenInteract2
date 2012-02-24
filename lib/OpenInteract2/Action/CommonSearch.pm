package OpenInteract2::Action::CommonSearch;

# $Id: CommonSearch.pm,v 1.24 2005/03/18 04:09:49 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::Common );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::ResultsManage;
use SPOPS::Iterator::WrapList;

$OpenInteract2::Action::CommonSearch::VERSION   = sprintf("%d.%02d", q$Revision: 1.24 $ =~ /(\d+)\.(\d+)/);

my ( $log );

########################################
# SEARCH FORM

sub search_form {
    my ( $self ) = @_;
    $self->param( c_task => 'search_form' );
    $self->_search_form_init_param;
    my %tmpl_params = ();
    $self->_search_form_customize( \%tmpl_params );
    my $search_template = $self->param( 'c_search_form_template' );
    return $self->generate_content(
                    \%tmpl_params, { name => $search_template } );
}

sub _search_form_init_param {
    my ( $self ) = @_;
    unless ( $self->param( 'c_search_form_template' ) ) {
        $self->add_error_key( 'action.error.no_template', 'c_search_form_template' );
        die $self->execute({ task => 'common_error' }), "\n";
    }
    return undef;
}


########################################
# SEARCH

sub search {
    my ( $self ) = @_;
    $self->param( c_task => 'search' );
    $self->_search_init_param;
    $log ||= get_logger( LOG_ACTION );

    my %tmpl_params = ();

    my $is_paged = $self->param( 'c_search_results_paged' );
    if ( $is_paged eq 'yes' ) {
        %tmpl_params = $self->_search_retrieve_paged_results;
    }

    # If we're not using paged results, then just run the normal
    # search and get back an iterator, but run through it once so we
    # can count up the results

    else {
        $log->is_debug &&
            $log->debug( "Search results not paged, using basic iterator" );
        my $iter = eval {
            $self->_search_build_and_run();
        };
        $self->_search_catch_errors( "$@" );
        my $items = $iter->get_all();
        $log->is_debug &&
            $log->debug( scalar( @{ $items } ), " objects in iterator, ",
                         "recreating iterator" );
        $tmpl_params{iterator} = SPOPS::Iterator::WrapList->new({
            object_list => $items
        });
        $tmpl_params{total_hits}  = scalar @{ $items };
        $tmpl_params{page_num}    = 1;
        $tmpl_params{total_pages} = 1;
    }

    $tmpl_params{search_criteria} = $self->param( 'c_search_criteria' );
    my $results_template = $self->param( 'c_search_results_template' );
    $self->_search_customize( \%tmpl_params );
    return $self->generate_content(
                    \%tmpl_params, { name => $results_template } );
}

sub _search_retrieve_paged_results {
    my ( $self ) = @_;
    $log->is_debug && $log->debug( "Search results will be paged" );
    my %display = ();

    my $req = CTX->request;
    my $search_id = $req->param( 'search_id' );
    my $results = OpenInteract2::ResultsManage->new();

    # If the search has been run before, just set the ID

    if ( $search_id ) {
        $log->is_debug &&
            $log->debug( "Retrieving search for ID '$search_id'" );
        $results->{search_id} = $search_id;
    }

    # Otherwise, run the search and get an iterator back, then pass
    # the iterator to ResultsManage so we can reuse the results

    else {
        $log->is_debug &&
            $log->debug( "Running search for the first time" );
        my $iterator = eval {
            $self->_search_build_and_run();
        };
        $self->_search_catch_errors( "$@" );
        $results->save( $iterator );
        $log->is_debug &&
            $log->debug( "Got search ID from stored results '$results->{search_id}'" );
    }

    if ( $results->{search_id} ) {
        my $this_page  = $req->param( 'page_num' ) || 1;
        my $hits_per_page = $self->param( 'c_search_results_page_size' );
        my ( $min, $max ) =
                $results->find_page_boundaries( $this_page, $hits_per_page );
        $display{iterator}    = $results->retrieve({
                                     min         => $min,
                                     max         => $max,
                                     return_type => 'iterator' });
        $display{page_num}    = $this_page;
        $display{total_pages} = $results->find_total_page_count( $hits_per_page );
        $display{total_hits}  = $results->{num_records};
        $display{search_id}   = $results->{search_id};
        $log->is_debug && $log->debug( "Search info: [min: $min] [max: $max] ",
                                       "[records: $results->{num_records}]" );
    }
    else {
        $log->warn( "No search ID from results, creating empty iterator" );
        $display{iterator} = SPOPS::Iterator->from_list( [] );
    }
    return %display;
}


my %DEFAULTS = (
   c_search_results_paged         => 'yes',
   c_search_results_page_size     => 50,
   c_search_results_cap           => 0,
   c_search_table_links           => {},
   c_search_fail_task             => 'search_form',
   c_search_results_cap_fail_task => 'search_form',
);

sub _search_init_param {
    my ( $self ) = @_;
    $self->_common_set_defaults( \%DEFAULTS );

    my $has_error =
        $self->_common_check_template_specified( 'c_search_results_template' );
    $has_error += $self->_common_check_object_class;

    my $table_links = $self->param( 'c_search_table_links' );
    if ( ref $table_links eq 'HASH' ) {
        while ( my ( $table, $id_link ) = each %{ $table_links } ) {
            if ( ref $id_link ne 'ARRAY' ) {
                my $msg = join( '', "Misconfigured search: there should ",
                                "be multiple entries in the ",
                                "'c_search_table_links' section for table ",
                                "[$table] under action [", $self->name, "]" );
                $self->param_add( error_msg => $msg );
                $has_error++;
            }
            else {
                my $num_id_links = scalar @{ $id_link };

                # NOTE: There's nothing except simplicity stopping us
                # from making this arbitrarily complex (6, 8, ...)

                unless ( $num_id_links == 2 || $num_id_links == 4 ) {
                    $self->add_error_key( 'action.error.search_table_links',
                                          $table, $self->name );
                    $has_error++;
                }
            }
        }
    }
    if ( $has_error ) {
        die $self->execute({ task => 'common_error' }), "\n";
    }

    # Now we're dealing with valid data...

    my @all_fields = (
        $self->param( 'c_search_fields_like' ),
        $self->param( 'c_search_fields_exact' ),
        $self->param( 'c_search_fields_left_exact' ),
        $self->param( 'c_search_fields_right_exact' )
    );
    $self->param( c_search_fields => \@all_fields );
    return undef;
}

sub _search_catch_errors {
    my ( $self, $caught ) = @_;
    return unless ( $caught );
    my ( $msg, $task );
    if ( $caught =~ /^CAP: (.*)$/ ) {
        $msg = $self->_msg( 'action.error.search_too_many_results', $1 );
        $task = $self->param( 'c_search_results_cap_fail_task' );
    }
    else {
        $msg = $caught;
        $task = $self->param( 'c_search_fail_task' );
    }
    $self->add_error( $msg );
    die $self->execute({ task => $task }), "\n";
}

# Build the search and run it, returning an iterator

sub _search_build_and_run {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    $self->_search_build_criteria;
    $self->_search_build_where_clause;

    my $object_class = $self->param( 'c_object_class' );

    # TODO: This is kind of (!!!) yucky -- run the same search twice?

    my @tables = $self->param( 'c_search_query_tables' );
    my $where  = join( ' AND ', $self->param( 'c_search_query_where' ) );
    my @values = $self->param( 'c_search_query_values' );
    if ( my $num_limit_results = $self->param( 'c_search_results_cap' ) ) {
        my $row = eval {
            $object_class->db_select({
                select => [ 'count(*)' ],
                from   => \@tables,
                where  => $where,
                value  => \@values,
                return => 'single' })
        };
        if ( $row->[0] > $num_limit_results ) {
            oi_error "CAP: $row->[0] > $num_limit_results";
        }
    }

    $self->_search_calculate_limit;
    my $limit = $self->param( 'c_search_query_limit' );
    my $order = $self->param( 'c_search_results_order' );
    my $additional_params = $self->_search_additional_params || {};
    my $iter = eval {
        $object_class->fetch_iterator({
            from  => \@tables,
            where => $where,
            value => \@values,
            limit => $limit,
            order => $order,
            %{ $additional_params } })
    };
    if ( $@ ) {
        $log->warn( "Search failed: $@" );
        oi_error $@;
    }
    $log->is_info &&
        $log->info( "Got iterator from '$object_class' ok" );
    return $iter;
}


# Grab the specified fields and values out of the form
# submitted. Fields with multiple values are saved as arrayrefs.

sub _search_build_criteria {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    my $object_class = $self->param( 'c_object_class' );
    my $object_table = $object_class->base_table;
    my ( %search );

    # Go through each search field and assign a value. If the search
    # field is a simple one (no table.field), then prepend the object
    # table to the fieldname

    my $req = CTX->request;
    my @search_fields = $self->param( 'c_search_fields' );
    foreach my $field ( @search_fields ) {
        next unless ( $field );
        my @value = $req->param( $field );
        next unless ( defined $value[0] and $value[0] ne '' );
        my $full_field = _fq( $object_table, $field );
        $log->is_debug &&
            $log->debug( "Adding search criteria [$field] [@value]" );
        $search{ $full_field } = ( scalar @value > 1 ) ? \@value : $value[0];
    }
    $self->param( c_search_criteria => \%search );
    $self->_search_criteria_customize;
    return $self;
}


# Build a WHERE clause -- parameters with multiple values are 'OR',
# everything else is 'AND'. Example:
#
#  ( table.last_name LIKE '%win%' OR table.last_name LIKE '%smi%' )
#  AND ( table.first_name LIKE '%john%' )

sub _search_build_where_clause {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    my $criteria = $self->param( 'c_search_criteria' );

    # Find all our configured information

    my $object_class = $self->param( 'c_object_class' );
    my $object_table = $object_class->base_table;
    my %from_tables  = ( $object_table => 1 );
    my %exact_match        = map { _fq( $object_table, $_ ) => 1 }
                                 $self->param( 'c_search_fields_exact' );
    my %left_exact_match   = map { _fq( $object_table, $_ ) => 1 }
                                 $self->param( 'c_search_fields_left_exact' );
    my %right_exact_match  = map { _fq( $object_table, $_ ) => 1 }
                                 $self->param( 'c_search_fields_right_exact' );

    # Go through each of the criteria set -- note that each one must
    # be a fully-qualified (table.field) fieldname or it is discarded.

    my ( @where, @value ) = ();
    while ( my ( $field_name, $field_value ) = each %{ $criteria } ) {
        $log->is_debug &&
            $log->debug( "Adding criteria [$field_name: $field_value]" );
        next unless ( defined $field_value );

        # Discard unqualified fieldnames. Note that this regex will
        # greedily swallow everything to the last '.' to accommodate
        # systems that use a 'db.table' syntax to refer to a table.

        my ( $this_table ) = $field_name =~ /^([\w\.]*)\./;
        next unless ( $this_table );

        # Track the table used

        $from_tables{ $this_table }++;

        # Normalize into an arrayref

        my $value_list = ( ref $field_value )
                           ? $field_value : [ $field_value ];

        # Hold the items for this particular criterion, which will be
        # joined with an 'OR'

        my @where_param = ();
        foreach my $value ( @{ $value_list } ) {

            # Value must be defined and non-empty to be set

            next unless ( defined $value and $value ne '' );

            # Default is a LIKE match (see POD)

            my $oper = ( $exact_match{ $field_name } ) ? '=' : 'LIKE';
            push @where_param, " $field_name $oper ? ";
            my ( $search_value );
            if ( $exact_match{ $field_name } ) {
                $search_value = $value;
            }
            elsif ( $left_exact_match{ $field_name } ) {
                $search_value = "$value%";
            }
            elsif ( $right_exact_match{ $field_name } ) {
                $search_value = "%$value";
            }
            else {
                $search_value = "%$value%";
            }
            push @value, $search_value;
            $log->is_debug &&
                $log->debug( "Clause [$field_name $oper $search_value]" );
        }
        push @where, '( ' . join( ' OR ', @where_param ) . ' )';
    }

    # Generate any statements needed to link tables for searching.

    # DO NOT replace '@tables_used' in the foreach with 'keys
    # %from_tables' since we may add items to %from_tables during the
    # loop. Also don't do an 'each %table_links' and then check to see
    # if the table is in %from_tables for the same reason.

    my $table_links = $self->param( 'c_search_table_links' );
    my @tables_used = keys %from_tables;

TABLE:
    foreach my $link_table ( @tables_used ) {
        next if ( $link_table eq $object_table );
        my $id_link = $table_links->{ $link_table };
        unless ( ref $id_link eq 'ARRAY' ) {
            $log->warn( "No links for non-object table used [$link_table]; ",
                        "this is likely a bad thing..." );
            next TABLE;
        }

        # See POD for what the values in 'c_search_table_links' mean;
        # there should be either two or four

        my $num_linking_fields = scalar @{ $id_link };
        if ( $num_linking_fields == 2 ) {
            my ( $object_field, $link_field ) = @{ $id_link };
            $log->is_debug &&
                $log->debug( "Linking [$link_table] with ",
                             "[$object_field = $link_field]" );
            push @where, "$object_field = $link_field";
        }

        # Remember to add the linking table to our FROM list!

        elsif ( $num_linking_fields == 4 ) {
            my ( $from, $middle_from, $middle_to, $to ) = @{ $id_link };
            $log->is_debug &&
                $log->debug( "Linking [$from = $middle_from > ",
                             "$middle_to = $to]" );
                push @where, "$from = $middle_from ",
                             "$middle_to = $to";
            my ( $middle_table ) = $middle_from =~ /^([\w\.]*)\./; # greedy on purpose
            $from_tables{ $middle_table }++;
        }
    }

    $self->param( c_search_query_tables => [ keys %from_tables ] );
    $self->param( c_search_query_where  => \@where );
    $self->param( c_search_query_values => \@value );
    $self->_search_query_customize;

    $log->is_debug &&
        $log->debug( join( "\n",
                           "Built SQL chunks: ",
                           "   FROM: " .
                           join( ', ', $self->param( 'c_search_query_tables' ) ),
                           "  WHERE: " . join( ' AND ', $self->param( 'c_search_query_where' ) ),
                           " VALUES: " . join( ', ', $self->param( 'c_search_query_values' ) ),
                         ) );
    return $self;
}


# TODO: Where do min and max get set...?

sub _search_calculate_limit {
    my ( $self ) = @_;
    my ( $limit );
    my ( $min, $max ) = ( $self->param( 'min' ), $self->param( 'max' ) );
    if ( $min or $max ) {
        if ( $min and $max ) { $limit = "$min,$max" }
        elsif ( $max )       { $limit = $max }
    }
    $self->param( c_search_query_limit => $limit );
}

sub _fq {
    my ( $table, $field ) = @_;
    return ( $field =~ /\./ ) ? $field : "$table.$field";
}

# Take a list of fields and ensure that each one is fully-qualified

sub _fq_fields {
    my ( $self, $table, @fields ) = @_;
    return map { _fq( $table, $_ ) } @fields;
}

########################################
# OVERRIDABLE

sub _search_form_customize        { return undef }
sub _search_additional_params     { return undef }
sub _search_criteria_customize    { return undef }
sub _search_query_customize       { return undef }
sub _search_customize             { return undef }

1;

__END__

=head1 NAME

OpenInteract2::Action::CommonSearch - Implement searching functionality for SPOPS::DBI-based objects

=head1 SYNOPSIS

 # Just subclass and the tasks 'search_form' and 'search' are
 # implemented
 
 package OpenInteract2::Action::MyAction;
 
 use strict;
 use base qw( OpenInteract2::Action::CommonSearch );
 
 # Relevant configuration entries in your action.ini
 
 [myaction]
 ...
 c_object_type                  = book
 c_search_form_template         = mypkg::search_form
 c_search_results_template      = mypkg::search_results
 c_search_fields_like           = author
 c_search_fields_exact          = publisher
 c_search_fields_left_exact     = title
 c_search_fields_right_exact    = who_knows
 c_search_fields_exact          = co_author.name
 c_search_results_order         = title
 c_search_results_paged         = yes
 c_search_results_page_size     = 50
 c_search_results_cap           = 500
 c_search_fail_task             = search_form
 c_search_results_cap_fail_task = search_form
 
 [myaction c_search_table_links]
 co_author = book.book_id
 co_author = co_author.book_id

=head1 SUPPORTED TASKS

This common action supports two tasks, explained in detail below:

B<search_form>

Display a form for searching an object.

B<search>

Collect search criteria from the user, build a query against an object
and return results

=head1 DESCRIPTION FOR 'search_form'

This is a very simple action -- all we really do is get the specified
template and display it.

=head1 TEMPLATES USED FOR 'search_form'

B<c_search_form_template>

Fully qualified template name for your search form. If undefined
you will get the standard error page.

=head1 METHODS FOR 'search_form'

_search_form_customize( \%template_params )

Add any necessary parameters to C<\%template_params> before the
content generation step where they get passed to the template
specified in C<c_search_form_template>.

=head1 CONFIGURATION FOR 'search_form'

None. All you need to do is specify the template name as mentioned
above.

=head2 System-created parameters

These are created by the task and available in any callbacks or from
the view.

B<c_task>

Name of the task originally invoked: 'search_form'.

=head1 DESCRIPTION FOR 'search'

This task builds a SQL query from the given search criteria and
returns the results as an iterator, just in case you accidentally
selected 1000 records.

It also supports stepping through the search results a page at a time
-- just set the C<c_search_results_paged> parameter to 'yes'. When
you are generating URLs to page through searches, you should only need
to pass the following parameters after the first search:

=over 4

=item *

B<search_id>: ID of the search you're requesting.

=item *

B<page_num>: Page of the result set you'd like to view.

=back

=head1 TEMPLATES USED FOR 'search'

B<c_search_results_template>

Fully qualified template name for your search results. If undefined
you will get the standard error page.

These paramters are available to your template:

=over 4

=item *

B<iterator>: An L<SPOPS::Iterator|SPOPS::Iterator> (or one of its
subclasses) with your search results.

=item *

B<search_criteria>: A hashref of the criteria we used to run the
search. Note that the search strings does not contain any wildcards
(e.g., '%') and that the keys are fully-qualified fieldnames (e.g.,
'book.title'). If you plan to display the results you may want to
modify the fieldnames in C<_search_customize()>.

=item *

B<page_num>: Page of the results we are currently on. (If results not
paged, always '1'.)

=item *

B<total_pages>: The total number of pages in the result set. (If
results not paged, always '1'.)

=item *

B<total_hits>: The total number of hits in the result set.

=item *

B<search_id>: The ID of this search. (Not set if results not paged.)

=back

=head1 METHODS FOR 'search'

B<_search_additional_params()> (\%)

If you want to pass additional parameters directly to the
L<SPOPS::DBI|SPOPS::DBI> C<fetch_iterator()> call, return them
here. For instance, if you want to skip security for a particular
search you would create:

 sub _search_additional_params {
     return { skip_security => 1 };
 }

Default: undef (no parameters)

B<_search_criteria_customize()>

If you wouldd like to modify the search criteria after it has been
read in from the user but before it hass been translated to SQL and
executed, override this method. You have access to the parameter
'c_search_critieria', a hashref of fields to values searched for. The
value can be a scalar or an arrayref, depending on how many values the
user submitted.

For instance, you can play nasty with your users and ensure that when
a certain search term is entered they get something entirely
different:

 sub _search_criteria_customize {
     my ( $self ) = @_;
     my $criteria = $self->param( 'c_search_criteria' );
     if ( $critieria->{full_name} eq 'Bill Gates' ) {
         $criteria->{full_name} = 'Larry Wall';
     }
 }

B<_search_query_customize()>

This is called after the pieces for the query have been built but not
yet put together to create the query. You have the opportunity to
modify the parameters:

=over 4

=item *

C<c_search_query_tables> - an arrayref of the tables used

=item *

C<c_search_query_where> - an arrayref of the sections to be used in
the C<WHERE> clause that will eventually be joined by 'AND' later in
the process.

=item *

C<c_search_query_values> - an arrayref of the values to be plugged
into placeholders from C<c_search_query_where>.

=back

So if you wanted to set a value depending on multiple values you might
do something like this:

 sub _search_query_customize {
     my ( $self ) = @_;
 
     # Our query operator depends on $date_type...
 
     my $request = CTX->request;
     my $date_type = $request->param( 'date_order' );
     my $date_search = $request->param_date( 'filter_date' );
 
     # Do not do anything unless both are defined
 
     return unless ( $date_type and $date_search );
     my $where = $self->param( 'c_search_query_where' )  || [];
     my $value = $self->param( 'c_search_query_values' ) || [];
 
     # ...now define the different operators
 
     if ( $date_type eq 'after' ) {
         push @{ $where }, 'object_time >= ?';
     }
     elsif ( $date_type eq 'before' ) {
         push @{ $where }, 'object_time <= ?';
     }
 
     # ... but the value is the same
 
     push @{ $value }, $date_search;
 
     # Now reset the parameters to the new values, just in case they
     # were previously undefined
 
     $self->param( c_search_query_where  => $where );
     $self->param( c_search_query_values => $value );
 }

B<_search_customize( \%template_params )>

This is called just before we generate the content. You are passed a
hashref of the parameters that will be passed to the template, and you
can modify them as needed. Typically you will use this to pass
additional parameters to the template.

=head1 CONFIGURATION FOR 'search'

These are in addition to the template parameters defined above.

=head2 Basic

B<c_object_type> ($) (REQUIRED)

SPOPS key for object you will be searching. You can build a search
that spans tables from other objects, but you still have to return a
single type of object. (See
L<OpenInteract2::Common|OpenInteract2::Common>.)

=head2 Specifying search fields

In these configuration entries you are presenting a list of fields
used to build a search. This can include fields from other
tables. Fields from other tables must be fully-qualified with the
table name.

For instance, for a list of fields used to find users, I might list:

 c_search_fields_like = login_name
 c_search_fields_like = last_name
 c_search_fields_like = group.name

Where 'group.name' is a field from another table. I would then have to
configure C<c_search_table_links> (below) to tell the query builder
how to link my object with that table.

These are the actual parameters from the form used for searching. If
the names do not match up, such as if you fully-qualify your names in
the configuration but not the search form, then you will not get the
criteria you think you will. An obvious symptom of this is running a
search and getting many more records than you expected, maybe even all
of them.

To be explicit -- in the HTML page corresponding to the above example
you should have something like:

 Group Name: <input type="text" name="group.name">

B<c_search_fields_like> ($ or @)

Zero or more fields to search using 'LIKE' and a wildcard '%' on both
sides of the search value.

Example:

 login name LIKE '%foo%'

B<c_search_fields_exact> ($ or @)

Zero or more fields to search using '=', no wildcards.

Example:

 login name = 'foo'

B<c_search_fields_left_exact>

Zero or more fields to search using 'LIKE' and a wildcard '%' on the
right-hand side of the search value, thus finding all objects where
the given value matches the beginning of the object field.

Example:

 login name = 'foo%'

B<c_search_fields_right_exact>

Zero or more fields to search using 'LIKE' and a wildcard '%' on the
left-hand side of the search value, thus finding all objects where the
given value matches the end of the object field. (This is not used
very often.)

Example:

 login name = '%foo'

=head2 Linking tables for searches

B<c_search_table_links> (\%)

Maps zero or more table names to the necessary information to build a
WHERE clause that joins the relevant tables together on the proper
fields.

 NOTE: This discussion may seem confusing but it can be extremely
 useful: for instance, if you want to search by a city but the address
 information is in a separate table from the 'person' objects. If we
 stuck to the one-object/one-table mentality then you would have to
 break normalization or some other hack.

The values assigned to each table name enable us to build a join
clause to link our table (the one with the object being searched) to
the table in the key. So we have two pieces to the puzzle: the 'FROM'
(our object) and the 'TO' (the related object).

There are two possibilities for the configuration:

B<Configuration 1: Objects matched by fields>

Example: Assume we have a 'person' table (holding our searchable
object) and an 'address' table. We want to find all people by the
'address.city' field.

 [person c_search_table_links]
 address = person.person_id
 address = address.person_id

So we are saying that to link our object ('person') to another object
('address'), we just find all the 'address' objects where the
'person_id' field is a particular value. This is the classic
one-to-many relational mapping.

Here is what the statement might look like:

 SELECT (person fields)
   FROM person, address
  WHERE address.city = 'foo'
        AND person.person_id = address.person_id

Another example: Assume we have a 'phone_log' table (holding our
searchable object) and a 'person' table. We want to find all phone log
records for people by last name.

 [phone_log c_search_table_links]
 person = phone_log.person_id
 person = person.person_id

This is the same as the first example but demonstrates that you can
use non-key fields as well as key fields to specify a relationship.

Here is what the statement might look like:

 SELECT (phone_log fields)
   FROM phone_log, person
  WHERE person.last_name = 'foo'
        AND phone_log.person_id = person.person_id

B<Configuration 2: Objects linked by a third table>

Example: Assume we have a 'user' table (holding our searchable
object), a 'group' table and a 'group_user' table holding the
many-to-many relationships between the objects. We want to find all
users in a particular group.

 [user search_table_links]
 group = user.user_id
 group = group_user.user_id
 group = group_user.group_id
 group = group.group_id

This is fundamentally the same as the other two examples except we
have chained two relationships together:

    FROM                 TO
 1. user.user_id         group_user.user_id
 2. group_user.group_id  group.group_id

So searching for a user by a group name with 'admin' would give:

 SELECT (user fields)
   FROM user, group, group_user
  WHERE group.name = 'admin'
    AND group.group_id = group_user.group_id
    AND group_user.user_id = user.user_id

Default: empty hashref

=head2 Other query modifications

B<c_search_results_order> ($)

An 'ORDER BY' clause (without the 'ORDER BY') used to order your
results. The query builder makes sure to include the fields used to
order the results in the SELECT statement, since many databases will
complain about their absence.

Note that in addition to declaring this statically you can dynamically
add this in C<_search_query_customize()>.

Default: none

=head2 Paging/capping results

B<c_search_results_paged> (boolean)

Do you want your search results to be paged ('yes') or do you want
them returned all at once ('no')?

Default: 'yes'

B<c_search_results_page_size> ($)

If B<c_search_results_paged> is set to 'yes' we output pages of this
size.

Default: 50

B<c_search_results_cap> ($)

Constrains the max number of records returned. If this is set we run a
'count(*)' query using the search criteria before running the
search. If the result is greater than the number set here, we call the
task specified in B<c_search_results_cap_fail_task> with an error
message set in the normal manner about the number of records that
would have been returned.

Note that this is a somewhat crude measure of the records returned
because it does not take into account security checks. That is, a
search that returns 500 records from the database could conceivably
return only 100 records after security checks. Keep this in mind when
setting the value.

Default: 0 (no cap)

=head2 Tasks to execute on failure

B<c_search_fail_task> ($)

Task to run if your search fails. The action parameter 'error_msg'
will be set to an appropriate message which you can display.

Default: 'search_form'

B<c_search_results_cap_fail_task> ($)

Task to run in this class when a search exceeds the figure set in
B<c_search_results_cap>. The task is run with a relevant message in
the 'error_msg' action parameter.

Default: 'search_form'

=head2 System-created parameters

These are created by the action when it is first initialized and
during the search task.

B<c_task>

Name of the task originally invoked: 'search'.

B<c_object_class> ($)

Set to the class corresponding to C<c_object_type>. This has already
been validated.

B<c_search_fields> ($ or @)

Zero or more fields that users can search by. This includes all fields
from C<c_search_fields_like>, C<c_search_fields_exact>,
C<c_search_fields_left_exact>, C<c_search_fields_right_exact>.

B<c_search_criteria> (\%)

These are the criteria built-up during the search process. You can
change them by overriding C<_search_criteria_customize()> and
modifying the parameter.

B<c_search_query_tables> (\@)

List of the tables used in a search.

B<c_search_query_where> (\@)

List of the clauses to be used in a WHERE clause of a search. Will be
joined together with 'AND' on submitting to the engine.

B<c_search_query_values> (\@)

Values to be plugged into the placeholders specified in
C<c_search_query_where>.

B<c_search_query_limit> ($)

The limit clause -- either a single number, which indicates the number
of items to get from the beginning, or two numbers separated by a
comma, which indicates the range of items to get.

=head1 TO DO

B<Modify page size on the fly>

Allow the incoming URL to define page size as well as the page number.
(Default page size still set in the action.) If a user sets this it
should be saved in her session (or a cookie?) so it is sticky.

=head1 COPYRIGHT

Copyright (c) 2003-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
