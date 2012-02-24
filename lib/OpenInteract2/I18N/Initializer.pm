package OpenInteract2::I18N::Initializer;

# $Id: Initializer.pm,v 1.18 2005/03/30 00:13:51 infe Exp $

use strict;
use File::Spec::Functions;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Template;

my ( $TEMPLATE, $BASE_CLASS );

$OpenInteract2::I18N::Initializer::VERSION   = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub new {
    my ( $class ) = @_;
    return bless( { _files => [] }, $class );
}

# This may be really naive, but it should work for po/mo/msg files
# should match:  en | en-US | en_US

sub is_valid_message_file {
    my ( $class, $filename ) = @_;
    $log ||= get_logger( LOG_OI );
    my ( $lang ) = $filename =~ m/\b(\w\w|\w\w\-\w+|\w\w_\w+)\.\w+$/;
    $log->is_debug &&
        $log->debug( "Pulled language '$lang' from file '$filename'" );
    return $lang;
}


sub add_message_files {
    my ( $self, @files ) = @_;
    return $self->{_files} unless ( scalar @files );
    $log ||= get_logger( LOG_INIT );

    # ensure all files have an identifiable language
    foreach my $msg_file ( @files ) {
        my $lang = $self->is_valid_message_file( $msg_file );
        unless ( $lang ) {
            $log->error( "File '$msg_file' does not have identifiable language" );
            oi_error "Cannot identify language from message file ",
                     "'$msg_file'. It must end with a language code ",
                     "before the file extension. For example: ",
                     "'myapp-en.msg', 'MyReallyBigApp-es-MX.dat'";
        }
    }
    $log->is_debug &&
        $log->debug( "Adding message files: ", join( ', ', @files ) );
    push @{ $self->{_files} }, @files;
    return $self->{_files};
}

sub locate_global_message_files {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $msg_dir = CTX->lookup_directory( 'msg' );
    opendir( MSGDIR, $msg_dir )
        || oi_error "Cannot read from global message directory '$msg_dir': $!";
    my @msg_files = grep /\.(msg|mo|po)$/, readdir( MSGDIR );
    closedir( MSGDIR );
    my @full_msg_files = map { catfile( $msg_dir, $_ ) } @msg_files ;
    $log->is_debug &&
        $log->debug( "Found global message files: ",
                     join( ', ', @full_msg_files ) );
    $self->add_message_files( @full_msg_files );
    return \@full_msg_files;
}

sub run {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );
    unless ( ref $self->{_files} eq 'ARRAY' and @{ $self->{_files} } ) {
        $log->warn( "Asked to generate localization classes but no ",
                    "localization message files assigned; weird..." );
        return [];
    }

    $self->_check_for_gettext_files();

    # %all_messages is:
    #   ->lang->lang_key         = msg
    #   ->lang->SOURCE->lang_key = file with key
    # ...see _assign_file_messages() for where it gets filled

    my %all_messages = ();
    foreach my $msg_file ( @{ $self->{_files} } ) {
        $log->is_debug &&
            $log->debug( "Reading messages from file '$msg_file'" );
        my %file_messages = ();
        if ( $msg_file =~ /\.msg$/ ) {
            %file_messages = $self->_read_msg_file( $msg_file );
        }
        elsif ( $msg_file =~ /\.(mo|po)$/ ) {
            %file_messages = $self->_read_gettext_file( $msg_file );
        }
        $self->_assign_file_messages( $msg_file, \%all_messages, \%file_messages );
    }

    # ...message key sources aren't needed anymore so delete

    while ( my ( $lang, $lang_msg ) = each %all_messages ) {
        delete $lang_msg->{SOURCE};
    }

    # Now all messages are read in and merged, generate the classes

    my @generated_classes = ();
    foreach my $lang ( keys %all_messages ) {
        my $generated_class =
            $self->_generate_language_class( $lang, $all_messages{ $lang } );
        push @generated_classes, $generated_class;
    }
    return \@generated_classes;
}


########################################
# private methods below here

sub _check_for_gettext_files {
    my ( $self ) = @_;
    my $has_gettext = grep /\.(mo|po)$/, @{ $self->{_files} };
    if ( $has_gettext ) {
        eval "require Locale::Maketext::Lexicon::Gettext";
        if ( $@ ) {
            oi_error "Locale::Maketext::Lexicon is required to parse mo/po ",
                     "localization files. Please install it.";
        }
        $log->is_info &&
            $log->info( "Required Locale::Maketext::Lexicon::Gettext ok" );
    }
}

# merge messages from a file into all messages

sub _assign_file_messages {
    my ( $self, $file, $all_messages, $file_messages ) = @_;
    my $lang = $self->is_valid_message_file( $file );
    while ( my ( $key, $value ) = each %{ $file_messages } ) {
        if ( $all_messages->{ $lang }{ $key } ) {
            my $source = $all_messages->{ $lang }{SOURCE}{ $key };
            $log->is_debug &&
                $log->debug(
                    "DUPLICATE MESSAGE KEY FOUND. Key '$key' from ",
                    "'$file' was already found in message file ",
                    "'$source' read in earlier. Existing key WILL NOT BE ",
                    "OVERWRITTEN, which may cause odd behavior." );
        }
        else {
            $all_messages->{ $lang }{ $key }         = $value;
            $all_messages->{ $lang }{SOURCE}{ $key } = $file;
        }
    }
}

sub _read_msg_file {
    my ( $self, $msg_file ) = @_;
    my %messages = ();
    my ( $current_key, $current_msg, $readmore );
    open( MSG, '<', $msg_file )
        || oi_error "Cannot read messages from '$msg_file': $!";
    while ( <MSG> ) {
        chomp;

        # Skip comments and blanks unless we're in a readmore block
        next if ( ! $readmore and /^\s*\#/ );
        next if ( ! $readmore and /^\s*$/ );

        my $line = $_;
        my $this_readmore = $line =~ s|\\\s*$||;

        # lop off spaces at the beginning of continued lines so
        # they're more easily distinguished
        if ( $readmore ) {
            $line =~ s/^\s+//;
            $current_msg .= $line;
        }
        else {
            # since we split on a '=' the key can have any character EXCEPT a '='
            my ( $key, $msg ) = split( /\s*=\s*/, $line, 2 );
            if ( $key ) {
                if ( $current_key ) {
                    $messages{ $current_key } = $current_msg;
                    $log->is_debug &&
                        $log->debug( "Set '$current_key' = '$current_msg'" );
                }
                $current_key = $key;
                $current_msg = $msg;
                $readmore    = undef;
            }
        }
        $readmore = $this_readmore;
    }
    close( MSG );
    $log->is_debug && $log->debug( "Set '$current_key' = '$current_msg'" );
    $messages{ $current_key } = $current_msg;
    return %messages;
}


sub _read_gettext_file {
    my ( $self, $gettext_file ) = @_;
    open( GETTEXT, '<', $gettext_file )
        || oi_error "Failed to open gettext file: $!";
    my $msg = Locale::Maketext::Lexicon::Gettext->parse( <GETTEXT> );
    close( GETTEXT );
    
    # The PO header metadata is parsed and added with __ prefixes to
    # message hash. The complete header is stored with key ''
    # which we remove as unnecessary.
    delete $msg->{ '' } if exists $msg->{ '' };

    if ( $log->is_debug ) {
        $log->debug( "Read following messages from '$gettext_file': " );
        while ( my ( $key, $value ) = each %{ $msg } ) {
            $log->debug( "  '$key' = '$value'" );
        }
    }
    return %{ $msg }
}


sub _generate_language_class {
    my ( $self, $lang, $messages ) = @_;
    $log ||= get_logger( LOG_INIT );

    unless ( $lang ) {
        oi_error "Cannot generate maketext class without a language";
    }

    my @base_class_pieces = ( 'OpenInteract2', 'I18N' );
    my @lang_class_pieces = @base_class_pieces;

    # 'en' is always the default language no matter what your
    # website's default language is

    unless ( $lang eq 'en' ) {
        push @base_class_pieces, 'en';
    }

    if ( my @pieces = split( /[\-\_]/, $lang ) ) {
        push @lang_class_pieces, @pieces; # 'es', 'mx';
        pop @pieces;
        push @base_class_pieces, @pieces; # 'es'
    }
    else {
        push @lang_class_pieces, $lang;   # 'es'
    }
    my $base_class = join( '::', @base_class_pieces );
    my $lang_class = join( '::', @lang_class_pieces );
    my %params = (
        lang       => $lang,
        lang_class => $lang_class,
        base_class => $base_class,
    );

    $log->is_debug &&
        $log->debug( "Trying to generate class '$lang_class' for language ",
                     "'$lang' with base class '$base_class'" );
    my ( $gen_class );

    $TEMPLATE   ||= Template->new();
    $BASE_CLASS ||= $self->_get_lang_template();

    $TEMPLATE->process( \$BASE_CLASS, \%params, \$gen_class )
        || oi_error "Failed to process maketext subclass template: ",
                    $TEMPLATE->error();
    $log->is_debug &&
        $log->debug( "Class generated ok; now eval'ing class with\n",
                     $gen_class );
    eval $gen_class;
    if ( $@ ) {
        $log->error( "Failed to evaluate generated class\n$gen_class\n$@" );
        oi_error "Failed to evaluate generated class '$lang_class': $@";
    }
    $log->is_debug &&
        $log->debug( "Evaluated class $lang_class ok" );

    $lang_class->_assign_messages( $messages );
    $log->is_debug &&
        $log->debug( "Assigned mesages to $lang_class ok" );

    return $lang_class;
}

sub _get_lang_template {
    return <<'TEMPLATE';
package [% lang_class %];

use strict;

use vars qw( %Lexicon );

@[% lang_class %]::ISA = qw( [% base_class %] );

%Lexicon = ();

sub get_oi2_lang { return '[% lang %]' }

sub _assign_messages {
    my ( $class, $messages ) = @_;
    while ( my ( $key, $value ) = each %{ $messages } ) {
        $Lexicon{ $key } = $value;
    }
}

1;

TEMPLATE
}

1;

__END__

=head1 NAME

OpenInteract2::I18N::Initializer - Read in localization messages and generate maketext classes

=head1 SYNOPSIS

 my $init = OpenInteract2::I18N::Initializer->new;
 $init->add_message_files( @some_message_files );
 my $gen_classes = $init->run;
 print "I generated the following classes: ", join( @{ $gen_classes } ), "\n";

=head1 DESCRIPTION

This class is generally only used by the OI2 startup procedure, which
scans all packages for message files and adds them to this
initializer, then runs it. The purpose of this class is to generate
subclasses for use with L<Locale::Maketext|Locale::Maketext>. Those
classes are fairly simple and generally only contain a package
variable L<%Lexicon> which C<L::M> uses to work its magic.

The message files may be in one of three formats:

=over 4

=item *

B<.msg> - Custom key/value pair format with interpolated variables
indicated by C<[_1]> , C<[_2]>, etc. as supported by
L<Locale::Maketext>. End-of-line continuations ('\') are also
supported -- see L<OpenInteract2::Manual::I18N> for formatting
details.

=item *

B<.po> - Plaintext format used by gettext. This format is documented
elsewhere (see L<SEE ALSO>) and parsed by L<Locale::Maketext::Lexicon>.

=item *

B<.mo> - Compiled gettext files. This format is documented elsewhere
(see L<SEE ALSO>) and parsed by L<Locale::Maketext::Lexicon>.

=back

Message files can also be mixed and matched, even within a package. So
if you've got one translator who likes to use gettext tools you can
include them alongside people who are fine with the OI2 message
format.

=head1 CLASS METHODS

B<new()>

Return a new object. Any parameters are ignored.

B<is_valid_message_file( $filename )>

If C<$filename> is a valid message file this returns the language from
the filename, otherwise it returns false.

The language must be the last distinct set of characters before the
file extension. (Distinct in the '\b' regex sense.) The following are
ok:

  myapp-en.msg
  myotherapp-en_MX.po
  messages_en-HK.mo

The following are not:

 english-messages.msg
 messages-en-part2.po
 messagesen.mo

Currently we assume the base language identifier is two characters
(e.g., 'en', 'jp', 'ru') and the extension (e.g., 'US', 'CA', 'MX')
can by any number of characters. This may be wildly naive and may
change.

=head1 OBJECT METHODS

B<add_message_files( @fully_qualified_files )>

Adds all files in C<@fully_qualified_files> to its internal list of
files to process. It does not process these files until C<run()>.

If any file in C<@fully_qualified_files> does not have a valid
language we throw an exception.

B<locate_global_message_files()>

Finds all message files (that is, files ending in '.msg') in the
global message directory as reported by the L<OpenInteract2::Context>
and adds them to the initializer. Normally only called by
L<OpenInteract2::Setup::ReadLocalizedMessages>.

Returns: arrayref of fully-qualified files added

B<run()>

Reads messages from all files added via C<add_message_files()> and
generates language-specific subclasses for all messages found. Once
the subclasses are created the system does not know from where the
messages come since all messages are flattened into a per-language
data structure. So the following:

 file: msg-en.msg
 keys:
   foo.title
   foo.intro
   foo.label.main

 file: other_msg-en.mo
 keys:
   baz.title
   baz.intro
   baz.conclusion

 file: another_msg-en.po
   bar.title
   bar.intro
   bar.error.notfound

would be flattened into:

 lang: en
   foo.title
   foo.intro
   foo.label.main
   baz.title
   baz.intro
   baz.conclusion
   bar.title
   bar.intro
   bar.error.notfound

The method throws an exception on any of the following conditions:

=over 4

=item *

Cannot open or read from one of the message files.

=item *

If you have any gettext files (mo/po extension) and do not have
L<Locale::Maketext::Lexicon>.

=item *

Cannot process the template used to generate the class.

=item *

Cannot evaluate the generated class.

=back

Note that a duplicate key (that is, a key defined in multiple message
files) will not generate an exception. Instead it will generate a
logging message with an 'warn' level.

See more about the format used for the custom message files in
L<OpenInteract2::Manual::I18N>.

Returns: arrayref of the names of the classes generated.

=head1 SEE ALSO

L<Locale::Maketext>

L<Locale::Maketext::Lexicon>

gettext: L<http://www.gnu.org/software/gettext/>

L<OpenInteract2::I18N>

L<OpenInteract2::Manual::I18N>

L<OpenInteract2::Setup::ReadLocalizedMessages>

=head1 COPYRIGHT

Copyright (c) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

