package OpenInteract2::Action::Comments;

# $Id: Comments.pm,v 1.16 2005/09/24 14:01:40 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use HTML::Entities;
use Log::Log4perl            qw( get_logger );
use Mail::Sendmail;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Cookie;
use OpenInteract2::Util;

$OpenInteract2::Action::Comments::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my $DEFAULT_ECODE_LINE_LENGTH = 70;
my $DELIMITER                 = ':::';

# Display some summary info (plus a link) for an object

sub show_summary {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my ( $obj_class, $obj_id ) = $self->_get_class_and_id;
    unless ( $obj_class and $obj_id ) {
        $log->warn( "Cannot display summary: no object or ",
                    "object class + ID given" );
        return $self->_msg( 'comments.error.summary_data_missing' );
    }

    my %params = ();

    $log->is_debug &&
        $log->debug( "Fetching summary for '$obj_class: $obj_id'" );
    my $summaries = eval {
        OpenInteract2::CommentSummary->fetch_group({
            where => 'class = ? AND object_id = ?',
            value => [ $obj_class, $obj_id ],
        })
    };
    if ( $@ ) {
        $params{comment_error} = "$@";
    }
    else {
        my ( $summary );
        if ( scalar @{ $summaries } > 0 ) {
            $log->is_info && $log->info( "Fetched summary ok" );
            $summary = $summaries->[0];
        }
        else {
            $log->is_info &&
                $log->info( "No summary available, creating transient one" );
            $summary = OpenInteract2::CommentSummary->new({
                num_comments => 0,
                class        => $obj_class,
                object_id    => $obj_id
            });
            my $object = eval { $obj_class->fetch( $obj_id ) };
            if ( $@ ) {
                $log->error( "FAILURE: Cannot fetch for summary object ",
                             "'$obj_class: $obj_id': $@" );
            }
            else {
                my $info = $object->object_description;
                $summary->{object_title} = $info->{title};
                $summary->{object_url}   = $info->{url};
            }
        }
        $params{url}     = $summary->{object_url};
        $params{summary} = $summary;
    }
    return $self->generate_content(
                    \%params, { name => 'comments::comment_summary' } );
}


# List comments across objects

sub list {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $page_size = $request->param( 'page_size' )
                    || $self->param( 'default_page_size' )
                    || 25; # last-ditch effort...
    my $page_num = $request->param( 'page_num' ) || 1;

    # These need to be 0-based...

    my $lower_bound = ( $page_size * ( $page_num - 1 ) );
    my $upper_bound = ( $page_size * $page_num ) - 1;

    # ...but we pass 1-based figures to the template (how humane)

    my %params = (
        lower_bound  => $lower_bound + 1,
        upper_bound  => $upper_bound + 1,
        page_num     => $page_num,
        page_size    => $page_size,
        num_comments => $request->param( 'num_comments' ),
    );
    my $comments = eval {
        OpenInteract2::Comment->fetch_group({
            limit        => "$lower_bound,$upper_bound",
            order        => 'posted_on DESC',
            column_group => 'summary',
        })
    };
    if ( $@ ) {
        $self->add_error_key( 'comments.error.cannot_fetch_listing', "$@" );
        $log->error( "Cannot fetch comments: $@" );
    }
    else {
        $params{comments} = $comments;
        if ( scalar @{ $comments } > 0 ) {

            # Egads this is inefficient...
            eval { $_->get_summary for ( @{ $comments } ) };
            if ( $@ ) {
                $log->warn( "Failed to fetch comment summary: $@" );
            }
        }
        unless ( $params{num_comments} ) {
            $params{num_comments} = OpenInteract2::Comment->count_comments;
        }
    }
    return $self->generate_content(
                    \%params, { name => 'comments::comment_list_page' } );
}


# List all comments for a particular object. (This is similar to the
# 'get_comments' method in ::Commentable, but objects aren't
# *required* to inherit it.)

sub list_by_object {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    $self->param_from_request( 'class', 'object_id' );
    my ( $obj_class, $obj_id ) = $self->_get_class_and_id();

    unless ( $obj_class and $obj_id ) {
        $log->error( 'Class/object_id not given to find object' );
        return $self->_msg( 'comments.error.list_for_object_data_missing' );
    }
    $log->is_debug &&
        $log->debug( "Will display comments for [$obj_class: $obj_id]" );
    my $object = $self->param( 'object' );
    unless ( $object ) {
        $object = eval { $obj_class->fetch( $obj_id ) };
        if ( $@ ) {
            $log->error( "Failed to fetch '$obj_class: $obj_id': $@" );
            return $self->_msg( 'comments.error.cannot_fetch_object_for_listing' );
        }
    }
    my %params = (
        object     => $object,
        summary    => $self->param( 'summary' ),
        standalone => $self->param( 'standalone' ),
    );
    my $comments = eval {
        OpenInteract2::Comment->fetch_group({
            where => 'class = ? and object_id = ?',
            value => [ $obj_class, $obj_id ],
            order => 'posted_on ASC'
        })
    };
    if ( $@ ) {
        $log->error( "Error fetching comments: $@" );
        $self->add_error_key( 'comments.error.cannot_fetch_by_object', "$@" );
    }
    else {
        $log->is_info &&
            $log->info( "Fetched comments ok (", scalar( @{ $comments } ), ")" );
        $params{comments} = $comments;
    }
    return $self->generate_content(
                    \%params, { name => 'comments::comment_list' } );
}


# Display a single comment

sub display {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $comment_id = $self->param( 'comment_id' )
                     || $request->param( 'comment_id' );
    my %params = ();
    if ( $comment_id ) {
        my $comment = eval { OpenInteract2::Comment->fetch( $comment_id ) };
        if ( $@ ) {
            $log->error( "Error retrieving comment '$comment_id': $@" );
            $self->add_error_key( 'comments.error.cannot_fetch', "$@" );
        }
        if ( $comment ) {
            $params{comment} = $comment;
        }
        else {
            $log->error( "No comment found for given ID '$comment_id'" );
            $self->add_error_key( 'comments.error.not_found' );
        }
    }
    else {
        $self->add_error_key( 'comments.error.no_id' );
    }

    return $self->generate_content(
                    \%params, { name => 'comments::comment_detail' } );
}


# This is internal-only: reads
#   form_settings (\%)
#   comment       (object)
#   pre_escaped   ($)

sub _show_editable {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $comment       = $self->param( 'comment' );
    my %params = ();


    # If we were provided a comment, take the content and place it
    # into a variable 'preview_text' and move the 'pre_escaped'
    # content into the comment.

    if ( $comment ) {
        $params{preview_text} = $comment->{content};
        $comment->{content} = $self->param( 'pre_escaped' );
    }

    # If we weren't supplied a comment, grab the name/URL/email info
    # from the cookie if it exists as well as pulling the
    # class/object_id from the parameters/object

    else {
        $comment = $self->_fill_in_default_comment;
    }

    $params{comment}         = $comment;
    $params{object}          = $self->_fetch_object_for_comment( $comment );

    my $remember_poster = $self->param( 'remember_poster' );
    $params{remember_poster} =
        $remember_poster || ( $self->_has_cookie() ) ? 'yes' : '';

    my $is_subscribed = $self->param( 'is_subscribed' );
    $params{is_subscribed}   =
        $is_subscribed   || ( $self->_is_subscribed( $comment ) ) ? 'yes' : 'no';

    return $self->generate_content(
                    \%params, { name => 'comments::comment_form_page' } );
}

sub _fetch_object_for_comment {
    my ( $self, $comment ) = @_;
    my $obj_class = $comment->{class};
    my ( $object );
    if ( $obj_class ) {
        $object = eval { $obj_class->fetch( $comment->{object_id} ) };
        if ( $@ ) {
            $self->add_error_key( 'comments.error.cannot_fetch_object', "$@" );
            $object = undef;
        }
    }
    else {
        $self->add_error_key( 'comments.error.no_class_for_object' );
    }
    return $object;
}

sub show_empty_form {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );
    my ( $object_class, $object_id ) = $self->_get_class_and_id();
    my %params = ();
    $params{is_disabled} = OpenInteract2::CommentDisable->is_disabled(
        $object_class, $object_id,
    );
    if ( $params{is_disabled} ) {
        $log->is_info &&
            $log->info( "Comments are disabled for [$object_class $object_id] ",
                        "(may be all objects in class are disabled)" );
    }
    else {
        $params{comment}    = $self->_fill_in_default_comment();
        $params{has_cookie} = $self->_has_cookie() ? 'yes' : 'no';
        if ( $params{has_cookie} ) {
            $params{is_subscribed} =
                $self->_is_subscribed( $params{comment} ) ? 'yes' : 'no';
        }
        else {
            $params{is_subscribed} = 'no';
        }
    }
    return $self->generate_content(
                    \%params, { name => 'comments::comment_form' } );
}

sub _is_subscribed {
    my ( $self, $comment ) = @_;
    my ( $c_class, $c_id ) = ( $comment->{class}, $comment->{object_id} );
    return 0 unless ( $c_class and $c_id );
    my $poster_info = $self->_get_info_from_cookie();
    return 0 unless ( $poster_info->{email} );
    my $items = OpenInteract2::CommentNotify->fetch_group({
        where => 'class = ? AND object_id = ? AND email = ?',
        value => [ $c_class, $c_id, lc $poster_info->{email} ]
    });
    return ( ref $items and scalar @{ $items } );
}

sub _has_cookie {
    my ( $self ) = @_;
    my $poster_info = $self->_get_info_from_cookie;
    return ( $poster_info ) ? 1 : 0;
}

sub _fill_in_default_comment {
    my ( $self ) = @_;
    my $comment = OpenInteract2::Comment->new();
    my $poster_info = $self->_get_info_from_cookie;
    if ( $poster_info ) {
        $comment->{poster_name}  = $poster_info->{name};
        $comment->{poster_url}   = $poster_info->{url};
        $comment->{poster_email} = $poster_info->{email};
    }

    my ( $o_class, $o_id ) = $self->_get_class_and_id();
    $comment->{class}     = $o_class;
    $comment->{object_id} = $o_id;
    return $comment;
}

sub _get_class_and_id {
    my ( $self ) = @_;
    my $object = $self->param( 'object' );
    my ( $o_class, $o_id );
    if ( $object ) {
        $o_class = ref $object;
        $o_id    = $object->id;
    }
    else {
        $o_class = $self->param( 'class' );
        $o_id    = $self->param( 'object_id' );
    }
    return ( $o_class, $o_id );
}


sub _get_cookie_name {
    my ( $self ) = @_;
    return $self->param( 'cookie_name' ) ||
           $self->param( 'default_cookie_name' ) ||
           'comment_info';
}

sub _get_info_from_cookie {
    my ( $self ) = @_;
    my $cookie_name = $self->_get_cookie_name();
    my $poster_info = CTX->request->cookie( $cookie_name );
    return unless ( $poster_info );
    my ( $name, $url, $email ) = split $DELIMITER, $poster_info;
    return { name => $name, url => $url, email => $email };
}

sub _store_cookie {
    my ( $self, $name, $url, $email ) = @_;
    my $cookie_info = join( $DELIMITER, $name, $url, $email );
    OpenInteract2::Cookie->create({
        name    => $self->_get_cookie_name(),
        value   => $cookie_info,
        expires => '+6M',
        HEADER  => 'yes',
    });
}

sub _remove_cookie {
    my ( $self ) = @_;
    OpenInteract2::Cookie->expire( $self->_get_cookie_name() );
}


sub add {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;

    # Fill the comment...

    my $comment = OpenInteract2::Comment->new();

    my @editable_fields = qw( class object_id subject content
                              poster_name poster_email poster_url );
    foreach my $field ( @editable_fields ) {
        my $value = $request->param( $field );
        $value =~ s/^\s+//;
        $value =~ s/\s+$//;
        $log->is_debug &&
            $log->debug( "Assigning to comment: $field = $value" );
        $comment->{ $field } = $value
    }

    # Stick in right now (with timezone)...

    $comment->{posted_on} = CTX->create_date();

    # Ensure URLs at least start with HTTP...

    unless ( $comment->{poster_url} =~ m|^http(s)?://| ) {
        $comment->{poster_url} = undef;
    }

    # store the unescaped version for the re-editing (if preview)

    $self->param( pre_escaped => $comment->{content} );

    # pull out any <ecode></ecode> sections for later

    my $placeholder = 'CODECONTENT';

    my @code_sections = ();
    my $count = 0;
    $comment->{content} =~ s|
        (<ecode>(.*?)</ecode>)
    |
        push @code_sections, $2;
        $placeholder . ++$count;
    |gisemx;

    # Get rid of any HTML tags (be sure this is after code sections)

    $comment->{content} =~ s|<[^>]+>||gs;
    $comment->{subject} =~ s|<[^>]+>||gs;

    # Escape any remaining HTMLisms

    $comment->{content} = HTML::Entities::encode( $comment->{content} );
    $comment->{subject} = HTML::Entities::encode( $comment->{subject} );

    # Autocreate any links

    $comment->{content} =~ s|(http://[^\s\)\]]+)|<a href="$1">$1</a>|g;

    # \n\n -> <p>

    $comment->{content} =~ s/(\r\n\r\n|\n\n)/$1<p>/g;

    # put the code sections back in
    $count = 1;
    foreach my $section ( @code_sections ) {
        my $fixed_section = $self->_trim_preformatted_line_length( $section );
        $comment->{content} =~ s|$placeholder$count|<pre class="commentCode">$fixed_section</pre>|gsm;
        $count++;
    }

    $comment->{poster_host} = $request->remote_host;

    # Non-object form widgets

    $self->param( remember_poster => scalar( $request->param( 'remember_poster' ) ) );
    $self->param( is_subscribed   => scalar( $request->param( 'is_subscribed' ) ) );

    # check requirements

    my %required = (
          poster_name => 'Name',
          subject     => 'Subject',
          content     => 'Comments',
    );
    my @required_missing = ();
    for ( keys %required ) {
        push @required_missing, $required{ $_ } unless ( $comment->{ $_ } );
    }

    $self->param( comment => $comment );

    if ( scalar @required_missing ) {
        $self->add_error_key( 'comments.error.data_missing',
                              join( ', ', @required_missing ) );
        return $self->_show_editable;
    }

    my $action = $request->param( 'action' );
    if ( $action eq $self->_msg( 'comments.form.preview' ) ) {
        return $self->_show_editable;
    }

    # Save this for the next screen...

    $self->param( class     => $comment->{class} );
    $self->param( object_id => $comment->{object_id} );

    # See if the poster wants his/her information remembered in a
    # cookie.

    my $remember = $request->param( 'remember_poster' );
    if ( $remember eq 'yes' ) {
        $self->_store_cookie( $comment->{poster_name},
                              $comment->{poster_url},
                              $comment->{poster_email} );
        $log->is_info && $log->info( "Created 'remember' cookie" );
    }
    else {
        $self->_remove_cookie();
    }

    eval { $comment->save };
    if ( $@ ) {
        $log->error( "Failed to add comment: $@" );
        $self->add_error_key( 'comments.error.cannot_add', "$@" );
    }
    else {
        $self->add_status_key( 'comments.status.add_ok' );

        # These are used for the listing page we go to next...

        $self->param( standalone => 1 );
        $self->param( summary    => $comment->get_summary );

        # Take care of creating/sending notifications

        $self->_add_auto_notifications( $comment );
        $self->_process_notifications( $comment );
        $self->_check_user_notification( $comment );
    }
    return $self->list_by_object;
}

sub _trim_preformatted_line_length {
    my ( $self, $text ) = @_;
    my @new = ();
    my $max = $self->param( 'max_ecode_line' ) || $DEFAULT_ECODE_LINE_LENGTH;
    foreach my $line ( split /\r?\n/, $text ) {
        if ( length $line > $max ) {
            push @new, substr( $line, 0, $max ) . '+',
                       substr( $line, $max );
        }
        else {
            push @new, $line;
        }
    }
    return join( "\n", @new );
}

# When a new thread is added you can add people who get notified with
# every new message in that thread. Return value is the number of
# auto-notifications added successfully.

sub _add_auto_notifications {
    my ( $self, $comment ) = @_;
    $log ||= get_logger( LOG_APP );

    # If this isn't the first comment in the thread, we don't need to
    # do anything

    if ( $comment->get_summary->{num_comments} > 1 ) {
        $log->is_debug &&
            $log->debug( 'Not the first comment in a thread, no auto-notify' );
        return;
    }

    my $action_info = CTX->lookup_action_info( 'comment' );

    # If no notifications setup, nothing todo
    unless ( $action_info->{notify} ) {
        $log->is_debug &&
            $log->debug( "No auto-notifications setup in 'comment' action" );
        return;
    }

    # These are the people who get notified, in 'name|email@foo.com'
    # format

    my @defaults = ( ref $action_info->{notify} eq 'ARRAY' )
                     ? @{ $action_info->{notify} }
                     : ( $action_info->{notify} );
    my $success = 0;
    for ( @defaults ) {
        my ( $name, $email ) = split /\s*\|\s*/, $_;
        eval {
            OpenInteract2::CommentNotify->new({
                class     => $comment->{class},
                object_id => $comment->{object_id},
                name      => $name,
                email     => lc $email
            })->save()
        };
        if ( $@ ) {
            $log->error( "Failed to add notification for ",
                         "[$name: $email]: $@" );
        }
        else {
            $success++;
            $log->is_info &&
                $log->info( "Added auto notification for ",
                            "[$name: $email] ok" );
        }
    }
    return $success;
}


# Now see if the user posting the comment would like to be notified on
# further posts. Return value is the status they see.

sub _check_user_notification {
    my ( $self, $comment ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $is_subscribed = $self->_is_subscribed( $comment );
    my $user_sub_option = $request->param( 'is_subscribed' );

    if ( $is_subscribed and $user_sub_option eq 'yes' ) {
        $log->is_debug &&
            $log->debug( "User subscribes and wants to keep notification" );
        return;
    }
    elsif ( ! $is_subscribed and $user_sub_option eq 'no' ) {
        $log->is_debug &&
            $log->debug( "User is not subscriber and has elected not ",
                         "to be notified of new messages in thread" );
        return;
    }

    # If the poster didn't specify an email or the email seems bad,
    # return an error message

    my $email = $comment->{poster_email};
    unless ( $email ) {
        $log->is_info &&
            $log->info( "Posted wants to be notified but didn't ",
                        "provide an email address" );
        $self->add_error_key( 'comments.error.cannot_add_notify_no_email' );
        return;
    }

    unless ( $email =~ /$Mail::Sendmail::address_rx/ ) {
        $log->is_info &&
            $log->info( "Posted wants to be notified but provided a bad ",
                        "email address: '$email'" );
        $self->add_error_key(
            'comments.error.cannot_add_notify_bad_email', $email );
        return;
    }

    # Fetch the existing notifications and see if this email address
    # is already registered

    my $notifications = eval {
        OpenInteract2::CommentNotify->fetch_group({
            where => 'class = ? AND object_id = ? AND email = ?',
            value => [ $comment->{class}, $comment->{object_id}, lc $email ],
        })
    };
    if ( $@ ) {
        $log->error( "Error fetching notifications for: ",
                     "$comment->{class}; $comment->{object_id}; $email: $@" );
        $self->add_error_key( 'comments.error.cannot_add_notify_error_dupe_check' );
        return;
    }
    my $existing_notifications =
        ( ref $notifications eq 'ARRAY' and scalar @{ $notifications } );

    if ( $is_subscribed and $existing_notifications  ) {
        my $notify = $notifications->[0];
        eval { $notify->remove };
        if ( $@ ) {
            $log->error( "Cannot remove notification: $@" );
            $self->add_error_key( 'comments.error.cannot_remove_notify' );
        }
        else {
            $self->add_status_key( 'comments.status.remove_notify_ok' );
        }
    }

    elsif ( $existing_notifications ) {
        $log->is_debug &&
            $log->debug( "No notification added: already exists in thread" );
        $self->add_error_key( 'comments.error.cannot_add_notify_is_dupe' );
    }

    else {
        eval {
            OpenInteract2::CommentNotify->new({
                class     => $comment->{class},
                object_id => $comment->{object_id},
                name      => $comment->{poster_name},
                email     => lc $comment->{poster_email}
            })->save()
        };
        if ( $@ ) {
            $log->error( "Failed to save notification: $@" );
            $self->add_error_key( 'comments.error.cannot_add_notify_persist', "$@" );
        }
        else {
            $self->add_status_key( 'comments.status.add_notify_ok' );
        }
    }
}

sub _process_notifications {
    my ( $self, $comment ) = @_;
    $log ||= get_logger( LOG_APP );

    my $notes = eval {
        OpenInteract2::CommentNotify->fetch_group({
            where => 'class = ? AND object_id = ?',
            value => [ $comment->{class}, $comment->{object_id} ],
        })
    };
    if ( $@ ) {
        $log->error( "Failed to fetch notifications for processing: $@" );
        return undef;
    }
    unless ( ref $notes eq 'ARRAY' and scalar @{ $notes } ) {
        $log->is_info &&
            $log->info( "No notifications to process for ",
                        "'$comment->{class}: $comment->{object_id}'" );
        return 0;
    }

    my $summary = $comment->get_summary;
    my $server_name = CTX->request->server_name;
    my %params = ( comment     => $comment,
                   summary     => $summary,
                   server_name => $server_name );
    my $message = $self->generate_content(
        \%params, { name => 'comments::notification_email' });
    my $subject = $self->_create_email_subject;
    my $success = 0;
    my $from_address = CTX->lookup_mail_config->{content_email};
    $log->is_info &&
        $log->info( "Sending ", scalar @{ $notes }, " notification messages ",
                    "from address '$from_address'" );
    foreach my $note ( @{ $notes } ) {
        my $to = ( $note->{name} )
                   ? qq("$note->{name}" <$note->{email}>)
                   : $note->{email};
        eval {
            OpenInteract2::Util->send_email({
                to      => $to,
                from    => $from_address,
                subject => $subject,
                message => $message
            })
        };
        if ( $@ ) {
            $log->error( "Failed to send to '$to': $@" );
        }
        else {
            $success++;
            $log->is_info &&
                $log->info( "Sent notification message to '$to' ok" );
        }
    }
    return $success;
}

sub _create_email_subject {
    my ( $self ) = @_;
    my $base_subject = $self->param( 'notify_subject' ) ||
                       "New comment posted on SERVER_NAME";
    my $server_name = CTX->request->server_name;
    $base_subject =~ s/SERVER_NAME/$server_name/g;
    return $base_subject;
}


sub remove {
    my ( $self ) = @_;
    $self->add_error( 'REMOVE not implemented yet' );
    return $self->list_by_object;
}

sub show_notify {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );
    my $request = CTX->request;

    my ( $obj_class, $obj_id );
    my $object = $self->param( 'object' );
    if ( $object ) {
        $obj_class = ref $object;
        $obj_id    = $object->id;
    }
    else {
        $obj_class = $self->param( 'class' ) ||
                     $request->param( 'class' );
        $obj_id    = $self->param( 'object_id' ) ||
                     $request->param( 'object_id' );
    }
    unless ( $obj_class and $obj_id ) {
        return "No class/ID given for which to fetch notifications." .
               "(Given '$obj_class' $obj_id')";
    }
    my %params = ();

    $params{notes} = eval {
        OpenInteract2::CommentNotify->fetch_group({
            where => 'class = ? AND object_id = ?',
            value => [ $obj_class, $obj_id ]
        })
    };
    if ( $@ ) {
        $log->error( "Error fetching notifications for ",
                     "[$obj_class: $obj_id]: $@" );
        $self->add_error_key( 'comments.error.cannot_fetch_notify', "$@" );
    }
    else {
        my $summaries = eval {
            OpenInteract2::CommentSummary->fetch_group({
                where => 'class = ? AND object_id = ?',
                value => [ $obj_class, $obj_id ]
            })
        };
        $params{summary} = $summaries->[0];
    }
    return $self->generate_content(
                    \%params, { name => 'comments::comment_notify_list' } );
}

sub comment_recent {
    my ( $self ) = @_;
    my $recent_num = $self->param( 'comment_count' ) ||
                     $self->param( 'default_comment_count' ) ||
                     5; # last-ditch effort...
    my %params = ();
    my $comments = eval {
        OpenInteract2::Comment->fetch_group({
            limit        => $recent_num,
            order        => 'posted_on DESC',
            column_group => 'summary',
        })
    };
    if ( $@ ) {
        $params{error} = $self->_msg(
            'comments.error.cannot_fetch_recent', "$@" );
    }
    else {
        $params{comments} = $comments;
    }
    return $self->generate_content( \%params );
}

1;
