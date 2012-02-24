package OpenInteract2::CreateSecurity;

# $Id: CreateSecurity.pm,v 1.3 2005/03/18 04:09:48 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure            qw( :level :scope );

$OpenInteract2::CreateSecurity::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw(
    website_dir scope scope_id level
    action action_class spops spops_class where iterator
    num_processed num_failed start_time end_time elapsed_time
);
__PACKAGE__->mk_accessors( @FIELDS );

my %VALID_SCOPE = (
   world => SEC_SCOPE_WORLD,
   user  => SEC_SCOPE_USER,
   group => SEC_SCOPE_GROUP,
);

my %VALID_LEVEL = (
    none  => SEC_LEVEL_NONE,
    read  => SEC_LEVEL_READ,
    write => SEC_LEVEL_WRITE,
);

my %DEFAULTS = (
     iterator => 'yes',
);

my ( $log );

sub new {
    my ( $class, $params ) = @_;
    my $self = bless( {}, $class );
    for ( @FIELDS ) {
        my $value = $params->{ $_ } || $DEFAULTS{ $_ };
        $self->$_( $value ) if ( $value );
    }
    return $self;
}

sub errors {
    my ( $self ) = @_;
    $self->{errors} ||= {};
    return values %{ $self->{errors} };
}

sub errors_with_params {
    my ( $self ) = @_;
    $self->{errors} ||= {};
    return $self->{errors};
}

sub validate {
    my ( $self ) = @_;

    unless ( CTX ) {
        unless ( -d $self->website_dir ) {
            my $msg =
                "Parameter 'website_dir' must be set to website dir to " .
                "create a Context object.";
            $self->{errors} = { website_dir => $msg };
            return 0;
        }
        eval {
            OpenInteract2::Context->create({
                website_dir => $self->website_dir
            });
        };
        if ( $@ ) {
            my $msg = "Failed to create Context object: $@";
            $self->{errors} = { website_dir => $msg };
            return 0;
        }
    }

    my %errors = ();

    my $scope    = lc $self->scope;
    my $scope_id = $self->scope_id;
    my $level    = lc $self->level;

    unless ( $scope =~ /^(world|group|user)$/ ) {
        $errors{scope} = "'scope' must be set to 'world', 'group', or 'user'";
    }
    if ( $scope ne 'world' and ! $scope_id ) {
        $errors{scope_id} = "'scope_id' must be set if the --scope is set " .
                            "to 'group' or 'user'";
    }
    unless ( $level =~ /^(none|read|write)$/ ) {
        $errors{level} = "'level' must be set to 'none', 'read' or 'write'";
    }

    if ( my $spops_key = $self->spops ) {
        my $spops_class = eval { CTX->lookup_object( $spops_key ) };
        if ( $spops_class ) {
            if ( ! $spops_class->can( 'fetch' ) ) {
                $errors{spops} =
                    "Class '$spops_class' is not valid. Are you " .
                    "sure it is defined in your OpenInteract setup?";
            }
            elsif ( ! $spops_class->isa( 'SPOPS::Secure' ) ) {
                $errors{spops} =
                    "Class '$spops_class' is not using security.";
            }
            else {
                $self->spops_class( $spops_class );
            }
        }
        else {
            $errors{spops} =
                "Cannot find SPOPS class mapped to key '$spops_key'";
        }
    }

    elsif ( my $action_name = $self->action ) {
        my $info = eval { CTX->lookup_action_info( $action_name ) };
        if ( $info->{class} ) {
            if ( ! UNIVERSAL::isa( $info->{class}, 'OpenInteract2::Action' ) ) {
                $errors{action} =
                    "Class '$info->{class}' does not seem to be a " .
                    "subclass of 'OpenInteract2::Action'.";
            }
            else {
                $self->action_class( $info->{class} );
            }

        }
        else {
            $errors{action} =
                "Cannot find action mapped to name '$action_name'";
        }
    }

    else {
        $errors{class} =
            "Neither action name nor SPOPS key set. One must be set to " .
            "the class for which you want to set security (e.g., " .
            "'OpenInteract2::Action::News', 'OpenInteract2::News')";
    }

    $self->scope( $VALID_SCOPE{ lc $scope } );
    $self->level( $VALID_LEVEL{ lc $level } );

    $self->{errors} = \%errors;

    if ( scalar keys %errors == 0 ) {
        $self->{_validated}++;
        return 1;
    }
    return 0;
}


sub run {
    my ( $self ) = @_;

    $self->start_time( time );
    return unless ( $self->{_validated} or $self->validate );

    $log ||= get_logger( LOG_OI );

    my $scope_id = $self->_resolve_scope_id;
    my $scope    = $self->scope;
    my $level    = $self->level;

    my ( $count, $failure ) = ( 0, 0 );

    if ( my $spops_class = $self->spops_class ) {
        my ( $object_store );
        if ( $self->iterator eq 'yes' ) {
            $object_store = $spops_class->fetch_iterator({
                skip_security => 1,
                column_group  => '_id_field',
                where         => $self->where,
            });
        }
        else {
            $object_store = $spops_class->fetch_group({
                skip_security => 1,
                column_group  => '_id_field',
                where         => $self->where,
            });
        }
        while ( my $object = $self->_get_from_store( $object_store ) ) {
            my $ok = _create_or_update_security(
                $scope, $scope_id, $level, $spops_class, $object->id
            );
            $count++;
            $failure++ unless ( $ok );
        }
    }

    elsif ( my $action_class = $self->action_class ) {
        my $ok = _create_or_update_security(
            $scope, $scope_id, $level, $action_class, '0',
        );
        $count++;
        $failure++ unless ( $ok );
    }

    else {
        # ... die here? this should have already been caught in validate()
    }

    $self->num_processed( $count );
    $self->num_failed( $failure );
    $self->end_time( time );
    $self->elapsed_time( $self->end_time - $self->start_time );
    return $count;
}

sub _create_or_update_security {
    my ( $scope, $scope_id, $level, $class, $object_id ) = @_;
    my $item = OpenInteract2::Security->fetch_match( undef, {
            class          => $class,
            object_id      => $object_id,
            scope          => $scope,
            scope_id       => $scope_id,
    });
    if ( $item ) {
        $item->{security_level} = $level;
    }
    else {
        $item = OpenInteract2::Security->new({
            class          => $class,
            object_id      => $object_id,
            scope          => $scope,
            scope_id       => $scope_id,
            security_level => $level
        });
    }
    eval { $item->save() };
    if ( $@ ) {
        $log->info( "FAIL: $object_id ($@)" );
        return 0;
    }
    else {
        $log->info( "OK: $object_id" );
        return 1;
    }
}

# Use either an iterator or a list

sub _get_from_store {
    my ( $self, $store ) = @_;
    return undef unless ( $store );
    if ( ref $store eq 'ARRAY' ) {
        return undef unless ( scalar @{ $store } );
        return shift @{ $store };
    }
    return $store->get_next;
}

sub _resolve_scope_id {
    my ( $self ) = @_;
    my $scope_id = $self->scope_id;
    my $default_objects = CTX->lookup_default_object_id;
    if ( $scope_id and $default_objects->{ $scope_id } ) {
        $scope_id = $default_objects->{ $scope_id };
    }
    return $scope_id;
}

1;

__END__

=head1 NAME

OpenInteract2::CreateSecurity - Batch create security for one or more objects or classes

=head1 SYNOPSIS

  # Create security for an action
 
  my $creator = OpenInteract2::CreateSecurity->new({
      scope       => 'group',
      scope_id    => '5',
      level       => 'write'
      action      => 'myaction',
      website_dir => '/path/to/mysite',
  });
  unless ( $creator->validate ) {
      my $errors = $creator->errors_with_params;
      print "Found errors: \n";
      foreach my $param ( keys %{ $errors } ) {
          print "$param: $errors->{ $param }\n";
      }
 
      # can also pass the error hashref to the standard exception for
      # bad parameters: 
      OpenInteract2::Exception::Parameter->throw(
          "Cannot create security, one or more parameters were invalid",
          { parameter_fail => $errors }
      );
  }
 
  # we're cleared for takeoff
  $creator->run();
 
  # how'd we do?
  print "Processed: ", $creator->num_processed, "\n",
        "Failed:    ", $creator->num_failed, "\n",
        "Elapsed:   ", $creator->elapsed_time, " secs\n";

=head1 DESCRIPTION

This class can create or update security for a single action class or
for a whole group of SPOPS objects.

=head1 CLASS METHODS

B<new( \%properties )>

Create a new object and assign all properties from
C<\%properties>. See C<PROPERTIES> for listing.

=head1 OBJECT METHODS

B<run()>

With the C<PROPERTIES> previously set find matching security objects;
if found, update them with the new security level, otherwise create
new objects.

=head1 PROPERTIES

B<scope>

B<website_dir>

B<scope_id>

B<level>

B<action>

B<action_class> (assigned after C<validate()>)

B<spops>

B<spops_class> (assigned after C<validate()>)

B<where>

B<iterator>

B<num_processed>

B<num_failed>

B<start_time>

B<end_time>

B<elapsed_time>

=head1 SEE ALSO

L<OpenInteract2::Manage::Website::CreateSecurityForAction>

L<OpenInteract2::Manage::Website::CreateSecurityForSPOPS>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
