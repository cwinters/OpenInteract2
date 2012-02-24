package OpenInteract2::TT2::Plugin;

# $Id: Plugin.pm,v 1.19 2005/03/17 14:58:05 sjn Exp $

use strict;
use base qw( Template::Plugin );
use Data::Dumper               qw( Dumper );
use DateTime;
use DateTime::Format::Strptime qw( strptime );
use HTML::Entities             qw();
use Log::Log4perl              qw( get_logger );
use OpenInteract2::Constants   qw( :log :template );
use OpenInteract2::Context     qw( CTX );
use OpenInteract2::URL;
use SPOPS::Secure              qw( :level :scope );
use SPOPS::Utility;

$OpenInteract2::TT2::Plugin::VERSION  = sprintf("%d.%02d", q$Revision: 1.19 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my %SECURITY_CONSTANTS  = (
  level => {
     none => SEC_LEVEL_NONE, read => SEC_LEVEL_READ, write => SEC_LEVEL_WRITE
  },
  scope => {
     user => SEC_SCOPE_USER, group => SEC_SCOPE_GROUP, world => SEC_SCOPE_WORLD
  },
);


########################################
# PLUGIN IMPLEMENTATION
########################################

# Simple stub to load/create the plugin object. Since it's really just
# a way to call subroutines and doesn't maintain any state within the
# request, we can just return the same one again and again

sub load {
    my ( $class, $context ) = @_;
    return bless( { _CONTEXT => $context }, $class );
}


sub new {
    my ( $self, $context, @params ) = @_;
    return $self;
}

########################################
# METADATA
########################################

sub show_all_actions {
    my ( $self ) = @_;
    my $class = ref $self || $self;
    no strict 'refs';
    my %skip_actions = map { $_ => 1 } qw( load new Dumper );
    my @skip_initial = qw( SEC _ );
    my $src = \%{ $class . '::' };
    my @methods = ();
SYMBOL:
    foreach my $symbol_name ( keys %{ $src } ) {
        next SYMBOL if ( $skip_actions{ $symbol_name } );
        for ( @skip_initial ) { next SYMBOL if ( $symbol_name =~ /^$_/ ) }
        push @methods, $symbol_name if ( defined *{ $src->{ $symbol_name } }{CODE} );
    }
    return [ sort @methods ];
}

sub show_all_plugins {
    my ( $self ) = @_;
    my $generator = CTX->content_generator( 'TT' );

    # Yes, this is relying on a private data structure...
    my %plugin_info = %{ $generator->{_plugin_class} };
    return \%plugin_info;
}


########################################
# PLUGIN ACTIONS
########################################

sub action_execute {
    my ( $self, $name, $params ) = @_;
    my $action = eval { CTX->lookup_action( $name ) };
    if ( $@ ) {
        return "No action defined for '$name'";
    }
    $log ||= get_logger( LOG_TEMPLATE );
    $params ||= {};
    $log->is_debug &&
        $log->debug( "Trying to assign properties/params to execute ",
                     "action '$name': ", join( ', ', keys %{ $params } ) );
    $action->property_assign( $params );
    $action->param_assign( $params );
    return $action->execute;
}

# L10N stuff

sub msg {
    my ( $self, $key, @params ) = @_;
    my $h = $self->msg_handle();
    unless ( $h ) {
        $log ||= get_logger( LOG_TEMPLATE );
        $log->error( "No language handle available from the request object!" );
        return "msg $key n/a";
    }
    return $h->maketext( $key, @params );
}

sub msg_handle {
    my ( $self ) = @_;
    return CTX->request->language_handle;
}

# BOXES

sub box_add {
    my ( $self, $box, $params ) = @_;
    $params ||= {};
    $log ||= get_logger( LOG_TEMPLATE );
    $log->is_debug && $log->debug( "Template box add '$box' " );
    my %box_info = ( name => $box );
    if ( $params->{remove} ) {
        return $self->box_remove( $box );
    }

    # First assign all the known stuff...

    for ( qw( weight title template is_template ) ) {
        next unless ( $params->{ $_ } );
        $log->is_debug &&
            $log->debug( "Box '$box' param '$_' '$params->{$_}'" );
        $box_info{ $_ } = $params->{ $_ };
        delete $params->{ $_ };
    }

    # Everything else is passed to the box as params...

    $box_info{params} = $params;
    eval { CTX->controller->add_box( \%box_info ) };
    if ( $@ ) {
        $log->error( "Failed to add box '$box_info{name}': $@" );
    }
    return undef;
}

sub box_remove {
    my ( $self, $box_name ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    $box_name =~ s/^\-//;
    eval { CTX->controller->remove_box( $box_name ) };
    if ( $@ ) {
        $log->error( "Failed to remove box '$box_name': $@" );
    }
    return undef;
}


########################################
# SPOPS/OBJECT INFORMATION

# Return a hashref of information about $obj

sub object_description {
    my ( $self, $obj ) = @_;
    return {} unless ( ref $obj and $obj->can( 'object_description' ) );
    return $obj->object_description;
}


# Backward compatibility

sub object_info { return object_description( @_ ); }


# Wrap the call in an eval{} just in case people pass us bad data.

sub class_isa {
    my ( $self, $item, $class ) = @_;
    return eval { $item->isa( $class ) };
}


sub can_read {
    my ( $self, $spops_object ) = @_;
    return undef unless ( $spops_object );
    return ( $spops_object->{tmp_security_level} >= SEC_LEVEL_READ );
}

sub can_write {
    my ( $self, $spops_object ) = @_;
    return undef unless ( $spops_object );
    return ( $spops_object->{tmp_security_level} >= SEC_LEVEL_WRITE );
}





########################################
# DATES

sub _create_date_object {
    my ( $date_string, $date_format ) = @_;
    return $date_string if ( ref $date_string );
    $date_format ||= '%Y-%m-%d %H:%M';
    return ( $date_string =~ /^(today|now)$/ )
             ? DateTime->now()
             : strptime( $date_format, $date_string );
}


# Format a date with a strftime format

sub date_format {
    my ( $self, $date_string, $format, $params ) = @_;
    return undef unless ( $date_string );
    $log ||= get_logger( LOG_TEMPLATE );
    my $date = _create_date_object( $date_string, $format );
    unless ( $date ) {
        $log->error( "Cannot parse '$date_string' into valid date" );
        return undef;
    }
    $format ||= '%Y-%m-%d %l:%M %p';
    my $formatted = $date->strftime( $format );
    if ( $params->{fill_nbsp} ) {
        $formatted =~ s|\s|\&nbsp;|g;
    }
    return $formatted;
}


# Put a date into a hash with year, month, day, hour and second as
# keys. If the date is 'today' or 'now' you get back the current time.

sub date_into_object {
    my ( $self, $date_string, $date_format ) = @_;
    return {} unless ( $date_string );
    return _create_date_object( $date_string, $date_format );
}


########################################
# STRING FORMATTING

sub as_boolean {
    my ( $self, $value ) = @_;
    return $value =~ /^(t|true|y|yes|1)$/i
}

sub as_boolean_label {
    my ( $self, $value, $positive, $negative ) = @_;
    my $result = $self->as_boolean( $value );
    if ( $result ) {
        $positive ||= $self->msg( 'global.label.yes' );
    }
    else {
        $negative ||= $self->msg( 'global.label.no' );
    }
    return $result ? $positive : $negative;
}

# Limit $str to $len characters

sub limit_string {
    my ( $self, $str, $len ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    $log->is_debug &&
        $log->debug( "limiting '$str' to '$len' characters" );
    return $str if ( length $str <= $len );
    return substr( $str, 0, $len ) . '...';
}


# Quote something for use in generated Javascript code

sub javascript_quote {
    my ( $self, $string ) = @_;
    $string =~ s/\'/\\\'/g;
    return $string;
}

# Limit $text to $num_sentences sentences (works?)

sub limit_sentences {
    my ( $self, $text, $num_sentences ) = @_;
    return undef if ( ! $text );
    require Text::Sentence;
    $num_sentences ||= 3;
    my @sentences = Text::Sentence::split_sentences( $text );
    my $orig_num_sentences = scalar @sentences;
    $sentences[ $num_sentences - 1 ] .= ' ...'  if ( $orig_num_sentences > $num_sentences );
    return join ' ', @sentences[ 0 .. ( $num_sentences - 1 ) ];
}


# Format $num as a percent to $places decimal places

sub percent_format {
    my ( $self, $num, $places ) = @_;
    $places = 2 unless ( defined $places );
    return sprintf( "%5.${places}f%%", $num * 100 );
}


# Format $num as US currency -- egads, who wants to mess with Locales?!

sub money_format {
    my ( $self, $num, $places ) = @_;
    $places = 2 unless ( defined $places );
    return sprintf( "\$%5.${places}f", $num );
}


sub byte_format {
    my ( $self, $num ) = @_;
    my @formats = ( '%s bytes', '%5.1f KB', '%5.1f MB', '%5.1f GB' );
    my $idx = 0;
    my $max = scalar @formats - 1;
    while ( $num > 1024 and $idx < $max ) {
        $num /= 1024;
        $idx++;
    }
    my $fmt = sprintf( $formats[ $idx ], $num );
    $fmt =~ s/^\s+//;
    return $fmt;
}


# Return the arg sent to ucfirst

sub uc_first { return ucfirst $_[1] }

sub uc { return uc $_[1] }


# Return an HTML-encoded first argument

sub html_encode {
    return HTML::Entities::encode( $_[1] )
}


# Return an HTML-decoded first argument

sub html_decode {
    return HTML::Entities::decode( $_[1] );
}


# Create a URL, smartly. (The smart part was taken from
# Template::Plugin::URL, and then moved to OI::URL)

my $U = OpenInteract2::URL->new();

sub add_params_to_url {
    my ( $self, $url, $p ) = @_;
    return $U->add_params_to_url( $url, $p );
}

sub make_url {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    $log->is_debug &&
        $log->debug( "Plugin trying to create URL with: ",
                     join( '; ', map { "$_ = $p->{$_}" } keys %{ $p } ) );
    my ( $url_base );
    my $no_escape = $p->{do_not_escape};
    delete $p->{do_not_escape};
    if ( $p->{BASE} ) {
        $url_base = $p->{BASE};
        delete $p->{ $_ } for ( qw( ACTION TASK BASE IMAGE STATIC ) );
        return $U->create( $url_base, $p, $no_escape );
    }
    elsif ( $p->{ACTION} ) {
        my ( $action, $task ) = ( $p->{ACTION}, $p->{TASK} );
        delete $p->{ $_ } for ( qw( ACTION TASK BASE IMAGE STATIC ) );
        return $U->create_from_action( $action, $task, $p, $no_escape );
    }
    elsif ( $p->{IMAGE} ) {
        my $image_url = $p->{IMAGE};
        delete $p->{ $_ } for ( qw( ACTION TASK BASE IMAGE STATIC ) );
        return $U->create_image( $image_url, $p, $no_escape );
    }
    elsif ( $p->{STATIC} ) {
        my $static_url = $p->{STATIC};
        delete $p->{ $_ } for ( qw( ACTION TASK BASE IMAGE STATIC ) );
        return $U->create_static( $static_url, $p, $no_escape );
    }
    else {
        return q{javascript:alert('Incorrect parameters passed to make_url()')};
    }
}


########################################
# DATA RETRIEVAL

# TODO: Figure out how configure this to use a nice API to select only
# certain users (e.g., pass in a group name, group API, beginning of a
# last name, etc..

sub get_users {
    my ( $self ) = @_;
    return eval { CTX->lookup_object( 'user' )
                     ->fetch_iterator({ order => 'login_name' }) };
}


########################################
# OI DISPLAY

# Tell OI (from a page) about the page title

sub page_title {
    my ( $self, $title ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    eval { CTX->controller->add_content_param( title => $title ) };
    if ( $@ ) {
        $log->error( "Failed to set page title: $@" );
    }
    return undef;
}

# Tell OI (from a page) you want to use a different 'main' template

sub use_main_template {
    my ( $self, $template_name ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    eval { CTX->controller->main_template( $template_name ) };
    if ( $@ ) {
        $log->error( "Cannot set main template '$template_name' in ",
                     "controller: $@" );
    }
    else {
        $log->is_info &&
            $log->info( "Set main template to '$template_name'" );
    }
    return undef;
}


# This should return the main content template used. This isn't
# documented yet because while it probably works 90% of the time, I'm
# not sure about the other 10%.

sub content_template {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    my $template = eval { CTX->controller->main_template };
    if ( $@ ) {
        $log->error( "Cannot get main_template from controller: $@" );
    }
    return $template;
}


########################################
# PLUGIN PROPERTIES

sub security_level {
    return $SECURITY_CONSTANTS{level};
}


sub security_scope {
    return $SECURITY_CONSTANTS{scope};
}


sub action {
    my ( $self ) = @_;
    return $self->{_CONTEXT}->stash()->get( 'ACTION' );
}

# Needed so we put lists in proper form for TT

sub action_param {
    my ( $self, $param_name ) = @_;
    my $action = $self->action;
    return undef unless ( $action );
    my @params = $action->param( $param_name );
    my $num_params = scalar @params;
    if ( $num_params < 2 ) {
        return $params[0];
    }
    return [ @params ];
}

sub param {
    my ( $self, $param_name ) = @_;
    return CTX->request->param( $param_name );
}

sub request {
    return CTX->request;
}

sub response {
    return CTX->response;
}

sub controller {
    return CTX->controller;
}

sub login {
    my ( $self ) = @_;
    return CTX->request->auth_user();
}


sub logged_in {
    my ( $self ) = @_;
    return CTX->request->auth_is_logged_in();
}


sub login_group {
    my ( $self ) = @_;
    return CTX->request->auth_group();
}


sub is_admin {
    my ( $self ) = @_;
    return CTX->request->auth_is_admin();
}


sub return_url {
    my ( $self ) = @_;
    return CTX->response->return_url() || CTX->request->url_absolute();
}


sub theme_properties {
    my ( $self ) = @_;
    my $request = CTX->request;
    my $values = $request->theme_values;
    unless ( $values ) {
        $values = $request->theme_values( $request->theme->all_values );
    }
    return $values;
}


# Don't return undef when things go sour or the caller will get a
# nasty surprise when he tries to use it

sub theme_fetch {
    my ( $self, $theme_spec, $params ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    unless ( $theme_spec ) {
        $log->warn( "No theme spec given to fetch" );
        return $self->theme_properties;
    }
    my ( $theme_id );
    if ( $theme_spec =~ /^[\d\s]+$/ ) {
        $theme_id = $theme_spec;
    }
    else {
        $theme_id = CTX->lookup_default_object_id( $theme_spec );
    }
    unless ( $theme_id ) {
        $log->error( "Could not fetch theme given spec of '$theme_spec': ",
                     "it doesn't look like an object ID and no matching ",
                     "no matching name found in 'default_objects' server ",
                     "configuration" );
        return $self->theme_properties;
    }
    my $new_theme = eval {
        CTX->lookup_object( 'theme' )->fetch( $theme_id )
    };
    if ( $@ ) {
        $log->error( "Error fetching theme with ID '$theme_id': $@" );
        return $self->theme_properties;
    }
    unless ( $new_theme ) {
        $log->warn( "No theme with ID '$theme_id' exists" );
        return $self->theme_properties;
    }

    # New theme looks good, fill it up...
    my $new_props = $new_theme->all_values;

    # ... and set for rest of request if specified
    if ( $params->{set_for_request} eq 'yes' ) {
        CTX->request->theme( $new_theme );
    }

    return $new_props;
}


sub theme {
    return theme_properties( @_ );
}


sub session {
    my ( $self ) = @_;
    CTX->request->session();
}

# TODO: Should we make this available?

sub server_config {
    return CTX->server_config;
}


########################################
# DEPRECATED

# use action_execute instead

sub comp {
    my ( $self, $name, @params ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    $log->warn( "Deprecated plugin method comp() called: use ",
                "action_execute() instead" );
    return $self->action_execute( $name, @params );
}


1;

__END__

=head1 NAME

OpenInteract2::TT2::Plugin - Custom OpenInteract functionality in templates

=head1 SYNOPSIS

 # Create the TT object with the OI plugin
 
 my $template = Template->new(
                       PLUGINS => { OI => 'OpenInteract2::TT2::Plugin' }, ... );
 my ( $output );
 $template->process( 'package::template', \%params, \$output );

 # In the template (brief examples, see below for more)
 
 Here is what the plugin can do:
   <ul><li>[% OI.show_all_actions.join( "\n   <li>" ) -%]</ul>
 
 Here are plugins available to you:
   [% OI.show_all_plugins.keys.sort.join( ', ' ) %]
 
 Here are all the parameters passed to the request:
   [% OI.request_param.sort.join( ', ' ) %]
 
 And the value of a particular parameter:
   last name: [% OI.request_param( 'last_name' ) %]
 
 [% OI.action_execute( 'error_display', error_msg = error_msg ) -%]
 
 # Note that you can also use the 'MSG' function
 [% OI.msg( 'mypage.intro', OI.login.full_name ) %]
 
 # Note that you can also use the 'LH' variable
 [% mh = OI.msg_handle %]
 [% mh.maketext( 'mypage.intro', OI.login.full_name ) %]
 [% mh.maketext( 'mypage.learnmore' ) %]
 
 [% OI.box_add( 'contact_tools_box', title  = 'Contact Tools',
                                     weight = 2 ) -%]
 
 [% object_info = OI.object_description( object ) %]
 This is a [% object_info.name %] object.
 
 Is the object in the class?
    [% OI.class_isa( object, 'SPOPS::DBI' ) ? 'yes' : 'no' %]
 
 Is the SPOPS object writable?
    [% IF OI.can_write( object ) %]You're special![% END %]
 
 [% action = OI.action %]
 Action that called this template: [% action.name %]
 Security for action:
     [% action.security_level %] found,
     [% action.security_required %] required
 
 Properties of action:
 [% action_prop = action.properties %]
 [% FOREACH key = action_prop.keys %]
   [% key %] = [% action_prop.$key %]
 [% END %]
 
 Parameters of action:
 [% action_param = action.param %]
 [% FOREACH key = action_param.keys %]
   [% key %] = [% action_param.$key %]
 [% END %]
 
 Today is [% OI.date_format( 'now', '%Y-%m-%d %l:%M %p' ) %] the
 [% OI.date_format( 'now', '%j' ) %] day of the year
 
 [% d = OI.date_into_object( object.updated_on, '%Y-%m-%d' ) -%]
 [% OI.action_execute( 'date_select', month_value  = d.month,
                                      day_value    = d.day,
                                      year_value   = d.year, blank = 1,
                                      field_prefix = 'updated_on' ) -%]
 
 [% INCLUDE form_checkbox( name        = 'is_in_print',
                           value       = 'TRUE',
                           is_checked  = OI.as_boolean( book.is_in_print ) ) -%]
 
 Is in print? [% OI.as_boolean_label( book.is_in_print ) %]
 
 Is in print? [% OI.as_boolean_label( book.is_in_print, 'You betcha', 'No way' ) %]
 
 [% OI.limit_string( object.description, 30 ) %]
 
 var person_last_name = '[% OI.javascript_quote( person.last_name ) %]';
 
 [% OI.limit_sentences( news.news_item, 3 ) %]
 
 [% score = grade.score / test.total %]
 Your grade is: [% OI.percent_format( score ) %]
 
 You have [% OI.money_format( account.balance ) %] left to spend.
 
 Hello [% OI.uc_first( person.first_name ) %]
 
 You are important so I must speak to you loudly [% OI.uc( person.last_name ) %]
 
 <textarea name="news_item">[% OI.html_encode( news.news_item ) %]</textarea>
 
 Item: [% OI.html_decode( news.news_item ) %]
 
 # Add parameters to an existing URL
 [% display_no_template_url = OI.add_params_to_url( my_path, no_template = 'yes' ) %]
 <a href="[% display_no_template_url %]">View Printable</a>

 # Works, but not as useful...
 [% edit_url = OI.make_url( BASE = '/User/show/', user_id = OI.login.user_id,
                            edit = 1, show_all = 'yes' ) %]
 <a href="[% edit_url %]">Edit your information</a>
 
 # Preferred way to generate URLs for actions
 [% edit_url = OI.make_url( ACTION = 'user', TASK = 'show',
                            user_id = OI.login.user_id,
                            edit = 1, show_all = 'yes' ) %]
 <a href="[% edit_url %]">Edit your information</a>
 
 [% image_url = OI.make_url( IMAGE = '/images/foo.gif' ) %]
 <img src="[% image_url %]"> Take a look at that!
 
 [% static_url = OI.make_url( STATIC = '/generated/report-q1-2003.pdf' ) %]
 <a href="[% static_url %]">Latest report</a>
 
 [% theme = OI.theme_properties %]
 Background color of page: [% theme.bgcolor %]
 
 [% new_theme = OI.theme_fetch( 5 ) %]
 Background color of page from other theme: [% new_theme.bgcolor %]
 
 [% IF OI.logged_in -%]
 Hello [% OI.login.full_name %]. 
   Your groups are: [% OI.login_group.join( ', ' ) -%]
 [% ELSE -%]
 You are not logged in.
 [% END -%]
 
 Your last search: [% OI.session.latest_search %]
 
 <a href="[% OI.return_url %]">Refresh</a>
  
 [% IF object.tmp_security_level >= OI.security_level.write -%]
   you can edit this object!
 [% END %]

=head1 DESCRIPTION

This implements a Template Toolkit Plugin. For more information about
plugins, see L<Template::Manual::Plugins|Template::Manual::Plugins>.

Normally a plugin is instantiated like this:

 [% USE OI %]
 [% object_info = OI.object_description( object ) %]

But since this plugin will probably be used quite a bit by
OpenInteract template authors, it is always already created for you if
you use the
L<OpenInteract2::ContentGenerator::TT2Process|OpenInteract2::ContentGenerator::TT2Process>
module.

It can be used outside of the normal OpenInteract processing by doing
something like:

    my $template = Template->new(
                      PLUGINS => { OI => 'OpenInteract2::TT2::Plugin' }
                   );
    $template->process( $text, { OI => $template->context->plugin( 'OI' ) } )
         || die "Cannot process template! ", $template->error();

This is done for you in
L<OpenInteract2::ContentGenerator::TT2Process|OpenInteract2::ContentGenerator::TT2Process> so
you can simply do:

    my $website_dir = $ENV{OPENINTERACT2};
    my $ctx = OpenInteract2::Context->create({ website_dir => $website_dir });
    my $generator = CTX->content_generator( 'TT' );
    print $generator->generate( {}, { foo => 'bar' },
                                { name => 'mypkg::mytemplate' });

And everything works. (See
L<OpenInteract2::ContentGenerator::TT2Process|OpenInteract2::ContentGenerator::TT2Process> for
more information.)

Most of the interesting information is in L<METHODS AND PROPERTIES>.

=head1 METHODS AND PROPERTIES

The following OpenInteract properties and methods are available
through this plugin, so this describes how you can interface with
OpenInteract from a template.

=head2 METHODS

B<request_param( [ $name ] )>

TODO

B<msg( $key, [ $param1, $param2, ... ] )>

TODO

B<msg_handle>

TODO

B<action_param( $name )>

Returns the value(s) for the parameter C<$name> in the action that
spawned this template process. If no action spawned the process
returns C<undef>.

The benefit this gives you above calling C<param> on the return value
for C<action()> is that multivalued parameters are returned in an
arrayref rather than an array. Zero or one values are returned by
themselves, everything else in an arrayref.

Example:

 [% FOREACH error_msg = OI.action_param( 'error_msg' ) -%]
   Another error: [% error_msg %]
 [% END %]

B<action_execute( $name, \%params )>

I<NOTE>: This replaces the C<comp()> method from OI 1.x

Creates an action of name C<$name> and returns the output of
C<execute>. All the normal action rules apply.

Example:

 [% OI.action_execute( 'error_display', error_msg = error_msg ) %]

See L<OpenInteract2::Action|OpenInteract2::Action> for
more information about actions.

B<box_add( $box, \%params )>

Adds a box to the list of boxes that will be processed by the 'boxes'
component. (This is usually found in the 'base_main' template for your
site.) You can add just a simple box name or parameters for the box as
well. See the 'base_box' package for more information about boxes.

Examples:

 [% OI.box_add( 'object_modify_box', object = news ) %]

 [% OI.box_add( 'object_modify_box', object = news, title = 'Change it!',
                                     weight = 1 ) %]

B<object_description( $spops_object )>

Returns a hashref with metadata about any SPOPS object. Keys of the
hashref are C<class>, C<object_id> (and C<oid>), C<id_field>, C<name>,
C<title>, C<url>, C<url_edit>. (See L<SPOPS|SPOPS> for details about
what is returned.)

 [% desc = OI.object_description( news ) %]
 [% IF news.tmp_security_level >= OI.security_level.write %]
   <a href="[% desc.url_edit %]">Edit</a>
 [% END %]

B<class_isa( $class|$object, $isa_class )>

Returns a true value if C<$class> or C<$object> is a C<$isa_class>.

Example:

 [% IF OI.class_isa( news, 'MySite::NewsCustom' ) %]
   [% news.display_custom_news() %]
 [% ELSE %]
   [% news.display_news() %]
 [% END %]

(Of course, this is a bad example since you would deal with this
through your normal OO methods.)

B<can_write( $spops_object )>

Returns true if the object is writeable by the current user, false if
not.

B<action()>

Returns the L<OpenInteract2::Action|OpenInteract2::Action> object that
called this template. If the template was called from a component or
using the C<generate_content()> method of the action object.

B<date_format( $date_string[, $format ] )>

Formats the date from string C<$string> using the strftime format
C<$format>. If you do not supply C<$format>, a default of

 %Y-%m-%e %l:%M %p

is used.

Examples:

  [% mydate = '2000-5-1 5:45 PM' %]
  Date [% mydate %] is day number [% OI.date_format( mydate, '%j' ) %] of the year.

displays:

  Date 2000-5-1 5:45 PM is day number 122 of the year.

and

  Today is day number [% OI.date_format( 'now', '%j' ) %] of the year.

displays:

  Today is day number 206 of the year.

For reference, here are supported C<strftime> B<formatting> sequences
(cribbed from L<DateTime|DateTime>):

  %%      PERCENT
  %a      day of the week abbr
  %A      day of the week
  %b      month abbr
  %B      month
  %C      century number (0-99)
  %d      numeric day of the month, zero padded (01..31)
  %D      MM/DD/YY (confusing for everybody but USA...)
  %e      same as %d, space padded ( 1..31)
  %F      %Y-%m-%d (ISO 8601 date)
  %g      year corresponding to ISO week number w/o century (0-99)
  %G      year corresponding to ISO week number
  %h      same as %b
  %H      hour, 24 hour clock, zero padded (00-23)
  %I      hour, 12 hour clock, zero padded (01-12)
  %j      day of the year (001-366)
  %k      hour, 24 hour clock, space padded ( 0-23)
  %k      hour, 12 hour clock, space padded ( 1-12)
  %m      month number (01-12)
  %M      minute (00-59)
  %n      NEWLINE
  %N      nanoseconds (%[3|6|9]N gives 3, 6, or 9 digits)
  %p      AM or PM (or locale equivalent)
  %P      %p in lowercase
  %r      time format: 09:05:57 PM (%I:%M:%S %p)
  %R      time format: 21:05 (%H:%M)
  %s      seconds since the Epoch, UCT
  %S      seconds (00-60)
  %t      TAB
  %T      time format: 21:05:57 (%H:%M:%S)
  %u      weekday number, Monday = 1 (1-7)
  %U      week number, Sunday as first day of week (00-53)
  %V      week number, ISO 8601 (01-53)
  %w      weekday number, Sunday = 0 (0-6)
  %W      week number, Monday as first day of week (00-53)
  %y      year (2 digits)
  %Y      year (4 digits)
  %z      timezone in ISO 8601 format (+0500, -0400, etc.)
  %Z      timezone brief (PST, EST, etc.)

B<date_into_object( $date_string, [ $date_format ] )>

Takes apart C<$date_string> and returns a L<DateTime|DateTime>
object. You can call a number of methods on this object to get
individual pieces of a date. (See the docs for
L<DateTime|DateTime> for a complete list.)

Note that you can pass 'now' or 'today' as C<$date_string> and get the
current time.

Example:

  [% mydate = '2000-5-1 5:45 PM' %]
  [% dt = OI.date_into_object( mydate, '%Y-%m-%d %I:%M %p' ) %]
  Date: [% mydate %]
  Year: [% dt.year %]
  Month Num/Name: [% dt.month %] / [% dt.month_name %]
  Day/Name/of Year:  [% dt.day_of_month %] / [% dt.day_name %] / [% dt.day_of_year %]
  Hour: [% dt.hour %]
  Minute: [% dt.minute %]

displays:

  Date: 2000-5-1 5:45 PM
  Year: 2000
  Month Num/Name: 5 / May
  Day/Name/of Year:  1 / Monday / 121
  Hour: 5
  Minute: 45

For reference, here are supported C<strptime> B<parsing> sequences
(cribbed from
L<DateTime::Format::Strptime|DateTime::Format::Strptime>):

  %%      PERCENT
  %a      day of the week abbr
  %A      day of the week
  %b      month abbr
  %B      month
  %C      century number (0-99)
  %d      numeric day of the month (1..31)
  %D      MM/DD/YY (confusing for everybody but USA...)
  %e      same as %d
  %g      year corresponding to ISO week number w/o century (0-99)
  %G      year corresponding to ISO week number
  %h      same as %b
  %H      hour, 24 hour clock (0-23)
  %I      hour, 12 hour clock (1-12)
  %j      day of the year (1-366)
  %m      month number (1-12)
  %M      minute (0-59)
  %n      whitespace
  %N      nanoseconds
  %p      AM or PM (or locale equivalent)
  %q      time zone name from Olsen database
  %r      time format: 09:05:57 PM (%I:%M:%S %p)
  %R      time format: 21:05 (%H:%M)
  %s      seconds since the Epoch, UCT
  %S      seconds (0-60)
  %t      whitespace
  %T      time format: 21:05:57 (%H:%M:%S)
  %u      weekday number, Monday = 1 (1-7)
  %U      week number, Sunday as first day of week (0-53)
  %w      weekday number, Sunday = 0 (0-6)
  %W      week number, Monday as first day of week (0-53)
  %y      year (2 digits)
  %Y      year (4 digits)
  %z      timezone in ISO 8601 format (+0500, -0400, etc.)
  %Z      timezone brief (PST, EST, etc.)

B<as_boolean( $value )>

Returns 1 if C<$value> any one of the following, in any case: 't',
'true', 'y', 'yes', or '1'. Otherwise returns 0.

B<as_boolean_label( $value, [ $yes_label ], [ $no_label ] )>

If C<$value> is a value that evaluates to 1 from C<$as_boolean()> we
return C<$yes_label> if specified, or the localized version of
'global.label.yes'; if it evaluates to '0' we return C<$no_label> if
specified, or the localized version of 'global.label.no'.

B<limit_string( $string, $length )>

Returns a string of max length C<$length>. If the function removes
information from the string, it appends '...' to the string. Note that
we currently do not try to be nice with word endings.

Example:

 [% string = 'This is a really long news title and we have strict space constraints' %]
 [% OI.limit_string( string, 25 ) %]

displays:

 This is a really long new...

B<javascript_quote( $string )>

Performs necessary quoting to use C<$string> as Javascript
code. Currently this only involves escaping the "'" character, but it
can easily expand as necessary.

Example:

 [% book_title = "it's nothing" %]
 var newArray = new Array( '[% OI.javascript_quote( book_title ) %]' );

displays:

 var newArray = new Array( 'it\'s nothing' );

We could probably use a filter for this.

B<limit_sentences( $string, $num_sentences )>

Limits C<$string> to C<$num_sentences> sentences. If the resulting
text is different -- if the function actually removes one or more
sentences -- we append '...' to the resulting text.

Example:

  [% sentence_text = 'This is the first. This is the second. This is the third. This is the fourth.' %]
  Sentences: [% OI.limit_sentences( sentence_text, 2 ) %]

displays:

  Sentences: This is the first. This is the second. ...

B<percent_format( $number[, $places ] )>

Formats C<$number> as a percentage to C<$places>. If not specified
C<$places> defaults to '2'.

Example:

 [% grade = 44 / 66 %]
 Grade: [% OI.percent_format( grade, 2 ) %]

displays:

 Grade: 66.67%

B<money_format( $number[, $places ] )>

Displays C<$number> as US dollars to C<$places>. If not specified,
C<$places> defaults to 2.

Example:

  [% monthly_salary = 3000 %]
  [% yearly_salary = monthly_salary * 12 %]
  Your yearly salary: [% OI.money_format( yearly_salary, 0 ) %]

displays:

  Your yearly salary: $36000

B<byte_format( $number )>

Displays C<$number> as a number of bytes. If the number is less than
1024 it displays directly, between 1024 and 1024**2 as KB, between
1024**2 and 1024**3 as MB and greater than that as GB.

Example:

 The file sizes are:
   [% OI.byte_format( 989 ) %]
   [% OI.byte_format( 2589 ) %]
   [% OI.byte_format( 9019 ) %]
   [% OI.byte_format( 2920451 ) %]
   [% OI.byte_format( 920294857 ) %]
   [% OI.byte_format( 3211920294857 ) %]

displays:

 The file sizes are:
   989 bytes
   2.5 KB
   8.8 KB
   2.8 MB
   877.7 MB
   2991.3 GB

B<uc_first( $text )>

Simply upper-case the first letter of the text passed in. Note that we
do not do every word, just the first.

Example:

  [% first_name = 'yahoo' %]
  Hi there, [% OI.uc_first( first_name ) %]

displays:

  Hi there, Yahoo

B<html_encode( $text )>

Encodes C<$text> so that it can be displayed in a TEXTAREA or in other
widgets.

Example:

 [% news_item = "<p>This is the first paragraph</p>" %]
 <textarea name="news_item" cols="50" rows="4"
           wrap="virtual">[% OI.html_encode( news_item ) %]</textarea>

displays:

 <textarea name="news_item" cols="50" rows="4"
           wrap="virtual">&lt;p&gt;This is the first paragraph&lt;/p&gt;</textarea>

B<html_decode( $text )>

Decodes C<$text> with HTML entities to be displayed normally.

Example:

 [% news_item = '&lt;p&gt;This is the first paragraph&lt;/p&gt;' %]
 [% OI.html_decode( news_item ) %]

displays:

 <p>This is the first paragraph</p>

B<add_params_to_url( $url, \%params )>

Delegates to L<OpenInteract2::URL> for C<add_params_to_url()> which
just adds the key/value pairs in C<\%params> to C<$url>, adding a
query separator if necessary and doing any escaping of the
paramters.. Note that C<$url> is already presumed to be contextualized
(under the correct deployment context) and will not be escaped.

B<make_url( \%params )>

Creates a URL given a number of parameters, taking care to perform any
necessary transformations. See the C<create()>, C<create_image()> and
C<create_static()> methods of L<OpenInteract2::URL|OpenInteract2::URL>
for what this means.

Parameters:

All parameters except those listed below are assumed to be used as GET
keys and values and will be appended to the URL appropriately.

To specify a URL to an OI resource you can use one of two methods:

=over 4

=item *

B<BASE>: The base for the URL. This is normally what gets transformed
with a location prepended to it or a session tag appended (or
whatever). (B<Compatibility Note>: In OI 1.x this was 'base' instead.)

=back

Examples:

 [% user_show_url = OI.make_url( BASE = '/User/show/',
                                 user_id = user.user_id ) %]
 <a href="[% user_show_url %]">blah</a>

displays (when under the normal location of '/'):

 <a href="/User/show/?user_id=5">blah</a>

displays (when under a different location '/oi'):

 <a href="/oi/User/show/?user_id=5">blah</a>

The second method, preferred for generating URLs to actions, is a
combination of:

=over 4

=item *

B<ACTION>: The action to which the task and parameters are being
sent. This should exist in the action table -- if it doesn't no URL is
returned.

=item *

B<TASK>: The optional task in the action to which the parameters are
being sent. If unspecified the URL will wind up going to the default
task for the action.

=back

Examples, assuming that the 'user' task is mapped to the '/User'
URLspace.

 [% user_show_url = OI.make_url( ACTION = 'user', TASK = 'show',
                                 user_id = user.user_id ) %]
 <a href="[% user_show_url %]">blah</a>

displays (when under the normal location of '/'):

 <a href="/User/show/?user_id=5">blah</a>

displays (when under a different location '/oi'):

 <a href="/oi/User/show/?user_id=5">blah</a>

You can also create URLs for images and static resources:

=over 4

=item *

B<IMAGE>: Specifies the image URL to which the image deployment
context gets prepended.

=item *

B<STATIC>: Specifies the static URL to which the static deployment
context gets prepended.

=back

If you do not specify either C<BASE> or C<ACTION> and C<TASK>, a
javascript URL is returned that alerts you to your error. (Note: this
may change...)

B<page_title( $title )>

Set the HTML title for the top-level page. This isn't used as often as
other directives, but like C<use_main_template> below it can come in
very handy.

Example:

 [% username = OI.login.full_name;
    OI.page_title( "Personalized Astrology Reading for $username"  ); %]

B<use_main_template( $template_name )>

Tell OpenInteract to use a particular main template. The
C<$template_name> should be in 'package::name' format.

Example:

  [% OI.use_main_template( 'mypkg::main' ) -%]

B<theme_fetch( $new_theme_spec, \%params )>

Retrieves the properties for theme C<$new_theme_spec>, which can be an
ID (normal) or a name listed in the 'default_objects' of your server
configuration. If the latter we'll use the ID associated with that
name.

If the key C<set_for_request> is set to 'yes' in C<\%params> then this
new theme will be used for the remainder of the request. This includes
the main template along with all graphical elements.

Returns: hashref with all properties of the given theme.

Examples:

 [% new_theme = OI.theme_fetch( 5 ) %]
 Background color of page from other theme: [% new_theme.bgcolor %]
 
 [% new_theme = OI.theme_fetch( 5, set_for_request = 'yes' ) %]
 Background color of page from other theme: [% new_theme.bgcolor %]
 Hey, the new theme is now set for the rest of the request!

=head2 PROPERTIES

B<theme_properties()>

A hashref with all the properties of The current theme. You will
probably use this a lot.

Example:

 [% theme = OI.theme_properties %]
 <tr bgcolor="[% theme.head_bgcolor %]">

The exact properties in the theme depend on the theme. See the
'base_theme' package for more information.

B<login()>

The user object representing the user who is currently logged in.

Example:

 [% login = OI.login %]
 <p>Hi [% login.full_name %]! Anything new?</p>

B<login_group()>

An arrayref of groups the currently logged-in user belongs to.

Example:

 [% login_group = OI.login_group %]
 <p>You are a member of groups:
 [% FOREACH group = login_group %]
   [% th.bullet %] [% group.name %]<br>
 [% END %]
 </p>

B<logged_in()>

True/false determining whether the user is logged in or not.

Example:

 [% IF OI.logged_in %]
   <p>You are very special, logged-in user!</p>
 [% END %]

B<is_admin()>

True/false depending on whether the user is an administrator. The
definition of 'is an administrator' depends on the authentication
class being used -- by default it means that the user is the superuser
or a member of the 'site admin' group. But you can modify this based
on your needs, and make the result available to all templates with
this property.

Example:

 [% IF OI.is_admin %]
   <p>You are an administrator -- you have the power! It feels great,
   eh?</p>
 [% END %]

B<session()>

Contains all information currently held in the session. Note that
other handlers may during the request process have modified the
session. Therefore, what is in this variable is not guaranteed to be
already saved in the database. However, as the request progresses
OpenInteract will sync up any changes to the session database.

Note that this information is B<read-only>. You will not get an error
if you try to set or change a value from the template, but the
information will persist only for that template.

Example:

 [% session = OI.session %]
 <p>Number of items in your shopping cart:
    [% session.num_shopping_cart_items %]</p>

B<return_url()>

What the 'return url' is currently set to. The return url is what we
come back to if we have to do something like logout.

 <a href="[% OI.return_url %]">Logout and return to this page</a>

Note that this should be an B<absolute URL> -- you should be able to
plug it directly into a tag without worrying about the server context.

B<security_level()>

A hashref with keys of 'none', 'read', and 'write' which gives you the
value used by the system to represent the security levels.

Example:

 [% IF obj.tmp_security_level < OI.security_level.write %]
  ... do stuff ...
 [% END %]

B<security_scope()>

A hashref with the keys of 'user', 'group' and 'world' which gives you
the value used by the system to represent the security scopes. This
will rarely be used but exists for completeness with
C<security_level>.

 [% security_scope = OI.security_scope %]
 [% FOREACH scope = security_scope.keys %]
   OI defines [% scope %] as [% security_scope.$scope %]
 [% END %]

B<server_config()>

Returns the server configuration object (or hashref) -- whatever is
returned by calling in normal code:

 CTX->server_config;
 
 The ID of the site admin group is:
  [% OI.server_config.default_objects.site_admin_group %]

=head2 REFLECTION

B<show_all_actions()>

You can get a listing of all methods available from the plugin by
doing:

 [% actions = OI.show_all_actions -%]
 [% actions.join( "\n" ) %]

B<show_all_plugins()>

Returns a hashref of plugins initialized by OpenInteract and available
in the template environment. Keys are the plugin names, values the
plugin classes:

 Plugins available:
 <ul>
   [% plugins = OI.show_all_plugins %] 
   [% FOREACH plugin_name = plugins.keys.sort %]
   <li>[% plugin_name %]: [% plugins.$plugin_name %]
   [% END %]
 </ul>

=head1 CUSTOM PLUGINS

Package authors can create their own plugins that are available to
template authors just like the 'OI' plugin. Read
L<OpenInteract2::Manual::Templates|OpenInteract2::Manual::Templates>
for more information.

=head1 SEE ALSO

L<Template::Plugins|Template::Plugins>

L<Template::Plugin::URL|Template::Plugin::URL> for borrowed code

Slashcode (http://www.slashcode.com) for inspiration

L<OpenInteract2::Manual::Templates|OpenInteract2::Manual::Templates>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
