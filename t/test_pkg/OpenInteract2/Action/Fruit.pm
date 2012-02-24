package OpenInteract2::Action::Fruit;

use strict;
use base qw( OpenInteract2::Action );
use OpenInteract2::Context qw( CTX );

$OpenInteract2::Action::Fruit::VERSION = '0.02';
$OpenInteract2::Action::Fruit::author  = 'chris@cwinters.com';

sub handler {
    my ( $self ) = @_;
    my $fruits = eval {
        CTX->lookup_object( 'fruit' )
           ->fetch_group({ 'order' => 'name' })
    };
    if ( $@ ) {
        $self->param_add(
            error_msg => "Found error when trying to fetch fruit: $@" );
    }
    my %params = ( fruits_in_store => $fruits );
    return $self->generate_content(
                    \%params,
                    { name => 'fruit::fruit-display' } );
}

1;
