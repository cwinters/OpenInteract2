package OpenInteract2::App::FullText;

# $Id: FullText.pm,v 1.2 2005/03/10 01:24:58 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::FullText::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::FullText::EXPORT  = qw( install );

my $NAME = 'full_text';

# Not a method, just an exported sub
sub install {
    my ( $website_dir ) = @_;
    my $manage = OpenInteract2::Manage->new( 'install_package' );
    $manage->param( website_dir   => $website_dir );
    $manage->param( package_class => __PACKAGE__ );
    return $manage->execute;
}

sub new {
    return OpenInteract2::App->new( $NAME );
}

sub get_brick {
    require OpenInteract2::Brick;
    return OpenInteract2::Brick->new( $NAME );
}

sub get_brick_name {
    return $NAME;
}

OpenInteract2::App->register_factory_type( $NAME => __PACKAGE__ );

1;

__END__

=pod

=head1 NAME

OpenInteract2::App::FullText - Package implementing full-text searching across objects in SPOPS and OpenInteract

=head1 SYNOPSIS

 # Make your SPOPS object available to the full text search
 # in yourpkg/conf/spops.ini
 #  -- set 'is_searchable' to 'yes'
 #  -- add 'fulltext_field', a list of fields to index for each object
 
 [myobj]
 class = OpenInteract2::MyObject
 ...
 is_searchable = yes
 fulltext_field = description
 fulltext_field = title
 fulltext_field = author
 fulltext_field = location
 # OPTIONAL
 fulltext_pre_index_method = fetch_content
 ...
 
 # Tell OI2 to use the built-in indexer 'DBI'
 # in conf/server.ini
 [fulltext]
 default = DBI
 
 [fulltext DBI]
 class = OpenInteract2::FullTextIndexer::DBI
 ...

=head1 DESCRIPTION

This package provides the means to create a full-text index from
arbitrary objects. All you have to do is tag the object as full-text
indexable (by setting 'is_searchable' to 'yes', which adds
L<OpenInteract2::FullTextRules|OpenInteract2::FullTextRules> to your object's
'isa' SPOPS configuration key) and specify which fields are to be
indexed. The rest is handled seamlessly.

See the
L<OpenInteract2::FullTextIndexer|OpenInteract2::FullTextIndexer>
module to learn more about how the indexing process works, and check
out
L<OpenInteract2::Action::SiteSearch|OpenInteract2::Action::SiteSearch>
to learn about the searching works.

=head2 Database

If you use the default indexer and you are using more than one
database you may need to specify the datasource to use for your
fulltext index in the server configuration key
'fulltext.DBI.datasource'. By default we use the 'main' datasource.

=head1 OBJECTS

B<full_text_mapping> - Simple object with an artificial ID, object
class and object id fields. 

=head1 ACTIONS

B<search> (also 'sitesearch' alias)

Run a search against the full-text index. Takes the argument
'keywords' with the search words along with the argument 'search_type'
set to 'any' or 'all' (default: 'all'). It has the ability to page the
search, persisting the results to disk using
L<OpenInteract2::ResultsManage|OpenInteract2::ResultsManage>.

B<search_box>

Small box for searching.

=head1 RULESETS

None

=head1 TO DO

B<Admin Handler for Re-indexing>

Create an administrative handler (task) for re-indexing an entire
class (or a chunk of a class, searchable?) via the browser.

B<Flexibility in Storage>

Allow different types of storage for the index -- see
L<DBIx::FullTextSearch|DBIx::FullTextSearch> -- but ensure that
database portability is kept in mind.

B<Flexibility in Searching>

Allow proximity searches, phrase searches, explicit scoring, wildcard
specification, boolean operators.

B<Weighted Parsing>

Words in headlines or the title should be "worth" more than normal
terms -- maybe increase the hit count for them? (Such as: a term if
found in a title is worth 1.5 matches.)

=head1 SEE ALSO

L<Lingua::Stem|Lingua::Stem>

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
