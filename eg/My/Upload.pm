package My::Upload;

use strict;
use base qw( OpenInteract2::Action );
use OpenInteract2::Context   qw( DEBUG LOG );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::URL;

sub handler {
    my ( $self ) = @_;

    my $content = initial_page();

    my $request = $self->request;
    #warn "Request loaded: ", Dumper( $request ), "\n";

    foreach my $name ( $request->param ) {
        $content .= "$name = " . $request->param( $name ) . "<br>\n";
    }

    my @uploads = $request->upload;
    DEBUG && LOG( LDEBUG, "Found [", scalar( @uploads ), "] uploads" );
    if ( scalar @uploads > 0 ) {
        $content .= "Uploads:<br>\n";
    }
    foreach my $upload ( @uploads ) {
        $content .= join( "<br>\n", "Name: " . $upload->name,
                                    "Size: " . $upload->size,
                                    "Content type: " . $upload->content_type );
        my $fh = $upload->filehandle;
        $content .= "\n<br>Content:<br><pre>\n";
        $content .= join( '', <$fh> );
        $content .= "</pre>\n";
    }

    my $other_url = OpenInteract2::URL->create( '/upload/foo/' );
    $content .= "<p>Go to <a href='$other_url'>another page</a></p>";
    $content .= upload_form();
    return $content;
}

sub initial_page {
    return <<INITIAL;
<html><head><title>Quickie form</title></head>
<body>
INITIAL
}

sub upload_form {
    my $url = OpenInteract2::URL->create( '/upload/bar/' );
    return <<UPLOAD;
<h3>Upload a File</h3>
<form enctype="multipart/form-data"
      action="$url"
      method="post">
<p>
<input type="file" name="upload"><br>
<input type="file" name="upload_two"><br>
<input type="file" name="upload_three"><br>
Your nickname: <input type="text" name="nickname" size="15"><br>
Your height: <input type="text" name="height" size="15"><br>
Your weight: <input type="text" name="weight" size="15"><br>
<input type="submit" value="Send">
</p>
</form>
</body></html>
UPLOAD
}

1;
