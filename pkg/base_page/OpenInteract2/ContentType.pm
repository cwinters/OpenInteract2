package OpenInteract2::ContentType;

# $Id: ContentType.pm,v 1.2 2004/04/09 11:38:26 lachoy Exp $

use strict;

@OpenInteract2::ContentType::ISA     = qw( OpenInteract2::ContentTypePersist );
$OpenInteract2::ContentType::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use constant DEFAULT_MIME_TYPE => 'text/plain';

my $BOUND_CHARACTER = ';';

########################################
# RULES
########################################

# The rules here are to ensure that the extensions can be found
# properly

sub ruleset_factory {
    my ( $class, $rs ) = @_;
    push @{ $rs->{post_fetch_action} }, \&split_extensions;
    push @{ $rs->{pre_save_action} }, \&merge_extensions;
    return __PACKAGE__;
}

sub split_extensions {
    my ( $self ) = @_;
    $self->{extensions} = join( ' ',
                                grep ! /^\s*$/,
                                split ( /$BOUND_CHARACTER/, $self->{extensions} ) );
    return 1;
}

sub merge_extensions {
    my ( $self ) = @_;
    $self->{extensions} = $BOUND_CHARACTER .
                          join( $BOUND_CHARACTER, split /\s+/, $self->{extensions} ) .
                          $BOUND_CHARACTER;
    return 1;
}


########################################
# CLASS METHODS
########################################

# Class method so that you can lookup a MIME type by an extension. If
# the extension isn't found, we return DEFAULT_MIME_TYPE.

# $p is used here to pass extra information to the SELECT, like a
# value for 'DEBUG'

sub mime_type_by_extension {
    my ( $class, $extension, $p ) = @_;
    $extension = lc $extension;
    $p ||= {};
    my $type_list = $class->db_select({
                         %{ $p },
                         from   => $class->table_name,
                         select => [ 'mime_type' ],
                         where  => 'extensions LIKE ?',
                         value  => [ "%$BOUND_CHARACTER$extension$BOUND_CHARACTER%" ],
                         return => 'single-list',
                         db     => $class->global_datasource_handle });
    return ( $type_list->[0] )
             ? $type_list->[0] : DEFAULT_MIME_TYPE;
}

1;
