package OpenInteract2::Setup::RequireIndexers;

# $Id: RequireIndexers.pm,v 1.2 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup::RequireClasses );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::RequireIndexers::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'require indexers';
}

sub get_dependencies {
    return ( 'create templib' );
}

sub setup {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $all_idx_config = $ctx->lookup_fulltext_config;
    unless ( ref $all_idx_config eq 'HASH' ) {
        $log->warn( "Fulltext configuration does not return a ",
                    "hash reference; continuing with setup, but ",
                    "this could bode poorly for server operation..." );
        return;
    }

    my @indexer_classes = ();
    while ( my ( $idx_name, $idx_info ) = each %{ $all_idx_config } ) {
        next if ( $idx_name eq 'default' );
        my $idx_class = $idx_info->{class};
        unless ( $idx_class ) {
            $log->warn( "Indexer '$idx_name' is not associated with ",
                        "a class; continuing with setup,  but this could ",
                        "bode poorly for server operation..." );
        }
        push @indexer_classes, $idx_class;
    }
    $self->param( classes => \@indexer_classes );
    $self->param( classes_type => 'Full-text indexer classes' );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::RequireIndexers - Bring in all indexer classes

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'require indexers' );
 $setup->run();

=head1 DESCRIPTION

This setup action subclasses L<OpenInteract2::Setup::RequireClasses>
and performs its actions in B<setup()>.

Note that except for the 'default' key we expect every entry under the
'fulltext' server configuration key to have a configuration associated
with it, like this:

 [fulltext DBI]
 class           = OpenInteract2::FullTextIndexer::DBI
 datasource      = main
 column_group    = listing
 min_word_length = 3
 max_word_length = 30
 index_table     = full_text_index
 class_map_table = full_text_index_class
 stem_locale     = en

=over 4

=item *

Find all declared full-text indexers from the context method
C<lookup_fulltext_config()> (sourced by the 'fulltext' server
configuration key).

=item *

Pull out the 'class' reference for each and store it in 'classes'
parameter.

=back

Our parent class implements C<execute()> which calls C<require()> on
every class in the 'classes' parameter.

=head2 Setup Metadata

B<name> - 'require indexers'

B<dependencies> - 'create templib'

=head1 SEE ALSO

L<OpenInteract2::Setup>

L<OpenInteract2::Setup::RequireClasses>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
