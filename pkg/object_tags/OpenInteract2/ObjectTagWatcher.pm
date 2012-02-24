package OpenInteract2::ObjectTagWatcher;

# $Id: ObjectTagWatcher.pm,v 1.1 2005/03/29 05:10:37 lachoy Exp $

use strict;

$OpenInteract2::ObjectTagWatcher::VERSION  = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub update {
    my ( $class, $type, $config ) = @_;
    return unless ( $type eq 'spops' and ref $config eq 'HASH' );
    if ( $config->{is_taggable} eq 'yes' ) {
        $config->{isa} ||= [];
        push @{ $config->{isa} }, 'OpenInteract2::TaggableObject';
    }
}

1;

__END__

=head1 NAME

OpenInteract2::ObjectTagWatcher - Configuration watcher to look for 'is_taggable'

=head1 SYNOPSIS

 [myspops]
 class = OpenInteract2::Foo
 ...
 is_taggable = yes
 
 # At startup OpenInteract2::Foo will have
 # OpenInteract2::TaggableObject in its 'isa'

=head1 DESCRIPTION

Configuration initializer to add a shortcut to SPOPS configuration --
a 'is_taggable = yes' will result in the SPOPS class getting
L<OpenInteract2::TaggableObject> in its 'isa'.

=head1 SEE ALSO

L<OpenInteract2::Config::Initializer>

=head1 COPYRIGHT

Copyright (c) 2004-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
