package OpenInteract2::Action::Wiki;

use strict;
use base qw( OpenInteract2::Action );

use DateTime::Format::Strptime;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::File;
use OpenInteract2::URL;

$OpenInteract2::Action::Wiki::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my %ACTIONS = map { $_ => 1 }
              qw( list recent referenced_by search
                  display edit preview commit );

my $date_parser = DateTime::Format::Strptime->new( pattern => '%Y-%m-%d %H:%M' );
my ( $wiki );

sub handler {
    my ( $self ) = @_;

    unless ( $wiki ) {
        my $wiki_class = $self->param( 'wiki_class' );
        unless ( $wiki_class ) {
            oi_error "You must specify a wiki implementation in the ",
                     "action configuration parameter 'wiki.wiki_class'";
        }
        eval "require $wiki_class";
        if ( $@ ) {
            oi_error "Failed to bring in wiki class '$wiki_class': $@";
        }

        $wiki = $wiki_class->create({
            node_prefix => OpenInteract2::URL->create( $self->url ),
            index_type  => $self->param( 'index_type' ),
            index_dir   => $self->param( 'index_dir' ),
            datasource  => $self->param( 'datasource' ),
        });
    }

    my ( $wiki_action, $node ) = $self->_parse_url_for_action_info;

    unless ( $ACTIONS{ $wiki_action } ) {
        $self->task( 'unknown_action' );
        $self->param( bad_action => $wiki_action );
        return $self->_unknown_action();
    }

    $self->param( node => $node ) if ( $node );
    $self->task( $wiki_action );
    my $action_method = '_' . $wiki_action;
    return $self->$action_method();
}

sub _unknown_action {
    my ( $self ) = @_;
    return $self->generate_content({
        bad_action => $self->param( 'bad_action' )
    });
}

sub _list {
    my ( $self ) = @_;
    my @nodes = $wiki->list_all_nodes;
    return $self->generate_content({ nodes => \@nodes });
}

sub _recent {
    my ( $self ) = @_;
    my @nodes = $wiki->list_recent_changes( last_n_changes => 20 );
    return $self->generate_content({
        nodes => [ map { $_->{name} } @nodes ]
    });
}

sub _referenced_by {
    my ( $self ) = @_;
    my $node = $self->param( 'node' );
    my @nodes = $wiki->list_backlinks( node => $node );
    return $self->generate_content({
        nodes            => \@nodes,
        referencing_node => $node
    });
}

sub _search {
    my ( $self ) = @_;
    my $keywords = CTX->request->param( 'keywords' );
    my %nodes = $wiki->search_nodes( $keywords );
    return $self->generate_content({
        nodes => [ keys %nodes ],
        query => $keywords
    });
}

sub _display {
    my ( $self ) = @_;
    my $node = $self->param( 'node' );

    unless ( $wiki->node_exists( $node ) ) {
        $self->task( 'edit' );
        return $self->_edit();
    }

    my $request = CTX->request;
    my $version = $request->param( 'version' );
    my @args = ( $version )
                 ? ( name => $node, version => $version )
                 : ( $node );
    my %node_info = $wiki->retrieve_node( @args );
    my $cooked = $wiki->format( $node_info{content} );

    my $versions = $self->_retrieve_other_version_metadata(
        $node, $node_info{version}
    );

    my %params = (
        content  => $cooked,
        node     => $node,
        version  => $node_info{version},
        modified => $node_info{last_modified},
        versions => $versions,
    );

    return $self->generate_content( \%params );
}

sub _edit {
    my ( $self ) = @_;

    my $node = $self->param( 'node' );
    my $raw = $wiki->retrieve_node( $node );

    my %params = (
        node      => $node,
        action    => 'preview',
        content   => $raw,
        checksum  => md5_hex( $raw ),
    );
    return $self->generate_content( \%params );
}

sub _preview {
    my ( $self ) = @_;
    my $request = CTX->request;

    my $node = $self->param( 'node' );
    my $raw          = $request->param( 'content' );
    my $preview_html = $wiki->format( $raw );
    my $checksum     = $request->param( 'checksum' );

    my %params = (
        node      => $node,
        action    => 'commit',
        content   => $raw,
        checksum  => $checksum,
        formatted => $preview_html,
    );

    return $self->generate_content( \%params );
}

sub _commit {
    my ( $self ) = @_;
    my $request = CTX->request;

    my $node = $self->param( 'node' );
    my $submitted_content = $request->param( 'content' );
    my $checksum = $request->param( 'checksum' );
    my $written = $wiki->write_node( $node, $submitted_content, $checksum );
    if ( $written ) {

        # Now submit for OI's fulltext searching
        


        $self->task( 'display' );
        return $self->_display();
    }
    else {
        $self->param_add(
            error_msg => "Conflict found when editing '$node'" );
        $self->task( 'preview' );
        return $self->_preview();
    }
}

########################################
# NON-DISPLAY METHODS

sub _parse_url_for_action_info {
    my ( $self ) = @_;
    my $request = CTX->request;
    my ( $my_name, @action_items ) = split( '/', $request->url_relative );

    my ( $wiki_action, $node );
    my $num_items = scalar @action_items;
    if ( $num_items > 1 ) {
        ( $wiki_action, $node ) = @action_items;
    }
    elsif ( $num_items == 1 ) {
        if ( $ACTIONS{ $action_items[0] } ) {
            ( $wiki_action, $node ) = ( $action_items[0], undef );
        }
        else {
            ( $wiki_action, $node ) = ( 'display', $action_items[0] );
        }
    }
    else {
        my $home_page = $self->param( 'wiki_home' );
        ( $wiki_action, $node ) = ( 'display', $home_page );
    }

    $node ||= $request->param( 'node' );

    return ( $wiki_action, $node );
}


sub _retrieve_other_version_metadata {
    my ( $self, $node, $node_version ) = @_;

    return [] unless ( $node and $node_version );

    my $sql = q{
        SELECT version, modified, comment
          FROM content
         WHERE name = ?
               AND version != ?
         ORDER BY version desc
    };

    my ( $sth );
    eval {
        $sth = $wiki->store->dbh->prepare( $sql );
        $sth->execute( $node, $node_version );
    };
    if ( $@ ) {
        oi_error "Error fetching versions of '$node' earlier ",
                 "than '$node_version': $@";
    }
    my @versions = ();
    while ( my $row = $sth->fetchrow_arrayref ) {
        push @versions, {
            version  => $row->[0],
            modified => $date_parser->parse_datetime( $row->[1] ),
            comment  => $row->[2]
        };
    }
    $sth->finish;
    return \@versions;
}

1;
