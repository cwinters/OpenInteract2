package OpenInteract2::SPOPS;

# $Id: SPOPS.pm,v 1.31 2005/03/18 03:34:27 lachoy Exp $

use strict;
use Digest::MD5              qw( md5_hex );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::URL;
use OpenInteract2::Util;

$OpenInteract2::SPOPS::VERSION = sprintf("%d.%02d", q$Revision: 1.31 $ =~ /(\d+)\.(\d+)/);

my ( $log );

# This is not public, look away, look away!
$OpenInteract2::SPOPS::TRACKING_DISABLED = 0;

########################################
# OBJECT DESCRIPTION

# overrides implementation from SPOPS.pm

sub object_description {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_SPOPS );

    my $config = $self->CONFIG;
    my $object_type = $config->{object_name};
    my $title_info  = $config->{title} || $config->{name};
    $log->is_debug &&
        $log->debug( "Describing SPOPS object '$object_type' '$title_info'" );
    my $title = '';
    if ( exists $self->{ $title_info } ) {
        $title = $self->{ $title_info };
    }
    elsif ( $title_info ) {
        $title = eval { $self->$title_info() };
    }
    $title ||= 'Cannot find name';

    my $u = OpenInteract2::URL->new();
    my $oid       = $self->id;
    my $id_field  = $self->id_field;
    $log->is_debug && $log->debug( "Describe: '$oid' '$id_field'" );
    my ( $url, $url_edit );
    my $inf = $config->{display} || {};
    my @url_param_values = ();
    if ( $inf->{URL_PARAMS} ) {
        my @url_params = ( ref $inf->{URL_PARAMS} )
                           ? @{ $inf->{URL_PARAMS} }
                           : ( $inf->{URL_PARAMS} );
        @url_param_values = map { eval { $self->$_() } } @url_params;
    }
    if ( $inf->{ACTION} ) {
        if ( $inf->{TASK} and @url_param_values ) {
            $url = $u->create_from_action(
                $inf->{ACTION}, $inf->{TASK},
                { URL_PARAMS => \@url_param_values }
            );
        }
        elsif ( $inf->{TASK} ) {
            $url = $u->create_from_action(
                $inf->{ACTION}, $inf->{TASK},
                { $id_field => $oid }
            );
        }
        if ( $inf->{TASK_EDIT} and @url_param_values ) {
            $url_edit = $u->create_from_action(
                $inf->{ACTION}, $inf->{TASK_EDIT},
                { URL_PARAMS => \@url_param_values }
            );
        }
        elsif ( $inf->{TASK_EDIT} ) {
            $url_edit = $u->create_from_action(
                $inf->{ACTION}, $inf->{TASK_EDIT},
                { $id_field => $oid }
            );
        }

    }
    else {
        if ( $inf->{url} ) {
            $url = "$inf->{url}?" . $id_field . '=' . $oid;
        }
        if ( $inf->{url_edit} ) {
            $url_edit = "$inf->{url_edit}?" . $id_field . '=' . $oid;
        }
        else {
            $url_edit = "$inf->{url}?edit=1;" . $id_field . '=' . $oid;
        }
    }
    my ( $object_date );
    if ( my $date_field = $inf->{date} ) {
        $object_date = $self->$date_field();
    }
    $log->is_debug &&
        $log->debug( "Describe: '$url', '$url_edit', '$object_date'" );
    return {
        class       => ref $self,
        object_id   => $oid,
        oid         => $oid, # backwards compatibility
        security    => $self->{tmp_security_level},
        id_field    => $id_field,
        name        => $object_type,
        title       => $title,
        date        => $object_date,
        url         => $url,
        url_edit    => $url_edit,
    };
}


########################################
# OBJECT TRACK METHODS

# Just a wrapper for log_action_enter, although we make sure that the
# action is allowed before doing it.

sub log_action {
    my ( $self, $action, $id ) = @_;
    return 1   unless ( $self->CONFIG->{track}{ $action } );
    return 1   if ( $OpenInteract2::SPOPS::TRACKING_DISABLED );
    return $self->log_action_enter( $action, $id );
}


# Log the object, the action (create, update, remove), who did
# the action and when it was done.
#
# Note that you can pass the uid in directly to override the current user

sub log_action_enter {
    my ( $self, $action, $id, $uid ) = @_;
    $log ||= get_logger( LOG_SPOPS );

    my $req = CTX->request;
    my $log_msg = 'no log message';

    # This looks weird but it's here for when you run actions not
    # logged in as user and outside the bounds of a request/response
    # lifecycle...

    if ( UNIVERSAL::isa( $req, 'OpenInteract2::Request' ) )  {
        $uid ||= $req->auth_user_id;
        $log_msg = $req->param( '_log_message' );
    }
    else {
        $uid ||= CTX->lookup_default_object_id( 'superuser' );
    }
    my $now = DateTime->now;
    my $class = ref $self || $self;
    $log->is_debug &&
        $log->debug( "Log [$action] [$class] [$id] by [$uid] [$now]" );
    my $object_action = eval {
        CTX->lookup_object( 'object_action' )
           ->new({ class     => $class,
                   object_id => $id,
                   action    => $action,
                   action_by => $uid,
                   action_on => $now,
                   notes     => $log_msg })
           ->save()
    };
    if ( $@ ) {
        $log->error( "Log entry failed: $@" );
        return undef;
    }
    return 1;
}


# Retrieve the user who created a particular object

sub fetch_creator {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_SPOPS );

    # Bail if it's not an already-existing object

    return undef  unless ( ref $self and $self->id );
    my $track = eval {
        CTX->lookup_object( 'object_action' )
           ->fetch_object_creation( $self )
    };
    if ( $@ ) {
        $log->error( "Failed to retrieve object creator(s): $@" );
        return undef;
    }
    my $creator = eval { $track->action_by_user };
    if ( $@ ) {
        $log->error( "Error fetching creator: $@" );
    }
    return $creator;
}


# Return 1 if the user represented by $uid is a creator
# of an object (or the superuser), undef if not

sub is_creator {
    my ( $self, $uid ) = @_;
    my $req = CTX->request;
    $uid ||= $req->auth_user_id;
    return undef unless ( $uid );

    # the great and powerful superuser sees all

    return 1 if ( $uid eq CTX->lookup_default_object_id( 'superuser' ) );

    my $creator = $self->fetch_creator;
    return ( $creator->id eq $uid );
}

# TODO: Update this to just return the object...
#
# Retrieve an arrayref of arrayrefs where item 0 is the uid
# of the user who last did the update and item 1 is the
# date of the update

sub fetch_updates {
    my ( $self, $opt ) = @_;
    $log ||= get_logger( LOG_SPOPS );

    # Bail if it's not an already-saved object

    return []  unless ( ref $self and $self->id );
    my $limit = ( $opt eq 'last' ) ? '1' : int( $opt );
    my $updates = eval {
        CTX->lookup_object( 'object_action' )
           ->fetch_actions( $self,
                            { limit        => $limit,
                              column_group => 'base' } )
    };
    if ( $@ ) {
        $log->error( "Cannot retrieve object updates: $@" );
        return undef;
    }
    $log->is_debug &&
        $log->debug( "Data from updates:\n", CTX->dump( $updates ) );
    return [ map { [ $_->{action_by}, $_->{action_on} ] } @{ $updates } ];
}


########################################
# SECURITY

# Override method in SPOPS::Secure since we already know the
# user/group information from the context

sub get_security_scopes {
    my ( $self, $p ) = @_;
    my $req = CTX->request;
    if ( $req ) {
        return ( $req->auth_user, $req->auth_group );
    }
    else {
        return ( undef, [] );
    }
}



# Let SPOPS::Secure know what the IDs are for the superuser and
# supergroup

sub get_superuser_id  {
    return CTX->lookup_default_object_id( 'superuser' );
}

sub get_supergroup_id  {
    return CTX->lookup_default_object_id( 'supergroup' );
}

########################################
# DATASOURCE

sub global_datasource_handle {
    my ( $self, $connect_key ) = @_;
    $connect_key ||= $self->CONFIG->{datasource}
                     || CTX->lookup_default_datasource_name;
    return CTX->datasource( $connect_key );
}


########################################
# GLOBAL OBJECTS/CLASSES

# These are used so that subclasses (and other classes in the
# inheritance hierarchy, particularly within SPOPS) are able to have
# access to the various objects and resources

sub global_cache                 { return CTX->cache           }

# ugh .. is this used
sub global_config                { return CTX->server_config          }

# Is this right? Is this needed?
sub global_secure_class          { return CTX->lookup_object( 'secure' ) }

sub global_security_object_class { return CTX->lookup_object( 'security' ) }
sub global_user_class            { return CTX->lookup_object( 'user' ) }
sub global_group_class           { return CTX->lookup_object( 'group' ) }

sub global_user_current {
    my $req = CTX->request;
    return ( $req ) ? CTX->request->auth_user : undef;
}

sub global_group_current {
    my $req = CTX->request;
    return ( $req ) ? CTX->request->auth_group : [];
}


########################################
# OTHER METHODS

# Send an email with one or more objects as the body.

sub notify {
    my ( $item, $p ) = @_;
    $log ||= get_logger( LOG_SPOPS );

    my $req = CTX->request;
    $p->{object} ||= [];

    # If we weren't given any objects and we were called by
    # a class instead of an object

    return undef unless ( ref $item or scalar @{ $p->{object} } );

    # If we were just called by an object, make it our message

    push @{ $p->{object} }, $item  unless ( scalar @{ $p->{object} } );
    my $num_objects = scalar @{ $p->{object} };
    my $subject = $p->{subject} || "Object notification: $num_objects objects in mail";
    my $separator = '=' x 25;
    my $msg = ( $p->{notes} ) ?
                join( "\n", 'Notes', "$separator$p->{notes}", $separator, "\n" ) : '';
    foreach my $obj ( @{ $p->{object} } ) {
        my $info = $obj->object_description;
        my $object_url = join( '', 'http://', $req->server_name, $info->{url} );
        $msg .= <<OBJECT;
Begin $info->{name} object
$separator
@{[ $obj->as_string ]}

View this object at: $object_url
$separator
End $p->{name} object

OBJECT
    }
    my $from_email = $p->{email_from} ||
                     CTX->lookup_mail_config->{admin_email};
    eval {
        OpenInteract2::Util->send_email({ to      => $p->{email},
                                          from    => $from_email,
                                          subject => $subject,
                                          message => $msg });
    };
    if ( $@ ) {
        $log->error( "Failed to send email: $@" );
        return undef;
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenInteract2::SPOPS - Define common behaviors for all SPOPS objects in the OpenInteract Framework

=head1 SYNOPSIS

 # In the server configuration ($WEBSITE_DIR/conf/server.ini)
 
 # First define the datasource type ('DBI') and associate that type
 # with an OI2::SPOPS subclass...
 
 [datasource_type DBI]
 connection_manager = OpenInteract2::Datasource::DBI
 spops_config       = OpenInteract2::SPOPS::DBI
 
 # Then declare a datasource and associate it with that type; SPOPS
 # objects associated with this datasource will have 'OI2::SPOPS::DBI'
 # automatically placed in the 'isa'.
 
 [datasource main]
 type          = DBI
 ...

=head1 DESCRIPTION

Here we provide some common operations within OpenInteract that are
not implmented within the data abstraction layer itself. Since we want
to continue using both separately we cannot embed ideas like a
configuration object or a particular cache implementation within
SPOPS. Think of this class as a bridge between the two.

Note that while most of the functionality is in this class, you will
always want to use one of the implementations-specific child classes
-- see L<OpenInteract2::SPOPS::DBI|OpenInteract2::SPOPS::DBI> and
L<OpenInteract2::SPOPS::LDAP|OpenInteract2::SPOPS::LDAP>.

=head1 DESCRIBING AN OBJECT

B<object_description()>

Very useful method you can call on any SPOPS object to get general
information about it. It's particularly useful when you're dealing
with an object of an unknown type -- such as when you're doing
fulltext searching or object tagging -- and need summary information
about it.

The method overrides the implementation found in L<SPOPS>, returning a
hashref of information with the keys:

=over 4

=item B<class>

Class of the object.

=item B<object_id>

ID of this particular object.

=item B<id_field>

ID field for this object.

=item B<name>

General type of this object: 'News', 'Document', etc.

=item B<title>

Title of this specific object: 'Weather tomorrow to be scorching',
'Recipe: Franks and Beans', etc.

=item B<date>

Date associated with this object, typically a created-on or updated-on
date and usually a L<DateTime> object.

=item B<security>

Security set on this object, matches one of the C<SEC_LEVEL_>
constants exported from L<SPOPS::Secure>.

=item B<url>

URL to display the object.

=item B<url_edit>

URL to display an editable form of the object.

=back

Some of these values you can control from your SPOPS configuration:

B<id_field>

Matches whatever you set in your C<id_field> key.

B<name>

Matches whatever you set in your C<object_name> key.

B<title>

Use C<title> (or C<name> as the method to call to retrieve the
title. So say you had an object representing a contact in your address
book. That contact may have 'first_name' and 'last_name' defined, but
when you display the object you want the contact's full name. So in
your configuration:

 [contact]
 title = full_name

And in your implementation you might have the naive:

 sub full_name {
     my ( $self ) = @_;
     return join( ' ', $self->first_name, $self->last_name );
 }

B<date>

If you want a date to be associated with your object, put its
field/method here. You're strongly encouraged to return a L<DateTime>
object.

B<url> and B<url_edit>

These can take a little more configuration. All configuration is in
the 'display' section of your SPOPS configuration, such as:

 [news display]
 ACTION     = news
 TASK       = display
 TASK_EDIT  = display_form
 URL_PARAMS = news_id

Most often you'll use the keys 'ACTION', 'TASK', and
'TASK_EDIT'. Similar to other areas of OI2, 'ACTION' and 'TASK' are
used in conjunction with L<OpenInteract2::URL> to create portable
URLs. We add 'TASK_EDIT' here because you typically not only want to
generate a URL for displaying an object but also one for editing it.

If you don't specify any 'URL_PARAMS' then we'll generate a URL with
the given action/task path and a GET param mapping your object's ID
field to its ID value. So the following:

 [news]
 ...
 id_field = news_id
 ...
 [news display]
 ACTION    = news
 TASK      = display
 TASK_EDIT = display_form

will generate the following for an object with ID 99:

 url:      /news/display/?news_id=99
 url_edit: /news/display_form/?news_id=99

However, you can also generate REST-style parameters using the
'URL_PARAMS' key. (This maps to the 'URL_PARAMS' argument passed to
all the C<create*()> methods in L<OpenInteract2::URL>.) So if we
change the above to:

 [news]
 ...
 id_field = news_id
 ...
 [news display]
 ACTION     = news
 TASK       = display
 TASK_EDIT  = display_form
 URL_PARAMS = news_id

Then you'll generate the following URLs with ID 99:

 url:      /news/display/99
 url_edit: /news/display_form/99

=head1 OBJECT TRACKING METHODS

There are a number of methods for dealing with object tracking -- when
a create/update/remove action is taken on an object and by whom.

B<log_action( $action, $id )>

Wrapper for the I<log_action_enter> method below, decides whether it
gets called. (Wrapper exists so subclasses can call log_action_enter
directly and not deal with this step.)

Parameters:

=over 4

=item *

B<action> ($)

Should be 'create', 'update', 'remove'.

B<id> ($)

ID of the object.

=back

B<Returns> undef on failure, true value on success.

B<log_action_enter( $action, $id )>

Makes an entry into the 'object_track' table, which logs all object
creations, updates and deletions. We do not note the content that
changes, but we do note who did the action and when it was done.

Parameters:

=over 4

=item *

B<action> ($)

Should be 'create', 'update', 'remove'.

B<id> ($)

ID of the object.

=back

B<Returns> undef on failure, true value on success.

B<fetch_creator()>

Retrieve an arrayref of all user objects who have 'creator' rights
to a particular object.

B<is_creator( $uid )>

Parameters:

=over 4

=item *

B<uid> ($)

User ID to check and see if that user created this object.

=back

B<Returns> 1 if the object was created by $uid, undef if not.

B<fetch_updates()>

B<Returns> an arrayref of arrayrefs, each formatted:

 [ uid of updater, date of update ]

=head1 METHODS

B<notify()>

Either call from an object or from a class passing an arrayref of
objects to send to a user. Calls the I<as_string()> method of the
object, which (if you look in the SPOPS docs), defaults to being a
simple property -E<gt> value listing. You can override this with
information in your class configuration which specifies the fields you
want to use in the listing along with associated labels.

Parameters:

=over 4

=item *

B<email> ($)

Address to which we should send the notification.

=item *

B<email_from> ($) (optional)

Address from which the email should be sent. If not specified this
defaults to the 'admin_email' setting in your server configuration
(under 'mail').

=item *

B<subject> ($) (optional)

Subject of email. If not specified the subject will be 'Object
notification # objects in mail'.

=item *

B<object> (\@) (optional if called from an object)

If not called from an object, this should be an arrayref of objects to
notify someone about.

=item *

B<notes> ($) (optional)

Notes that lead off an email.

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
