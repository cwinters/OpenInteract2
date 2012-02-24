package OpenInteract2::Wiki::Formatter;

# $Id: Formatter.pm,v 1.1 2004/06/03 13:04:43 lachoy Exp $

use strict;
use base qw( CGI::Wiki::Formatter::Default );
use CGI;
use HTML::PullParser;
use Text::WikiFormat;

$OpenInteract2::Wiki::Formatter::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub _init {
    my ( $self, %args ) = @_;

    # Store the parameters or their defaults.
    my %defs = (
        implicit_links           => 0,
        extended_links           => 1,
        extended_link_delimiters => [ '[', ']' ],
        absolute_links           => 1,
        allowed_tags             => [],
        macros                   => {},
    );

    my %collated = ( %defs, %args );
    foreach my $k ( keys %defs ) {
        $self->{ "_" . $k } = $collated{ $k };
    }

    return $self;
}

sub format {
    my ( $self, $raw ) = @_;
    my $safe = "";

    my %allowed = map { lc( $_ ) => 1, "/". lc( $_ ) => 1}
                       @{ $self->{_allowed_tags} };

    if ( scalar keys %allowed ) {

        # If we are allowing some HTML, parse and get rid of the nasties.
        my $parser = HTML::PullParser->new(
            doc   => $raw,
            start => '"TAG", tag, text',
            end   => '"TAG", tag, text',
            text  => '"TEXT", tag, text'
        );
        while ( my $token = $parser->get_token ) {
            my ( $flag, $tag, $text ) = @{ $token };
            if ( $flag eq "TAG" and ! defined $allowed{ lc( $tag ) } ) {
                $safe .= CGI::escapeHTML( $text );
            }
            else {
                $safe .= $text;
            }
        }
    }

    # Else just escape everything.
    else {
        $safe = CGI::escapeHTML( $raw );
    }

    # Now process any macros.
    my %macros = %{ $self->{_macros} };
    foreach my $regexp ( keys %macros ) {
        $safe =~ s/$regexp/$macros{ $regexp }/g;
    }

#    warn join( "\n",
#               "Looking to format\n$safe\nwith args: \n",
#               "prefix         => $self->{_node_prefix}",
#               "implicit_links => $self->{_implicit_links}",
#               "extended       => $self->{_extended_links}",
#               "extended_link_delimiters => " . join( ', ', @{ $self->{_extended_link_delimiters} } ),
#               "absolute_links => $self->{_absolute_links}" );

    $safe = $self->run_pre_processing( $safe );
    my $base = Text::WikiFormat::format(
        $safe,
        {
            extended_link_delimiters => $self->{_extended_link_delimiters},
            strong_tag               => qr/\*(.+?)\*/,
        },
        {
            prefix         => $self->{_node_prefix},
            implicit_links => $self->{_implicit_links},
            extended       => $self->{_extended_links},
            absolute_links => $self->{_absolute_links},
        }
    );
    return $self->run_post_processing( $base );
}

sub run_pre_processing {
    my ( $self, $text ) = @_;
    return $text;
}

sub run_post_processing {
    my ( $self, $text ) = @_;
    $text = $self->process_tables( $text );
    return $text;
}

sub process_tables {
    my ( $self, $text ) = @_;
    my @lines = split /\r?\n/, $text;
    my @use_lines = ();
    my $in_table = 0;
    my $row_count = 1;
LINE:
    for ( @lines ) {
        unless ( /^\|/ or /^<p>\|/ ) {
            if ( $in_table ) {
                $in_table = 0;
                $row_count = 1;
                push @use_lines, '</table>';
            }
            push @use_lines, $_;
            next LINE;
        }
        unless ( $in_table ) {
            $in_table++;
            s/^<p>//;
            s|<br\s*/\s*>$||;
            my @headers = split /\s*\|\s*/, $_;
            warn "Retrieved headers: (", join( ') (', @headers ), ") from '$_'\n";
            shift @headers;
            push @use_lines, '<table border="0" cellspacing="0" cellpadding="4">',
                             '<tr>',
                             map( { "  <th>$_</th>" } @headers ),
                             '</tr>';
            next LINE;
        }

        my @data = split /\s*\|\s*/, $_;
        shift @data if ( $data[0]  =~ m/^\s*$/ );
        pop @data   if ( $data[-1] =~ m/^\s*$/ );
        my $row_class = ( $row_count % 2 == 0 ) ? 'rowEven' : 'rowOdd';
        $row_count++;
        push @use_lines, qq{<tr align="left" class="$row_class">},
                         map( { "  <td>$_</td>" } @data ),
                         '</tr>';
    }
    if ( $in_table ) {
        push @use_lines, '</table>';
    }
    return join( "\n", @use_lines );
}

1;
