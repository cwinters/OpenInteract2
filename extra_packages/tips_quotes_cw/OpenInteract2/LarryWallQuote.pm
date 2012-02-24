package OpenInteract2::LarryWallQuote;

# $Id: LarryWallQuote.pm,v 1.1 2004/06/03 13:04:41 lachoy Exp $

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
    return join( "<br>\n", $quote,  HTML::Entities::encode( $source ) );
}

sub get_full_html { return get_html() }

1;

=pod

=head1 NAME

OpenInteract2::LarryWallQuote - Choose a random quote from Larry Wall

=head1 SYNOPSIS

 use OpenInteract2::LarryWallQuote;
 my ( $qupte, $source ) = OpenInteract2::LarryWallQuote->get;

 # These next two are the same
 print "In HTML: ", OpenInteract2::LarryWallQuote->get_html();
 print "In HTML: ", OpenInteract2::LarryWallQuote->get_full_html();

=head1 DESCRIPTION

This returns a random quote from Larry Wall.

=head1 SEE ALSO

Larry Wall quotes from use.perl: http://use.perl.org/quotes.txt

=head1 COPYRIGHT

Copyright Larry Wall (his words)

Copyright (c) 2002 Chris Winters (for putting it in this format)

=cut

__DATA__
All language designers are arrogant.  Goes with the territory... :-)
        --Larry Wall in <1991Jul13.010945.19157@netlabs.com
%%
Although the Perl Slogan is There's More Than One Way to Do It, I hesitate to make 10 ways to do something.  :-)
        --Larry Wall in <9695@jpl-devvax.JPL.NASA.GOV>
%%
        > Am I correct that perl5-porters is the proper forum for submitting
        > my ideas?
        I think you didn't get a reply because you used the terms "correct" and
        "proper", neither of which has much meaning in Perl culture. :-)
        --Larry Wall
%%
And don't tell me there isn't one bit of difference between null and space, because that's exactly how much difference there is.  :-)
        --Larry Wall in <10209@jpl-devvax.JPL.NASA.GOV>
%%
And I don't like doing silly things (except on purpose).
        --Larry Wall in <1992Jul3.191825.14435@netlabs.com>
%%
        : And it goes against the grain of building small tools.
        Innocent, Your Honor.  Perl users build small tools all day long.
        --Larry Wall in <1992Aug26.184221.29627@netlabs.com>
%%
        /* And you'll never guess what the dog had */
        /*   in its mouth... */
        --Larry Wall in stab.c from the perl source code
%%
Anyway, there's plenty of room for doubt.  It might seem easy enough, but computer language design is just like a stroll in the park.
Jurassic Park, that is.
        --Larry Wall in <1994Jun15.074039.2654@netlabs.com>
%%
Because . doesn't match \n.  [\0-\377] is the most efficient way to match everything currently.  Maybe \e should match everything.  And \E would of course match nothing.   :-)
        --Larry Wall in <9847@jpl-devvax.JPL.NASA.GOV>
%%
Be consistent.
        --Larry Wall in the perl man page
%%
Besides, including <std_ice_cubes.h> is a fatal error on machines that don't have it yet.  Bad language design, there...  :-)
        --Larry Wall in <1991Aug22.220929.6857@netlabs.com>
%%
Besides, I wasn't trying to help them understand. I was only trying to help them think they understand.
        --Larry Wall
%%
Besides, it's good to force C programmers to use the toolbox occasionally. :-)
        --Larry Wall in <1991May31.181659.28817@jpl-devvax.jpl.nasa.gov>
%%
Besides, REAL computers have a rename() system call.    :-)
        --Larry Wall in <7937@jpl-devvax.JPL.NASA.GOV>
%%
        break;                          /* don't do magic till later */
            --Larry Wall in stab.c from the perl source code
%%
But you have to allow a little for the desire to evangelize when you think you have good news.
            --Larry Wall in <1992Aug26.184221.29627@netlabs.com>
%%
Chip Salzenberg sent me a complete patch to add System V IPC (msg, sem and shm calls), so I added them.  If that bothers you, you can always undefine them in config.sh.  :-)
        --Larry Wall in <9384@jpl-devvax.JPL.NASA.GOV>
%%
        /* dbmrefcnt--;  */     /* doesn't work, rats */
        --Larry Wall in hash.c from the perl source code
%%
        #define NULL 0           /* silly thing is, we don't even use this */
        --Larry Wall in perl.c from the perl source code
%%
        #define SIGILL 6         /* blech */
        --Larry Wall in perl.c from the perl source code
%%
Does the same as the system call of that name. If you don't know what it does, don't worry about it.
            --Larry Wall in the perl man page regarding chroot(2)
%%
        double value;                /* or your money back! */
        short changed;               /* so triple your money back! */
        --Larry Wall in cons.c from the perl source code
%%
Down that path lies madness.  On the other hand, the road to hell is paved with melting snowballs.
        --Larry Wall in <1992Jul2.222039.26476@netlabs.com>
%%
        : Do you want perl everywhere or not?
        No, sometimes I just want it nearby.
        --Larry Wall
%%
        echo "Congratulations.  You aren't running Eunice."
        --Larry Wall in Configure from the perl distribution
%%
        echo "Hmmm...you don't have Berkeley networking in libc.a..."
        echo "but the Wollongong group seems to have hacked it in."
        --Larry Wall in Configure from the perl distribution
%%
        echo "ICK, NOTHING WORKED!!!  You may have to diddle the includes.";;
        --Larry Wall in Configure from the perl distribution
%%
        echo $package has manual pages available in source form.
        echo "However, you don't have nroff, so they're probably useless to you."
        --Larry Wall in Configure from the perl distribution
%%
        echo "Your stdio isn't very std."
        --Larry Wall in Configure from the perl distribution
%%
        #else /* !STDSTDIO */     /* The big, slow, and stupid way */
        --Larry Wall in str.c from the perl source code
%%
[End of diatribe.  We now return you to your regularly scheduled programming...]
        --Larry Wall in Configure from the perl distribution
%%
Even if you aren't in doubt, consider the mental welfare of the person who has to maintain the code after you, and who will probably put parens in the wrong place.
        --Larry Wall in the perl man page
%%
"Help save the world!"
        --Larry Wall in README
%%
Here is Perl. It's yours. It's everybody's. It's part of Unix. Use it as appropriate.
        --Larry Wall
%%
Hey, I had to let awk be better at *something*...  :-)
        --Larry Wall in <1991Nov7.200504.25280@netlabs.com>
%%
Hmm. Y'know, there are other possibilities if we assume that filenames are UTF-8...yikes...wait, put down that meat cleaver! Aieeee!!!
        --Larry Wall
%%
I already have too much problem with people thinking the efficiency of a perl construct is related to its length.  On the other hand, I'm perfectly capable of changing my mind next week...  :-)
        --lwall
%%
I create nice things...because it pleases the Author of my story.
        --Larry Wall
%%
I don't know if it's what you want, but it's what you get.  :-)
        --Larry Wall in <10502@jpl-devvax.JPL.NASA.GOV>
%%
I do quarrel with logic that says, "Stupid people are associated with X, therefore X is stupid." Stupid people are associated with everything.
        --Larry Wall
%%
I dunno, I dream in Perl sometimes...
        --Larry Wall in  <8538@jpl-devvax.JPL.NASA.GOV>
%%
I expect people to expect Perl to do the right thing.
        --Larry Wall in <199911192358.PAA24109@kiev.wall.org>

Did I say I expect Perl to do the right thing?  :-)
        --Larry Wall in <199911200217.SAA24898@kiev.wall.org>
%%
If history teaches us anything, it's that everyone will be part of the problem, but not everyone will be part of the solution.
        --Larry Wall
%%
If I allowed "next $label" then I'd also have to allow "goto $label", and I don't think you really want that...  :-)
        --Larry Wall in <1991Mar11.230002.27271@jpl-devvax.jpl.nasa.gov>
%%
If I don't document something, it's usually either for a good reason, or a bad reason.  In this case it's a good reason.  :-)
        --Larry Wall in <1992Jan17.005405.16806@netlabs.com>
%%
        "I find this a nice feature but it is not according to the documentation. Or is it a BUG?"
        "Let's call it an accidental feature. :-)"
        --Larry Wall in <6909@jpl-devvax.JPL.NASA.GOV>
%%
I have to do some "real work" now, so don't write anything interesting. :-)
        --Larry Wall
%%
        if (instr(buf,sys_errlist[errno]))  /* you don't see this */
        --Larry Wall in eval.c from the perl source code
%%
        if (rsfp = mypopen("/bin/mail root","w")) {     /* heh, heh */
        --Larry Wall in perl.c from the perl source code
%%
If you consistently take an antagonistic approach, however, people are going to start thinking you're from New York.   :-)
        --Larry Wall to Dan Bernstein in <10187@jpl-devvax.JPL.NASA.GOV>
%%
If you want to program in C, program in C.  It's a nice language.  I use it occasionally...   :-)
        --Larry Wall in <7577@jpl-devvax.JPL.NASA.GOV>
%%
If you want to see useful Perl examples, we can certainly arrange to have comp.lang.misc flooded with them, but I don't think that would help the advance of civilization.  :-)
        --Larry Wall in <1992Mar5.180926.19041@netlabs.com>
%%
If you want your program to be readable, consider supplying the argument.
        --Larry Wall in the perl man page
%%
I know it's weird, but it does make it easier to write poetry in perl. :-)
        --Larry Wall in <7865@jpl-devvax.JPL.NASA.GOV>
%%
I like my Sarathy.  I'll let you play with him if you're nice.
        --Larry Wall
%%
I'll say it again for the logic impaired.
        --Larry Wall
%%
I might be able to shoehorn a reference count in on top of the numeric value by disallowing multiple references on scalars with a numeric value,  but it wouldn't be as clean.  I do occasionally worry about that.
        --lwall
%%
I'm not opposed to run-time solutions--I've used them often enough in the past. But I'd really like to avoid creating yet another layer of OO. There's only so much polymorphism that a language can put up with before it turns into Python.
        --Larry Wall
%%
I'm sure that that could be indented more readably, but I'm scared of the awk parser.
        --Larry Wall in <6849@jpl-devvax.JPL.NASA.GOV>
%%
In general, if you think something isn't in Perl, try it out, because it usually is.  :-)
        --Larry Wall in <1991Jul31.174523.9447@netlabs.com>
%%
In general, they do what you want, unless you want consistency.
        --Larry Wall in the perl man page
%%
Interestingly enough, since subroutine declarations can come anywhere, you wouldn't have to put BEGIN {} at the beginning, nor END {} at the end.  Interesting, no?  I wonder if Henry would like it. :-)
        --lwall
%%
I think it's a new feature.  Don't tell anyone it was an accident.  :-)
        --Larry Wall on s/foo/bar/eieio in <10911@jpl-devvax.JPL.NASA.GOV>
%%
I think you'll find that, while we all know what it should have been, we all know it should have been something different from what everybody else thinks it should have been.
        --Larry Wall
%%
"It is easier to port a shell than a shell script."
        --Larry Wall
%%
It is, of course, written in Perl.  Translation to C is left as an exercise for the reader.  :-)
        --Larry Wall in <7448@jpl-devvax.JPL.NASA.GOV>
%%
It's all magic.  :-)
        --Larry Wall in <7282@jpl-devvax.JPL.NASA.GOV>
%%
It's documented in The Book, somewhere...
        --Larry Wall in <10502@jpl-devvax.JPL.NASA.GOV>
%%
It's easier to fix a broken spec than 10,000 broken programs.
        --Larry Wall
%%
It's not really a rule--it's more like a trend.
        --Larry Wall
%%
        > (It's sorta like sed, but not.  It's sorta like awk, but not.  etc.)
        Guilty as charged.  Perl is happily ugly, and happily derivative.
        --Larry Wall in <1992Aug26.184221.29627@netlabs.com>
%%
It's the Magic that counts.
        --Larry Wall on Perl's apparent ugliness
%%
It's there as a sop to former Ada programmers.  :-)
        --Larry Wall regarding 10_000_000 in <11556@jpl-devvax.JPL.NASA.GOV>
%%
It won't be covered in the book.  The source code has to be useful for something, after all...  :-)
        --Larry Wall in <10160@jpl-devvax.JPL.NASA.GOV>
%%
        :  I've heard that there is a shell (bourne or csh)  to perl filter, does
        :  anyone know of this or where I can get it?
        Yeah, you filter it through Tom Christiansen.  :-)
        --Larry Wall
%%
        :       I've tried (in vi) "g/[a-z]\n[a-z]/s//_/"...but that doesn't
        : cut it.  Any ideas?  (I take it that it may be a two-pass sort of solution).
        In the first pass, install perl. :-)
        --Larry Wall <6849@jpl-devvax.JPL.NASA.GOV>
%%
I won't mention any names, because I don't want to get sun4's into trouble...  :-)
        --Larry Wall in <11333@jpl-devvax.JPL.NASA.GOV>
%%
Just don't compare it with a real language, or you'll be unhappy...  :-)
        --Larry Wall in <1992May12.190238.5667@netlabs.com>
%%
Just don't create a file called -rf.  :-)
        --Larry Wall in <11393@jpl-devvax.JPL.NASA.GOV>
%%
        last|perl -pe '$_ x=/(..:..)...(.*)/&&"'$1'"ge$1&&"'$1'"lt$2'
        That's gonna be tough for Randal to beat...  :-)
        --Larry Wall in  <1991Apr29.072206.5621@jpl-devvax.jpl.nasa.gov>
%%
Let's say the docs present a simplified view of reality...    :-)
        --Larry Wall in  <6940@jpl-devvax.JPL.NASA.GOV>
%%
Let us be charitable, and call it a misleading feature  :-)
        --Larry Wall in <2609@jato.Jpl.Nasa.Gov>
%%
Life gets boring, someone invents another necessity, and once again we turn the crank on the screwjack of progress hoping that nobody gets screwed.
        --Larry Wall in <199705101952.MAA00756@wall.org>
%%
Lispers are among the best grads of the Sweep-It-Under-Someone-Else's-Carpet School of Simulated Simplicity.  [Was that sufficiently incendiary?  :-)]
        --Larry Wall in <1992Jan10.201804.11926@netlabs.com
%%
Live and let learn, that's my policy.
        --Larry Wall
%%
May you do Good Magic with Perl.
        --Larry Wall's blessing
%%
Much as I hate to say it, the Computer Science view of language design has gotten too inbred in recent years. The Computer Scientists should pay more attention to the Linguists, who have a much better handle on how people prefer to communicate.
        --Larry Wall
%%
No, I'm not going to explain it.  If you can't figure it out, you didn't want to know anyway...  :-)
        --Larry Wall in <1991Aug7.180856.2854@netlabs.com>
%%
No prisoner's dilemma here.  Over the long term, symbiosis is more useful than parasitism.  More fun, too.  Ask any mitochondria.
        --Larry Wall in <199705102042.NAA00851@wall.org>
%%
        /* now make a new head in the exact same spot */
        --Larry Wall in cons.c from the perl source code
%%
Obviously I was either onto something, or on something.
        --Larry Wall on the creation of Perl
%%
Oh, get ahold of yourself. Nobody's proposing that we parse English.
        --Larry Wall
%%
OK, enough hype.
        --Larry Wall in the perl man page
%%
        OOPS!  You naughty creature!  You didn't run Configure with sh!
        I will attempt to remedy the situation by running sh for you...
        --Larry Wall in Configure from the perl distribution
%%
Optimizations always bust things, because all optimizations are, in the long haul, a form of cheating, and cheaters eventually get caught.
        --Larry Wall
%%
People get annoyed when you try to debug them.
        --Larry Wall
%%
People understand instinctively that the best way for computer programs to communicate with each other is for each of the them to be strict in what they emit, and liberal in what they accept. The odd thing is that people themselves are not willing to be strict in how they speak, and liberal in how they listen.  You'd think that would also be obvious.
        --Larry Wall
%%
Perl is designed to give you several ways to do anything, so consider picking the most readable one.
        --Larry Wall in the perl man page
%%
Perl is, in intent, a cleaned up and summarized version of that wonderful semi-natural language known as "Unix".
        --Larry Wall in <1994Apr6.184419.3687@netlabs.com>
%%
[Perl is] more like a tank than a mine field. It may be ugly, but it shoots straight and gets you where you're going, if you don't mind a few squashed daisies.
        --Larry Wall
%%
Perl isn't really about safety. It's about getting where you're going, and enjoying the trip. It's more important to be a good driver than to have seven feet of sponge rubber all around your car.
        --Larry Wall
%%
Perl itself is usually pretty good about telling you what you shouldn't do. :-)
        --Larry Wall in <11091@jpl-devvax.JPL.NASA.GOV>
%%
Perl programming is an *empirical* science!
        --Larry Wall in <10226@jpl-devvax.JPL.NASA.GOV>
%%
        pos += screamnext[pos]  /* does this goof up anywhere? */
        --Larry Wall in util.c from the perl source code
%%
P.S. Perl's master plan (or what passes for one) is to take over the world like English did.  Er, *as* English did...
        --Larry Wall in <199705201832.LAA28393@wall.org>
%%
        Q. Why is this so clumsy?
        A. The trick is to use Perl's strengths rather than its weaknesses.
        --Larry Wall in <8225@jpl-devvax.JPL.NASA.GOV>
%%
Randal said it would be tough to do in sed.  He didn't say he didn't understand sed.  Randal understands sed quite well.  Which is why he uses Perl.   :-)
        --Larry Wall in <7874@jpl-devvax.JPL.NASA.GOV>
%%
Real programmers can write assembly code in any language.   :-)
        --Larry Wall in  <8571@jpl-devvax.JPL.NASA.GOV>
%%
Remember that the temperature at which frogs actually boil has been going up over time, in accordance with Moore's law.
        --Larry Wall
%%
Remember though that THERE IS NO GENERAL RULE FOR CONVERTING A LIST INTO A SCALAR.
        --Larry Wall in the perl man page
%%
        s = (char*)(long)retval;                /* ouch */
        --Larry Wall in doio.c from the perl source code
%%
        s = (char*)retval; /* ouch */
        --Larry Wall in pp_sys.c from the perl source code
%%
        signal(i, SIG_DFL); /* crunch, crunch, crunch */
        --Larry Wall in doarg.c from the perl source code
%%
Some [people] feel that the best way to improve Perl would be to go back in time and shoot the author before he wrote it.
        --Larry Wall
%%
Sorry.  My testing organization is either too small, or too large, depending on how you look at it.  :-)
        --Larry Wall in <1991Apr22.175438.8564@jpl-devvax.jpl.nasa.gov>
%%
        stab_val(stab)->str_nok = 1;    /* what a wonderful hack! */
        --Larry Wall in stab.c from the perl source code
%%
Stability is often more correct than correctness.
        --Larry Wall
%%
        str->str_pok |= SP_FBM;                     /* deep magic */
        s = (unsigned char*)(str->str_ptr);         /* deeper magic */
        --Larry Wall in util.c from the perl source code
%%
Tactical?  TACTICAL!?!?  Hey, buddy, we went from kilotons to megatons several minutes ago.  We don't need no stinkin' tactical nukes. (By the way, do you have change for 10 million people?)
        --lwall
%%
Tell you what. Let's just issue a mandatory warning at the startup of every Perl script that says: "Don't be stupid."
        --Larry Wall
%%
That means I'll have to use $ans to suppress newlines now. Life is ridiculous.
        --Larry Wall in Configure from the perl distribution
%%
The autodecrement is not magical.
        --Larry Wall in the perl man page
%%
The computer should be doing the hard work. That's what it's paid to do, after all. The fact that it takes a little hard work from the programmer to make the computer do hard work should not be a consideration when the payoff is big.
        --Larry Wall
%%
The Golden Gate wasn't our fault either, but we still put a bridge across it.
        --Larry Wall
%%
The language Unix is vastly more inconsistent than the language Perl. And guaranteed to remain that way, forever and ever, amen.
        --Larry Wall
%%
The only disadvantage I see is that it would force everyone to get Perl. Horrors.  :-)
        --Larry Wall in  <8854@jpl-devvax.JPL.NASA.GOV>
%%
        *** The previous line contains the naughty word "$&".\n
                if /(ibm|apple|awk)/;      # :-)
        --Larry Wall in the perl man page
%%
There ain't nothin' in this world that's worth being a snot over.
        --Larry Wall in <1992Aug19.041614.6963@netlabs.com>
%%
There are many times when you want it to ignore the rest of the string just like atof() does.  Oddly enough, Perl calls atof().  How convenient.  :-)
        --Larry Wall in <1991Jun24.231628.14446@jpl-devvax.jpl.nasa.gov>
%%
There are probably better ways to do that, but it would make the parser more complex. I do, occasionally, struggle feebly against complexity...  :-)
        --Larry Wall in <7886@jpl-devvax.JPL.NASA.GOV>
%%
There are still some other things to do, so don't think if I didn't fix your favorite bug that your bug report is in the bit bucket.  (It may be, but don't think it.  :-)
        --Larry Wall in <7238@jpl-devvax.JPL.NASA.GOV>
%%
There is, however, a strange, musty smell in the air that reminds me of something...hmm...yes...I've got it...there's a VMS nearby, or I'm a Blit.
        --Larry Wall in Configure from the perl distribution
%%
There's often more than one correct thing.
There's often more than one right thing.
There's often more than one obvious thing.
        --Larry Wall
%%
The Three Great Virtues of a Programmer
Laziness
The quality that makes you go to the great effort to reduce overall energy expenditure. It makes you write labor-saving programs that other people will find useful, and document what you wrote so you don't have to answer so many questions about it. Hence, the first great virtue of a programmer.
Impatience
The anger you feel when the computer is being lazy. This makes you write programs that don't just react to your needs, but actually anticipate them. Or at least pretend to. Hence, the second great virtue of a programmer.
Hubris
Excessive pride, the sort of thing Zeus zaps you for. Also the quality that makes you write (and maintain) programs that other people won't want to say bad things about. Hence, the third great virute of a programmer.
        --Larry Wall and Randal L. Schwartz, Programming Perl
%
%%
        /* This bit of chicanery makes a unary function followed by
           a parenthesis into a function with one argument, highest precedence. */
        --Larry Wall in toke.c from the perl source code
%%
...this does not mean that some of us should not want, in a rather dispassionate sort of way, to put a bullet through csh's head.
        --Larry Wall in <1992Aug6.221512.5963@netlabs.com>
%%
        > This made me wonder, suddenly: can telnet be written in perl?
        Of course it can be written in Perl.  Now if you'd said nroff,
        that would be more challenging...
        --Larry Wall
%%
Though I'll admit readability suffers slightly...
        --Larry Wall in <2969@jato.Jpl.Nasa.Gov>
%%
        tmps_base = tmps_max;                /* protect our mortal string */
        --Larry Wall in stab.c from the perl source code
%%
Unfortunately, some systems are so far gone that their csh doesn't even have an eval. In such cases, immediate and radical amputation of the power cord is the only recourse.
        --Larry Wall
%%
Unix is like a toll road on which you have to stop every 50 feet to pay another nickel.  But hey!  You only feel 5 cents poorer each time.
        --Larry Wall in <1992Aug13.192357.15731@netlabs.com>
%%
We all agree on the necessity of compromise.  We just can't agree on  when it's necessary to compromise.
        --Larry Wall in  <1991Nov13.194420.28091@netlabs.com>
%%
        /* we have tried to make this normal case as abnormal as possible */
        --Larry Wall in cmd.c from the perl source code
%%
Well, enough clowning around. Perl is, in intent, a cleaned up and summarized version of that wonderful semi-natural language known as "Unix".
        --Larry Wall in <1994Apr6.184419.3687@netlabs.com>
%%
What about WRITING it first and rationalizing it afterwords?  :-)
         --Larry Wall in <8162@jpl-devvax.JPL.NASA.GOV>
%%
        : 1.  What is the possibility of this being added in the future?
        In the near future, the probability is close to zero.  In the distant
        future, I'll be dead, and posterity can do whatever they like...  :-)
        --lwall
%%
What is the sound of Perl?  Is it not the sound of a wall that people have stopped banging their heads against?
        --Larry Wall in <1992Aug26.184221.29627@netlabs.com>
%%
When in doubt, parenthesize.  At the very least it will let some poor schmuck bounce on the % key in vi.
        --Larry Wall in the perl man page
%%
        You can't have filenames longer than 14 chars.
        You can't even think about them!
        --Larry Wall in Configure from the perl distribution
%%
        : Why Bible quotes exclusively?  What happened to the Eastern
        : religions?
        I'm still working on the Unicode mods.
        --Larry Wall
%%
Why would anyone want to write a Scheme intepreter in Perl?
        --Felix Lee
Madness.
        --Larry Wall
%%
You can never entirely stop being what you once were. That's why it's important to be the right person today, and not put it off till tomorrow.
        --Larry Wall
%%
You have to admit that it's difficult to misplace the Perl sources.  :-)
        --Larry Wall in <1992Aug26.184221.29627@netlabs.com>
%%
You'll be relieved to know that I have no opinion on it.  :-)
        --Larry Wall
%%
Your csh still thinks true is false.  Write to your vendor today and tell them that next year Configure ought to "rm /bin/csh" unless they fix their blasted shell. :-)
        --Larry Wall in Configure from the perl distribution
%%
You want it in one line?  Does it have to fit in 80 columns?   :-)
        --Larry Wall in <7349@jpl-devvax.JPL.NASA.GOV>
