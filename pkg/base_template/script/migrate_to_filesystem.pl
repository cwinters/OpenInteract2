#!/usr/bin/perl

# $Id: migrate_to_filesystem.pl,v 1.1 2003/03/25 14:23:48 lachoy Exp $

# migrate_to_filesystem.pl
#   Use for upgrading to base_template 2.00+/OI 1.50+ when you have
#   templates stored in the database. This will write all the
#   templates stored there to your global package template directory.

use strict;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );
use OpenInteract2::Setup;
use SPOPS::Initialize;

{
    OpenInteract2::Setup->setup_static_environment_options(
                                             undef, {}, { temp_lib => 'lazy' } );
    if ( CTX->server_config->spops_config->{sitetemplate} ) {
        die "You are using an old version of the 'base_template' package. ",
            "Please upgrade before running.\n";
    }

    my %config = (
      oldtemplate => {
         class        => 'OpenInteract2::OldSiteTemplate',
         isa          => [ 'OpenInteract2::SPOPS::DBI', 'SPOPS::DBI' ],
         rules_from   => [ 'SPOPS::Tool::DBI::DiscoverField' ],
         field        => [],
         id_field     => 'template_id',
         base_table   => 'template',
      }
    );
    SPOPS::Initialize->process({ config => \%config });
    my $template_list = OpenInteract::OldSiteTemplate->fetch_group;
    foreach my $old ( @{ $template_list } ) {
        my $new_template = OpenInteract2::SiteTemplate->new({
                              package  => $old->{package},
                              name     => $old->{name},
                              contents => create_contents( $old ) });
        eval { $new_template->save };
        my $attempt = "[$old->{package}::$old->{name}] --> [" . $new_template->full_filename . "]";
        if ( $@ ) {
            print "FAILED: $attempt\n$@\n";
        }
        else {
            print "OK: $attempt\n";
        }
    }
    print "All done\n";
}

sub _create_contents {
    my ( $template ) = @_;
    my $contents = $template->{template};
    if ( $template->{script} ) {
        $contents .= "\n\n<script language='JavaScript'>\n$template->{script}\n</script>\n";
    }
    return $contents;
}
