package OpenInteract2::Action::TemplateOnly;

# $Id: TemplateOnly.pm,v 1.7 2005/03/17 14:57:59 sjn Exp $

use strict;
use base qw( OpenInteract2::Action );

$OpenInteract2::Action::TemplateOnly::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub _find_task {
    return 'execute_template';
}

sub execute_template {
    my ( $self ) = @_;
    my $template = $self->param( 'template' );
    return $self->generate_content( {}, { name => $template } );
}

1;

__END__

=head1 NAME

OpenInteract2::Action::TemplateOnly - Base class for template-only actions

=head1 SYNOPSIS

 # Declare your action with the necessary action_type...
 
 [login_box]
 name        = login_box
 template    = base_box::login_box
 weight      = 1
 title       = Login
 is_secure   = no
 action_type = template_only
 
 # In code, find the action...
 
 my $action = CTX->lookup_action( 'login_box' );
 
 # And execute as normal!
 
 my $box_content = $action->execute;

 # You can also instantiate the action directly
 my $action = CTX->lookup_action( 'template_only' );
 
 # ...set the parameter
 $action->param( template => 'base_box::login_box' );
 
 # ...and execute as normal
 return $action->execute;

=head1 DESCRIPTION

This class implements the B<template_only> action type. What this
means is that your action declaration can specify that it is of this
type and most of the work is done for you.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
