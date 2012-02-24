# This OpenInteract2 file was generated
#   by:    [% invocation %]
#   on:    [% date %]
#   from:  [% source_template %]
#   using: OpenInteract2 version [% oi2_version %]

package OpenInteract2::Action::[% class_name %];

use strict;

use base qw(
    OpenInteract2::Action::CommonAdd
    OpenInteract2::Action::CommonDisplay
    OpenInteract2::Action::CommonRemove
    OpenInteract2::Action::CommonSearch
    OpenInteract2::Action::CommonUpdate
);

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

# It's always nice to let CVS deal with this
$OpenInteract2::Action::[% class_name %]::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

########################################
# DISPLAY

# customize what parameters get sent to 'display.tmpl'
# More info: see OpenInteract2::Action::CommonDisplay

sub _display_customize {
    my ( $self, $template_params ) = @_;
}


########################################
# ADD

# customize what parameters get sent to 'form.tmpl' on an add
# More info: see OpenInteract2::Action::CommonAdd

sub _display_add_customize {
    my ( $self, $template_params ) = @_;
}

# customize what occurs when adding an object, including validation
# More info: see OpenInteract2::Action::CommonAdd

sub _add_customize {
    my ( $self, $object, $save_options ) = @_;
}

# perform any actions after the add has occurred
# More info: see OpenInteract2::Action::CommonAdd

sub _add_post_action {
    my ( $self, $object ) = @_;
}


########################################
# UPDATE

# customize what parameters get sent to 'form.tmpl' on an update
# More info: see OpenInteract2::Action::CommonUpdate

sub _display_form_customize {
    my ( $self, $template_params ) = @_;
}

# customize what occurs when updating an object, including validation;
# the hashref $old_data is the object's old data for comparison
# More info: see OpenInteract2::Action::CommonUpdate

sub _update_customize {
    my ( $self, $object, $old_data, $save_options ) = @_;
}

# perform any actions after the add has occurred; the hashref
# $old_data is the object's old data for comparison
# More info: see OpenInteract2::Action::CommonUpdate

sub _update_post_action {
    my ( $self, $object, $old_data ) = @_;
}


########################################
# REMOVE

# perform any actions before the remove has occurred; you'll find the
# object we're about to remove in:
#   $self->param( 'c_object' );
# More info: see OpenInteract2::Action::CommonRemove

sub _remove_customize {
    my ( $self ) = @_;
}


########################################
# SEARCH


# modify template parameters sent to 'search_form.tmpl'
# More info: see OpenInteract2::Action::CommonSearch

sub _search_form_customize {
    my ( $self, $template_params ) = @_;
}

# modify the query criteria before we translate them to SQL
# More info: see OpenInteract2::Action::CommonSearch

sub _search_criteria_customize {
    my ( $self ) = @_;
}

# modify the query pieces before we run the query
# More info: see OpenInteract2::Action::CommonSearch

sub _search_query_customize {
    my ( $self ) = @_;
}

# any parameters you return as a hashref get passed to the final
# SPOPS::DBI->fetch_iterator() call
# More info: see OpenInteract2::Action::CommonSearch

sub _search_additonal_params {
    my ( $self ) = @_;
}

# modify template parameters sent to 'search_results.tmpl'
# More info: see OpenInteract2::Action::CommonSearch

sub _search_customize {
    my ( $self, $template_params ) = @_;
}

1;
