package OpenInteract2::Controller::ManageTemplates;

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Controller::MangeTemplates::VERSION  = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub init_templates {
    my ( $self ) = @_;
    $self->{_template_used} = [];
}

########################################
# TEMPLATES USED

sub add_template_used {
    my ( $self, $name ) = @_;
    $log ||= get_logger( LOG_ACTION );
    $log->is_debug &&
        $log->debug( "Adding template [$name] list of those used" );
    return push @{ $self->{_template_used} }, $name;
}

sub get_templates_used {
    my ( $self ) = @_;
    return $self->{_template_used};
}

1;

__END__

=head1 NAME

OpenInteract2::Controller::ManageTemplates - Mixin methods for managing templates

=head1 SYNOPSIS

 use base qw( OpenInteract2::Controller::ManageTemplates );

=head1 DESCRIPTION

If a controller wants to keep track of templates used during a request
it should add this class to its ISA.

=head1 METHODS

B<init_templates()>

Initializes the internal variable for tracking templates. Should be called
from the C<init()> method of the implementing class.

B<add_template_used( $template_name )>

Adds C<$template_name> to the list of those used.

B<get_templates_used()>

Returns an arrayref of all template names used in they order they were
added.

=head1 SEE ALSO

L<OpenInteract2::Controller|OpenInteract2::Controller>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
