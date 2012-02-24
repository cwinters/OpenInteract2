package OpenInteract2::Action::TemplatesUsedBox;

# $Id: TemplatesUsedBox.pm,v 1.12 2005/03/18 04:09:45 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Action::TemplatesUsedBox::VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub handler {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );
    my $controller = CTX->controller;
    unless ( $controller->isa( 'OpenInteract2::Controller::ManageTemplates' ) ) {
        $log->error( "Controller is not setup to handle templates; it is of type ",
                     "'", ref( $controller ), "' which should have ",
                     "OpenInteract2::Controller::ManageTemplates in its \@ISA" );
        return $self->_msg( 'base_template.error.no_manage' );
    }
    my %tmpl_by_package = ();
    my %tmpl_used       = ();
    my $templates_used = $controller->get_templates_used;
    my $template_class = CTX->lookup_class( 'template' );
    foreach my $template ( @{ $templates_used } ) {
        my ( $package, $name, $full_name );
        if ( ref $template ) {
            ( $package, $name ) = ( $template->{package}, $template->{name} );
            $full_name = $template_class->create_name( $package, $name );
        }
        else {
            ( $package, $name ) = $template_class->parse_name( $template );
            if ( $package and ! $name ) {
                $name    = $package;
                $package = '';
            }
            $full_name = $template;
        }
        next if ( $name eq '_anonymous_' );
        next if ( $tmpl_used{ $package }{ $name } );
        $tmpl_used{ $package }{ $name }++;
        push @{ $tmpl_by_package{ $package } }, {
            name      => $name,
            package   => $package,
            full_name => $full_name
        };
    }
    foreach my $package ( keys %tmpl_by_package ) {
        $tmpl_by_package{ $package } = [ sort { $b->{name} cmp $a->{name} }
                                         @{ $tmpl_by_package{ $package } } ];
    }
    return $self->generate_content(
                    { templates_used => \%tmpl_by_package },
                    { name => 'base_template::templates_used_box' } );
}

1;

__END__

=head1 NAME

OpenInteract2::Action::TemplatesUsedBox -- Generate 'Templates Used' box contents

=head1 SYNOPSIS

 # Add the box to a particular page
 [% OI.box_add( 'templates_used_box' ) %]

=head1 DESCRIPTION

This action supports a box which by default is referenced by the
'templates_used_box' name. This box lists templates used in the
current request. To work properly the controller must have
L<OpenInteract2::Controller::ManageTemplates> in its C<@ISA>. (You can
also create your own action to pull the templates from the
controller.)

This action provides the template a variable 'templates_used' which
holds a hashref of templates keyed by package. Each value is a an
array reference of hash references, each with the keys: 'name',
'package' and 'full_name'. For example, the default template used for
this box you would have:

 base_template => [
       { name      => 'templates_used_box',
         package   => 'base_template',
         full_name => 'base_template::templates_used_box' },
 ],

=head1 SEE ALSO

L<OpenInteract2::Action::Box|OpenInteract2::Action::Box>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
