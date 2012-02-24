package OpenInteract2::Action::News;

# $Id: News.pm,v 1.14 2005/09/25 15:19:24 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::CommonSearch
             OpenInteract2::Action::CommonDisplay
             OpenInteract2::Action::CommonUpdate
             OpenInteract2::Action::CommonAdd
             OpenInteract2::Action::CommonRemove );
use DateTime;
use DateTime::Format::Strptime qw( strptime );
use Log::Log4perl              qw( get_logger );
use OpenInteract2::Constants   qw( :log );
use OpenInteract2::Context     qw( CTX );
use OpenInteract2::Util;
use SPOPS::Secure              qw( SEC_LEVEL_WRITE );

$OpenInteract2::Action::News::VERSION = sprintf("%d.%02d", q$Revision: 1.14 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub home {
    my ( $self ) = @_;
    return $self->generate_content();
}

# only by date, but makes for nice URLs...

sub archive {
    my ( $self ) = @_;
    my $year  = $self->param( 'search_year' );
    my $month = $self->param( 'search_month' );
    $log ||= get_logger( LOG_APP );
    $log->info( "Got archive date [Year: $year] and [Month: $month]" );
    unless ( $year and $month ) {
        $self->add_error_key( 'news.error.archive_date' );
        return $self->execute({ task => 'home' });
    }
    return $self->search();
}

sub latest {
    my ( $self ) = @_;
    my $request = CTX->request;
    my $num_items = $self->param( 'num_items' )
                    || $request->param( 'num_items' )
                    || $self->param( 'default_list_size' );

    # For cache...
    $self->param( num_items => $num_items );

    my %params = ( show_box  => $self->param( 'show_box' ),
                   num_items => $num_items );
    my $where = "active_on <= ? AND active = ? ";
    my @values = ( OpenInteract2::Util->now, 'yes' );
    my $items = eval {
        OpenInteract2::News->fetch_group({
            where => $where,
            value => \@values,
            order => 'posted_on DESC',
            limit => $num_items,
        })
    };
    if ( $@ ) {
        $self->add_error_key( 'news.error.fetch_multiple', $@ );
    }
    else {
        $params{news_list} = $self->_massage_news_list( $items );
    }
    return $self->generate_content( \%params );
}


# This overrides OI2::Action::CommonSearch...

sub search {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;

    $self->param_from_request( qw( num_items option section ) );

    # NOTE: We can't use $request->param_date( 'news' ) here because
    # we allow the day to be blank

    unless ( $self->param( 'date' ) ) {
        my $p_day   = $self->param( 'search_day' ) ||
                      $request->param( 'news_day' );
        my $p_month = $self->param( 'search_month' ) ||
                      $request->param( 'news_month' );
        my $p_year  = $self->param( 'search_year' ) ||
                      $request->param( 'news_year' );
        if ( $p_month and $p_year ) {
            $self->param( date => join( '-', $p_day, $p_month, $p_year ) );
        }
    }

    my $now_string = OpenInteract2::Util->now;
    my %params = ();
    my $where = " active_on <= ? AND active = ? ";
    my @values = ( $now_string, 'yes' );

    $where .= ( $self->param( 'option' ) eq 'older' )
                ? ' AND ( expires_on < ? ) '
                : ' AND ( expires_on IS NULL OR expires_on > ? ) ';
    push @values, $now_string;
    if ( my $section = $self->param( 'section' ) ) {
        $where .= ' AND ( section = ? )';
        push @values, $section;
        $params{section} = $section;
        $log->is_info &&
            $log->info( "Given search section of '$section'" );
    }

    if ( my $date_spec = $self->param( 'date' ) ) {
        my ( $dy, $mo, $yr ) = split /\-/, $date_spec;
        $log->is_debug &&
            $log->debug( "Searching for date with [d: $dy] [m: $mo] ",
                         "[y: $yr]" );
        my ( $begin_date, $end_date );

        # If day is specified we find everything on that day...

        if ( $dy > 0 ) {
            my $search_date = strptime( '%d-%m-%Y', $date_spec );
            $begin_date = $search_date->clone
                                      ->subtract( days => 1 );
            $end_date   = $search_date->add( days => 1 );
            $params{date} = $end_date->strftime( '%Y-%m-%d' );
        }

        # ...otherwise we find everything in that month

        else {
            my $begin_date_spec = join( '-', $yr, $mo, 1 );
            $begin_date = strptime( '%Y-%m-%d', $begin_date_spec );
            $end_date   = $begin_date->clone->add( months => 1 );
            $params{date} = join( ' to ', $begin_date->strftime( '%Y-%m-%d' ),
                                          $end_date->strftime( '%Y-%m-%d' ) );
        }
        $log->is_info &&
            $log->info( "Given search begin/end dates of ",
                        "'", $begin_date->strftime( '%Y-%m-%d' ), "' and ",
                        "'", $end_date->strftime( '%Y-%m-%d' ), "'" );
        $where .= ' AND ( posted_on >= ? AND posted_on <= ? ) ';
        push @values, $begin_date->strftime( '%Y-%m-%d' ),
                      $end_date->strftime( '%Y-%m-%d' );
    }

    $log->is_debug &&
        $log->debug( "Quering news objects with: $where\n",
                     "and values: ", join( ', ', @values ) );
    my $items = eval {
        OpenInteract2::News->fetch_group({
            where        => $where,
            value        => \@values,
            column_group => 'listing',
            order        => 'posted_on DESC',
        })
    };
    $params{news_list} = $self->_massage_news_list( $items );
    $params{section_list} = $self->_get_sections;
    return $self->generate_content( \%params );
}

sub _massage_news_list {
    my ( $self, $news_list ) = @_;
    $log ||= get_logger( LOG_APP );

    # Only grab the first 'chunk' of the news item, as split up by the
    # separator; also create information about the user who posted the
    # story

    my %posters = ();
    foreach my $news ( @{ $news_list } ) {
        if ( $news->{news_item} ) {
            ( $news->{tmp_content} ) = split '<!--BREAK-->', $news->{news_item};

            # If there is template content in the news item, process it

            if ( $news->{tmp_content} =~ m|\[\%| ) {
                $log->is_debug &&
                    $log->debug( "Processing template content ",
                                 "for news item [$news->{title}]" );
                $news->{tmp_content} =
                    $self->generate_content( {}, { text => $news->{tmp_content} } );
            }
        }

        # Now grab relevant user information, caching as we go (since
        # the same people tend to post news)

        unless ( $posters{ $news->{posted_by} } ) {
            my $user = eval { $news->posted_by_user() };
            my $poster_info = {};
            if ( $@ ) {
                $poster_info->{login_name} = 'admin';
                $poster_info->{user_id}    = undef;
            }
            else {
                $poster_info->{login_name} = $user->{login_name};
                $poster_info->{user_id}    = $user->id;
            }
            $posters{ $user->{user_id} } = $poster_info;
        }
        $news->{tmp_poster_info} = $posters{ $news->{posted_by} };
    }
    return $news_list;
}


sub _display_form_customize {
    my ( $self, $template_params ) = @_;
    $template_params->{section_list} = $self->_get_sections;
}

sub _display_add_customize {
    my ( $self, $template_params ) = @_;
    $template_params->{section_list} = $self->_get_sections;
}

sub _add_customize {
    my ( $self, $news, $save_options ) = @_;
    $self->_set_defaults( $news );
}

sub _update_customize {
    my ( $self, $news, $old_data, $save_options ) = @_;
    $self->_set_defaults( $news );
}

sub _ds { return ref( $_[0] ) ? $_[0]->strftime( '%Y-%m-%d %H:%M' ) : $_[0] }

sub _set_defaults {
    my ( $self, $news ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_info &&
        $log->info( "Before setting date defaults: ",
                    "[active_on: ", _ds( $news->{active_on} ), "] ",
                    "[posted_on: ", _ds( $news->{posted_on} ), "] ",
                    "[expires_on: ", _ds( $news->{expires_on} ), "] " );

    $news->{active_on} ||= CTX->create_date;
    $news->{posted_on} ||= CTX->create_date;
    unless ( $news->{expires_on} ) {
        my $expire_days = $self->param( 'default_expire' );
        $news->{expires_on} = CTX->create_date->add( days => $expire_days );
    }

    $log->is_info &&
        $log->info( "After setting date defaults: ",
                    "[active_on: ", _ds( $news->{active_on} ), "] ",
                    "[posted_on: ", _ds( $news->{posted_on} ), "] ",
                    "[expires_on: ", _ds( $news->{expires_on} ), "] " );

    # substitute <p> for hard returns where needed

    $news->{news_item} =~ s/(\r\n\r\n)(?!(<p|<pre|<blockquote))/$1<p>/g;

    # If the image URL wasn't set to something real, clear it

    if ( $news->{image_url} =~ m|^http://\s*$| ) {
        $news->{image_url} = undef ;
    }

    # Set other defaults

    $news->{posted_by}   ||= CTX->request->auth_user->id;
    $news->{image_align} ||= 'left';
}

# TODO: Move this to OI2::Action::Notifyable or something
sub notify {
    my ( $self ) = @_;
    my $request = CTX->request;
    my @news_id  = $request->param( 'news_id' );
    my $email    = $request->param( 'email' );
    if ( ! $email or ! scalar @news_id ) {
        return '<h2 align="center">Error</h2>' .
               '<p>Error: Cannot notify anyone about an object when no ' .
               'ID/email is given.</p>';
    }
    my @news_list = ();
    foreach my $nid ( @news_id ) {
        my $news = eval { OpenInteract2::News->fetch( $nid ) };
        push @news_list, $news   if ( $news );
    }
    my $rv = OpenInteract2::News->notify({
        email   => $email,
        subject => 'News notification',
        object  => \@news_list,
        type    => 'news',
    });
    if ( $rv ) {
        return '<h2 align="center">Success!</h2>' .
               '<p>Notification sent properly!</p>';
    }
    return '<h2 align="center">Error</h2>' .
           '<p>Error sending email. Please check error logs!</p>';
}


# Fetch all the news items for display
sub show_summary {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $sections = $self->_get_sections;
    my $news = eval {
        CTX->lookup_object( 'news' )
           ->fetch_group({ order => 'posted_on DESC' })
    };
    if ( $@ ) {
        $log->error( "Failed to get news objects: $@" );
        $self->add_error_key( 'news.error.fetch_multiple', $@ );
    }
    return $self->generate_content(
                    { section_list => $sections, news_list => $news } );
}


sub edit_summary {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my @do_edit = $request->param( 'do_edit' );
    my ( $success, $attempt );
NEWS:
    foreach my $news_id ( @do_edit ) {
        next unless ( $news_id );
        $attempt++;
        my $news = eval { OpenInteract2::News->fetch( $news_id ) };
        if ( $@ ) {
            $log->error( "Cannot fetch news '$news_id': $@" );
            $self->add_error_key( 'news.error.fetch', $news_id, $@ );
            next NEWS;
        }
        $news->{title} = $request->param( "title_$news_id" );
        $news->{section} = $request->param( "section_$news_id" );
        $news->{active}  = $request->param( "active_$news_id" );
        eval { $news->save };
        if ( $@ ) {
            $log->error( "Failed to save news object '$news_id': $@" );
            $self->add_error_key( 'news.error.save', $news_id, $@ );
        }
        else {
            $success++;
        }
    }
    $self->add_status_key( 'news.status.multi_updates', $attempt, $success );
    $self->clear_cache();
    return $self->execute({ task => 'home' });
}

# counts by month
sub archive_by_month {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $dbh = OpenInteract2::News->global_datasource_handle();
    my $driver = $dbh->{Driver}{Name};

    # selects: count, year, month
    my $sql = $self->_get_count_by_month_sql( $driver );
    unless ( $sql ) {
        $self->add_error_key( 'news.error.db_unsupported', $driver );
        return $self->execute({ task => 'home' });
    }
    my ( $sth );
    eval {
        $sth = $dbh->prepare( $sql );
        $sth->execute;
    };
    if ( $@ ) {
        $log->warn( "Error preparing/executing SQL for '$driver' DB: $@" );
        $self->add_error_key( 'news.error.fetch_multiple', "$@" );
        return undef;
    }
    my @counts = ();
    while ( my $row = $sth->fetchrow_arrayref ) {
        push @counts, {
            count => $row->[0],
            year  => $row->[1],
            month => $row->[2],
        };
    }
    return $self->generate_content({
        counts => \@counts,
    });
}

sub _get_count_by_month_sql {
    my ( $self, $driver ) = @_;
    $driver = lc $driver;
    my $table = OpenInteract2::News->table_name;
    my $trailing = "  FROM $table\n" .
                   " GROUP BY year, month\n" .
                   " ORDER BY year DESC, month DESC\n";
    if ( 'pg' eq $driver ) {
        return "SELECT count(*), date_part( 'year', posted_on ) as year, " .
               " date_part( 'month', posted_on ) as month\n" .
               $trailing;
    }
    elsif ( 'mysql' eq $driver ) {
        return "SELECT count(*), EXTRACT( YEAR FROM posted_on ) as year, " .
               " EXTRACT( MONTH FROM posted_on ) as month\n" .
               $trailing;
    }
    elsif ( 'sqlite' eq $driver ) {
        return "SELECT count(*), substr( posted_on, 1, 4 ) as year, " .
               " substr( posted_on, 6, 2 ) as month\n" .
               $trailing;
    }
    return;
}

# Get all sections, or add an error message to the action

sub _get_sections {
    my ( $self ) = @_;
    my $sections = eval {
        CTX->lookup_object( 'news_section' )
           ->fetch_group({ order => 'section' })
    };
    if ( $@ ) {
        $log->error( "Failed to get news sections: $@" );
        $self->add_error_key( 'news.error.fetch_sections', $@ );
    }
    $sections ||= [];
    return $sections;
}

1;
