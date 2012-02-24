package OpenInteract2::JHIQuote;

# $Id: JHIQuote.pm,v 1.1 2004/06/03 13:04:41 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use HTML::Entities;
use Text::Wrap qw( wrap );

my @QUOTES = ();

BEGIN: {
        local $/ = undef;
        my $raw = <DATA>;
        my @raw_quotes = split( "%%\n", $raw );
        foreach my $quote ( @raw_quotes ) {
            my @lines = split( "\n", $quote );
            my $source = pop @lines;
            next unless ( $source );
            $source =~ s/^\s+//;
            push @QUOTES, [ join( "\n", @lines ), $source ];
        }
}


sub get {
    return @{ $QUOTES[ int( rand( scalar @QUOTES ) ) ] };
}

sub get_wrapped {
    my ( $quote, $source ) = get();
    local $Text::Wrap::columns = 60;
    return ( wrap( undef, undef, $quote ), $source );
}

sub get_html {
    my ( $quote, $source ) = get();
    $quote = HTML::Entities::encode( $quote );
    if ( $quote =~ /^\s{8}/ ) {
        $quote = "<tt>$quote</tt>";
    }
    $quote =~ s/\n/<br>\n/g;
    return join( "<br>\n", $quote, HTML::Entities::encode( $source ) );
}

sub get_full_html { return get_html() }

1;

=pod

=head1 NAME

OpenInteract2::JHIQuote - Choose a random quote from Jarkko Hietaniemi

=head1 SYNOPSIS

 use OpenInteract2::JHIQuote;
 my ( $quote, $source ) = OpenInteract2::JHIQuote->get;

 # Wrap the $quote to 60 characters
 my ( $quote, $source ) = OpenInteract2::JHIQuote->get_wrapped;

 # These return the same thing
 print "In HTML: ", OpenInteract2::JHIQuote->get_html();
 print "In HTML: ", OpenInteract2::JHIQuote->get_full_html();

=head1 DESCRIPTION

This returns a random quote from Jarkko Hietaniemi.

Thanks to HFB for emailing me the quote file!

=head1 COPYRIGHT

Copyright JHI (his words)

Copyright (c) 2002 Chris Winters (for putting it in this format)

=cut

__DATA__
%%
A vendor abandoning a platform does not mean we have to follow the suit (if anything, we might continue the support just out of spite...)
        --Jarkko Hietaniemi
%%
Alan, will you stop this moment dragging people back from the slave pits I have so generously prepared for them :-)
        --Jarkko Hietaniemi
%%
Damian's been giving people ideas again, that shameless Ozzie.
        --Jarkko Hietaniemi
%%
Disclaimer: I work at the reg*.{  [hc],sym} like a novice alchemist: I pour the blue liquid on the red liquid.  If it doesn't blow up on my face, I proceed to turn up the flame under the blue liquid, and so on. I have very little idea of what I am really doing, I just like the pretty colors :-)
        --Jarkko Hietaniemi
%%
        > Don't fret too much over it just yet, I was merely issuing a heads up.
        fret fret fret.  Isn't that what pumpkings are more or less supposed to do?
        --Jarkko Hietaniemi
%%
Hey, now you've made me feel like a cold heartless bastard :-) I'd prefer an old forgetful fool, though.
        --Jarkko Hietaniemi
%%
Hey, we are Perl programmers, we do only honorable errors. It's the programmers of other languages who get crucified :-)
        --Jarkko Hietaniemi
%%
I can let you in to the ultimate locale secret:
Avoid.
        --Jarkko Hietaniemi
%%
If among you you can't get at least a design done, we should forget about I/O disciplines and I should retire to the Tassili-in-Aijer mountains in Sahara as a camel herder :-)
        --Jarkko Hietaniemi
%%
... if so far I had been happily bouncing around the strange lands of Reg-Ex and shouting back "Dragons?  What dragons?" to people frantically waving their hands (safely beyond the borders, funny that)... now I canattest to nasty monsters being fully alive, and full of flame...
        --Jarkko Hietaniemi
%%
I have this wonderful patch that fixes all the bugs for ever in Perl but unfortunately the margin of this monitor is too narrow to include it.
        --Jarkko Hietaniemi
%%
I'm almost tempted to paraphrase Felix Gallo by saying: "Oh my goodness! Someone left the NickClarkulator on over the weekend!" :-)
        --Jarkko Hietaniemi
%%
I'm currently dodging core dumps falling from the sky, but I think I'm running in generally right direction...
        --Jarkko Hietaniemi
%%
        > I meant ?:, not :? and ??, of course.
        Fooled me :-) Maybe the Perlian sentence modifier style has crept into
        your C...?  I know that I often stare at the C compiler moaning about
        my perfectly sensible 'print "$p\n";'...
        --Jarkko Hietaniemi
%%
It's supposed to become standard.  (Nick, stop waving your hands so frantically :-)
        --Jarkko Hietaniemi
%%
        > I wouldn't call that a fix, I would call it a work-around.
        Please show us what a fix looks like, then...? :-)
        --Jarkko Hietaniemi
%%
        > Let's talk about pseudo-hashes,
        Yes.  They should die.  How's that for a polemic statement? :-)
        --Jarkko Hietaniemi
%%
        (looking at the mirror)
        - Jarkko, did you run vms/vms_yfix.pl after mucking with perly.  [hc]?
        (looking at own toes)
        - Did you or did you not?
        (picking own nose, still staring at own toes)
        - Awww, okay, you did not.
        --Jarkko Hietaniemi
%%
Looks good enough for me.  Then again, I found haggis to be edible :-)
        --Jarkko Hietaniemi
%%
Milking a dromedary -- a highly intelligent and not always good-natured beast -- is, she confesses, "a process of negotiation."
        --Jarkko Hietaniemi
%%
        &more_coffee for 1..3;
        --Jarkko Hietaniemi
%%
No, I don't have any formal theory, any actual code, and much less benchmarks to prove this, I'm just waving my hands to keep warm.
        --Jarkko Hietaniemi
%%
No point shaving in the morning if you are a kamikaze pilot?
        --Jarkko Hietaniemi
%%
Now, stepping off my pedestal, I would file an angry bug report on all the examples Abigal just demonstrated, but I have this sinking feeling of just who would have to fix them :-)
        --Jarkko Hietaniemi
%%
Okay, enough of this idle misguided thought of mine, these are not the droids you are looking for.
        --Jarkko Hietaniemi
%%
        open my $fh, "< :LATIN-0", FABRICATIDIEMPVNC or
            dulce_et_decorum_est_pro_patria_mori $!;
        --Jarkko Hietaniemi
%%
Scratch that.  I need more coffee.
        --Jarkko Hietaniemi
%%
Sentences long extremely and notation Polish reverse in writing about wrong is what?
        --Jarkko Hietaniemi
%%
Simon, meet Peter.  Peter, meet Simon.  Peter, Simon, meet a shared goal. You may engage your keyboard and brain now.
        --Jarkko Hietaniemi
%%
Somehow, strangely, this was already fixed...maybe I did it subconsciously, maybe there are helpful little gnomes running around in the repository and fixing bugs while we sleep, I don't know..
        --Jarkko Hietaniemi
%%
        > So, what happens first?
        I pour myself a cup of strong coffee. :-)
        --Jarkko Hietaniemi
%%
Thanks, applied!
        --Jarkko Hietaniemi
%%
The below seems to fix the bug, just don't ask me why...
        --Jarkko Hietaniemi
%%
[The semantics] are about as clear as mercury, and as about as healthy and easy to pin down too.
        --Jarkko Hietaniemi
%%
This message will self-destruct in a few minutes by being dragged into an endless discussion thread about what features to include.
        --Jarkko Hietaniemi
%%
Uh-oh, I smell an arbitrary number. 
        --Jarkko Hietaniemi
%%
Well, as soon as I fix UTF-8 character classes, but that's another story to scare small children with.
        --Jarkko Hietaniemi
%%
When you have no nails your hammer grows restless, and you begin to throw sideways glances at screws and pieces of string.
        --Jarkko Hietaniemi
%%
Your orthogonal is orthogonal to my orthogonal... Now, can we, orthogonally, get back from semantics and back to doing horribly orthogonal things to the regex engine...? :-)
        --Jarkko Hietaniemi
