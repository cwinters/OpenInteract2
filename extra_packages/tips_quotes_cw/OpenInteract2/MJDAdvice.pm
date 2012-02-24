package OpenInteract2::MJDAdvice;

# $Id: MJDAdvice.pm,v 1.1 2004/06/03 13:04:41 lachoy Exp $

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
            my ( $advice_num, $source );
            my @lines = split( "\n", $quote );
            $source = pop @lines;
            $source =~ s/^\s+//;
            ( $advice_num ) = $source =~ /Advice \#(\d+)/;
            $source =~ s/\s+\(Advice \#\d+\)\s*//;
            push @QUOTES, [ $lines[0], $source, $advice_num ];
        }
}


sub get {
    return @{ $QUOTES[ int( rand( scalar @QUOTES ) ) ] };
}

sub get_wrapped {
    my ( $advice, $source, $advice_num ) = get();
    local $Text::Wrap::columns = 60;
    return ( wrap( undef, undef, $advice ), $source, $advice_num );
}

sub get_html {
    my ( $advice, $source, $advice_num ) = get();
    return join( "<br>\n", HTML::Entities::encode( $advice ),
                           "$source (#$advice_num)" );
}

sub get_full_html {
    my ( $advice, $source, $advice_num ) = get();
    return join( "<br>\n", 'Good advice from <a href="http://perl.plover.com/">Mark Jason Dominus</a>',
                           HTML::Entities::encode( $advice ) . " (#$advice_num)" );
}

1;

=pod

=head1 NAME

OpenInteract2::MJDAdvice - Choose a random piece of advice from MJD

=head1 SYNOPSIS

 use OpenInteract2::MJDAdvice;
 # $source will always be '--Mark Jason Dominus'
 my ( $advice, $source, $advice_num ) = OpenInteract2::MJDAdvice->get;

 print "In HTML: ", OpenInteract2::MJDAdvice->get_html();

 print "With linked attribution: ", OpenInteract2::MJDAdvice->get_full_html();

=head1 DESCRIPTION

This returns a random piece of advice from MJD. Where did this come from? See:

 From: mjd@plover.com (Mark Jason Dominus)<
 Subject: Good Advice and Maxims for Programmers
 Keywords: afro, chiefdom, rosary, winy
 Newsgroups: comp.lang.perl.misc
 Date: Sat, 16 Mar 2002 05:14:05 +0000 (UTC)
 Organization: Plover Systems Co.

=head1 SEE ALSO

The usenet posting from which the entries were retrieved:

 http://groups.google.com/groups?q=%22good+advice+and+maxims%22&hl=en&lr=&ie=UTF-8&selm=a6ukat%24a4b%241%40plover.com&rnum=1

More great words from MJD:

 http://perl.plover.com/

=head1 COPYRIGHT

Copyright (c) 2002 Mark Jason Dominus (for the actual words)

Copyright (c) 2002 Chris Winters (for putting it in this format)

=cut

__DATA__
You cannot just paste code with no understanding of what is going on and expect it to work.
        --Mark Jason Dominus (Advice #11900)
%%
You can't just make shit up and expect the computer to know what you mean, Retardo!
        --Mark Jason Dominus (Advice #11901)
%%
You said it didn't work, but you didn't say what it would have done if it *had* worked.
        --Mark Jason Dominus (Advice #11902)
%%
What are you really trying to accomplish here?
        --Mark Jason Dominus (Advice #11903)
%%
Who the fuck cares which one is faster?
        --Mark Jason Dominus (Advice #11904)
%%
Now is the time in our program where you look at the manual.
        --Mark Jason Dominus (Advice #11905)
%%
Look at the error message!  Look at the error message!
        --Mark Jason Dominus (Advice #11906)
%%
Looking for a compiler bug is the strategy of LAST resort.  LAST resort.
        --Mark Jason Dominus (Advice #11907)
%%
Premature optimization is the root of all evil.
        --Mark Jason Dominus (Advice #11908)
%%
Bad programmer!  No cookie!
        --Mark Jason Dominus (Advice #11909)
%%
I see you omitted $! from the error message.   It won't tell you what went wrong if you don't ask it to.
        --Mark Jason Dominus (Advice #11910)
%%
You wrote the same thing twice here.  The cardinal rule of programming is that you never ever write the same thing twice.
        --Mark Jason Dominus (Advice #11911)
%%
Evidently it's important to you to get the wrong answer as quickly as possible.
        --Mark Jason Dominus (Advice #11912)
%%
Gee, I don't know.  I wonder what the manual says about that?
        --Mark Jason Dominus (Advice #11913)
%%
Well, no duh.  That's because you ignored the error message, dimwit.
        --Mark Jason Dominus (Advice #11914)
%%
Only Sherlock Holmes can debug the program by pure deduction from the output.  You are not Sherlock Holmes.  Run the fucking debugger already.
        --Mark Jason Dominus (Advice #11915)
%%
Always ignore the second error message unless the meaning is obvious.
        --Mark Jason Dominus (Advice #11916)
%%
Read.  Learn.  Evolve.
        --Mark Jason Dominus (Advice #11917)
%%
Well, then get one that *does* do auto-indent.  You can't do good work with bad tools.
        --Mark Jason Dominus (Advice #11918)
%%
No.  You must believe the ERROR MESSAGE.  You MUST believe the error message.
        --Mark Jason Dominus (Advice #11919)
%%
The error message is the Truth.  The error message is God.  
        --Mark Jason Dominus (Advice #11920)
%%
It could be anything.  Too bad you didn't bother to diagnose the error, huh?
        --Mark Jason Dominus (Advice #11921)
%%
You don't suppress error messages, you dumbass, you PAY ATTENTION and try to understand them.
        --Mark Jason Dominus (Advice #11922)
%%
Never catch a signal except as a last resort.
        --Mark Jason Dominus (Advice #11923)
%%
Well, if you don't know what it does, why did you put it in your program?
        --Mark Jason Dominus (Advice #11924)
%%
Gosh, that wasn't very bright, was it?
        --Mark Jason Dominus (Advice #11925)
%%
That's like taking a crap on someone's doorstep and then ringing the doorbell to ask for toilet paper.
        --Mark Jason Dominus (Advice #11926)
%%
A good approach to that problem would be to hire a computer programmer.
        --Mark Jason Dominus (Advice #11927)
%%
First get a book on programming.  Then read it.  Then write the program.
        --Mark Jason Dominus (Advice #11928)
%%
First ask yourself `How would I do this without a computer?'  Then have the computer do it the same way.
        --Mark Jason Dominus (Advice #11929)
%%
Would you like to see my rate card?
        --Mark Jason Dominus (Advice #11930)
%%
I think you are asking the wrong question here.
        --Mark Jason Dominus (Advice #11931)
%%
Holy cow.
        --Mark Jason Dominus (Advice #11932)
%%
Because it's a syntax error.
        --Mark Jason Dominus (Advice #11933)
%%
Because this is Perl, not C.
        --Mark Jason Dominus (Advice #11934)
%%
Because this is Perl, not Lisp.
        --Mark Jason Dominus (Advice #11935)
%%
Because that's the way it is.
        --Mark Jason Dominus (Advice #11936)
%%
Because.
        --Mark Jason Dominus (Advice #11937)
%%
If you have `some weird error', the problem is probably with your frobnitzer.
        --Mark Jason Dominus (Advice #11938)
%%
Because the computer cannot read your mind.  Guess what?  I cannot read your mind *either*.
        --Mark Jason Dominus (Advice #11939)
%%
You said `It doesn't work'.  The next violation will be punished by death.
        --Mark Jason Dominus (Advice #11940)
%%
Of course it doesn't work!  That's because you don't know what you are doing!
        --Mark Jason Dominus (Advice #11941)
%%
Sure, but you have to have some understanding also.
        --Mark Jason Dominus (Advice #11942)
%%
Ah yes, and you are the first person to have noticed this bug since 1987.  Sure.
        --Mark Jason Dominus (Advice #11943)
%%
Yes, that's what it's supposed to do when you say that.
        --Mark Jason Dominus (Advice #11944)
%%
Well, what did you expect?
        --Mark Jason Dominus (Advice #11945)
%%
Perhaps you have forgotten that this is an engineering discipline, not some sort of black magic.
        --Mark Jason Dominus (Advice #11946)
%%
You know, this sort of thing is amenable to experimental observation.
        --Mark Jason Dominus (Advice #11947)
%%
Perhaps your veeblefitzer is clogged.
        --Mark Jason Dominus (Advice #11948)
%%
What happens when you try?
        --Mark Jason Dominus (Advice #11949)
%%
Now you are just being superstitious.  
        --Mark Jason Dominus (Advice #11950)
%%
Your question has exceeded the system limit for pronouns in a single sentence.  Please dereference and try again.
        --Mark Jason Dominus (Advice #11951)
%%
In my experience that is a bad strategy, because the people who ask such questions are the ones who paste the answer into their program without understanding it and then complain that it `does not work'.
        --Mark Jason Dominus (Advice #11952)
%%
Of course, this is a heuristic, which is a fancy way of saying that it doesn't work. 
        --Mark Jason Dominus (Advice #11953)
%%
If your function is written correctly, it will handle an empty array the same way as a nonempty array.
        --Mark Jason Dominus (Advice #11954)
%%
When in doubt, use brute force.
        --Mark Jason Dominus (Advice #11955)
%%
Well, it might be more intuitive that way, but it would also be useless.
        --Mark Jason Dominus (Advice #11956)
%%
Show the code.
        --Mark Jason Dominus (Advice #11957)
%%
The bug is in you, not in Perl.
        --Mark Jason Dominus (Advice #11958)
%%
Cargo-cult.
        --Mark Jason Dominus (Advice #11959)
%%
So you threw in some random punctuation for no particular reason, and then you didn't get the result you expected.  Hmmmm.
        --Mark Jason Dominus (Advice #11960)
%%
How should I know what is wrong when I haven't even seen the code?  I am not clairvoyant.
        --Mark Jason Dominus (Advice #11961)
%%
How should I know how to do what you want when you didn't say what you wanted to do?
        --Mark Jason Dominus (Advice #11962)
%%
It's easy to get the *wrong* answer in O(1) time.
        --Mark Jason Dominus (Advice #11963)
%%
I guess this just goes to show that you can lead a horse to water, but you can't make him drink it.
        --Mark Jason Dominus (Advice #11964)
%%
You are a stupid asshole.  Shut the fuck up.
        --Mark Jason Dominus (Advice #11999)
