package OpenInteract2::PageRules;

use strict;
use File::Basename           qw();
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

$OpenInteract2::PageRules::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

########################################
# RULES
########################################

# Here we add a ruleset so we can set the value for 'directory'
# whenever we save the object

sub ruleset_factory {
    my ( $class, $rs_table ) = @_;
    push @{ $rs_table->{pre_save_action} },    \&find_directory;
    push @{ $rs_table->{post_save_action} },   \&save_content;
    push @{ $rs_table->{post_remove_action} }, \&remove_content;
    return __PACKAGE__;
}


sub find_directory {
    my ( $self, $p ) = @_;
    $self->{location} =~ s|/+|/|g;
    $self->{directory} = File::Basename::dirname( $self->{location} );
    return 1;
}


sub save_content {
    my ( $self, $p ) = @_;
    return 1 unless ( $self->{content} );
    $log ||= get_logger( LOG_APP );

    my $storage_class = $OpenInteract2::Page::STORAGE_CLASS{ $self->{storage} };
    $log->is_info &&
        $log->info( "Using storage class '$storage_class' to save content ",
                    "for $self->{location} (ID: $self->{page_id})" );
    return $self->{content} = $storage_class->save( $self, $self->{content} );
}


sub remove_content {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_APP );
    my $storage_class = $OpenInteract2::Page::STORAGE_CLASS{ $self->{storage} };
    $log->is_info &&
        $log->info( "Using storage class '$storage_class' to remove ",
                    "content for $self->{location} (ID: $self->{page_id})" );
    $self->{content} = $storage_class->remove( $self );
    return 1;
}

1;
