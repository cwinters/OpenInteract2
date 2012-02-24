package OpenInteract2::Conversion::CommonHandler;

# $Id: CommonHandler.pm,v 1.4 2005/03/18 04:09:50 lachoy Exp $

use strict;

$OpenInteract2::Conversion::CommonHandler::VERSION  = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub new {
    my ( $class, $convert_class ) = @_;
    my $new_class = $convert_class;
    $new_class =~ s/^OpenInteract::Handler/OpenInteract2::Action/;
    my $self = bless( { old_class => $convert_class,
                        new_class => $new_class }, $class );
    return $self;
}

sub convert {
    my ( $self ) = @_;

    # First check to see that the class is a descendent of common handler...

    # Get MY_HANDLER_PATH and set it as the INI key (strip off the
    # initial '/' and lowercase it

    # Get the MY_OBJECT_TYPE and set it in the INI under c_object_type

    # Get the MY_PACKAGE for use with templates later

    # Then just cycle through the configuration items for:
    #   * search_form
    #   * search
    #   * create
    #   * show
    #   * edit
    #   * remove
    #

    # Note that we may want to pass in a 'do_edit' to
    # 'MY_OBJECT_FORM_TEMPLATE' since the default impl will decide
    # whether to use the detail or the edit template

    # It would also be useful to allow the page title to be read by
    # Action::CommonFoo the INI as well as being set in the page...

    return ( 'no INI yet', 'no class yet', $self->{new_class} );
}

1;

__END__

=head1 NAME

OpenInteract2::Conversion::CommonHandler - Translate OI 1.x common handler files to the appropriate initialization and code

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CLASS METHODS

=head1 OBJECT METHODS

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
