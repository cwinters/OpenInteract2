package OpenInteract2::RandomQuote;

# $Id: RandomQuote.pm,v 1.2 2004/11/28 04:27:50 lachoy Exp $

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
            my ( $source );
            if ( $lines[-1] =~ /^\s+\-\-/ ) {
                $source = pop @lines ;
                $source =~ s/^\s+//;
            }
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
    return ( $source )
             ? join( "<br>\n", $quote,  HTML::Entities::encode( $source ) )
             : $quote;
}

sub get_full_html { return get_html() }

1;

=pod

=head1 NAME

OpenInteract2::RandomQuote - Choose a random quote

=head1 SYNOPSIS

 use OpenInteract2::RandomQuote;
 my ( $qupte, $source ) = OpenInteract2::RandomQuote->get;

 # These next two are the same
 print "In HTML: ", OpenInteract2::RandomQuote->get_html();
 print "In HTML: ", OpenInteract2::RandomQuote->get_full_html();

=head1 DESCRIPTION

This returns a random quote from any number of sources. Many of them
are programming or technology related, but many are not.

=head1 COPYRIGHT

Copyright The original speakers

Copyright (c) 2002 Chris Winters (for putting it in this format)

=cut

__DATA__
I've figured out the boy's punishment.  First, he's grounded.  No leaving the house, not even for school.  Second, no eggnog.  In fact, no nog, period.  And third, absolutely no stealing for three months.
        -- Homer Simpson, "Marge Be Not Proud"
%%
No doubt this was all meant to be edgy and ironic, but show me a man who complains about everything and I won't be impressed by his sharply honed urban sensibilities -- I'll just think he's been spending too much time with my grandmother.
        -- Jennifer Weiner (http://www.salon.com/ent/feature/1999/09/11/mtv_video/index1.html)
%%
If all else fails, immortality can always be assured by spectacular error.
        -- John Kenneth Galbraith
%%
From now on, 'TGIF' will stand for 'Thank Goodness I'm Freaky'!
        -- Gonzo
%%
No parachute? Wow! This is so cool!
        -- Gonzo
%%
On being told the world is about to end: "there's so many things I wanted to do...like frizz my hair and buy some new shooooes!"
        -- Gonzo
%%
        Gonzo: I want to go to Bombay India and become a movie star.
        Fozzie: You don't go to Bombay to become a movie star. You go where we're  going, Hollywood.
        Gonzo: Sure, if you wanna do it the easy way.
%%
That's right. [If we had the map] We'd be out searching for the treasure, sailing the seas on a five year mission, boldly going where no man has gone before...say, that's catchy.
        -- Gonzo
%%
Oh, I tell ya, Camilla, great plumbers are born, not made! I'm the prince  of plungers, fair maiden!
        -- Gonzo
%%
...sometimes late at night when I'm all alone, I wash my socks in club soda to make my feet fizz.
        -- Gonzo
%%
        Rizzo: Captured by crazed wild boars and about to be sacrificed hideously  before a pagan altar!
        Gonzo: Are we lucky or what?
%%
        Lady Nancy Astor: Winston, if you were my husband, I'd put poison in your coffee.
        Winston Churchill: Nancy, if you were my wife, I'd drink it.
%%
Beware of bugs in the above code; I have only proved it correct, not tried it.
        -- Donald E. Knuth
%%
I think that to try to own knowledge, to try to control whether people are allowed to use it, or to try to stop other people from sharing it, is sabotage. It is an activity that benefits the person that does it at the cost of impoverishing all of society. One person gains one dollar by destroying two dollars' worth of wealth. I think a person with a conscience wouldn't do that sort of thing except perhaps if he would otherwise die.
        -- Richard M. Stallman
%%
Beer is proof that God loves us and wants us to be happy.
        -- Benjamin Franklin
%%
When you use some wickedly cool and obscure feature of the language,  you reduce the number of potential readers of your code.  
        -- Paul Prescod
%%
If you don't understand how things are connected, the cause of problems is solutions.
        -- Amory B. Lovins
%%
If they think you're crude, go technical; if they think you're technical, go crude. I'm a very technical boy. So I decided to get as crude as possible. These days, though, you have to be pretty technical before you can even aspire to crudeness.
        -- William Gibson, "Johnny Mnemonic"
%%
Due to pollution, cars pose a mortal threat to the security of every nation.
        -- Senator Al Gore, from his 1992 book, "Earth in the Balance"
%%
Cars have freed the American spirit and given us the chance to chase our dreams.
        -- Vice President Al Gore in a 1999 speech to the Economic Club of Detroit.
%%
Never criticize anybody until you have walked a mile in their shoes, because by that time you will be a mile away and have their shoes.
        -- email sig, Brian Servis
%%
Don't ask for permission. Just do it! It's easier to apologize for  having done something than it is to get permission to do it.
        -- Admiral Grace Hopper
%%
I have always wished that my computer would be as easy to use as my telephone.  My wish has come true.  I no longer know how to use my telephone.
        -- Bjarne Stroustrup
%%
Consulting: the art of calling someone a "fucking idiot" without using the word "fucking" or the word "idiot."
        -- Donald B. Marti Jr.
%%
As for systems that are not like Unix, such as MSDOS, Windows, the Macintosh, VMS, and MVS, supporting them is usually so much work that it is better if you don't.
        -- Richard Stallman "GNU Coding Standards"
%%
A computer lets you make more mistakes faster than any invention in human history, with the possible exceptions of handguns and tequila.
        -- Mitch Ratcliffe, Technology Review, April 1992 
%%
Why has every man a conscience then? I think that we should be men first, and subjects afterward. It is not desirable to cultivate a respect for the law, so much as for the right. The only obligation which I have a right to assume is to do at any time what I think right.  It is truly enough said that a corporation has no conscience; but a corporation of conscientious men is a corporation with a conscience. Law never made men a whit more just; and, by means of their respect for it, even the well-disposed are daily made the agents of injustice.
        -- Henry David Thoreau, "Civil Disobedience"
%%
First they ignore you. Then they laugh at you. Then they fight you. Then you win.
        -- Gandhi
%%
UPDATE: OUR PLAN HAS FAILED STOP JOHN DENVER IS NOT TRULY DEAD STOP HE LIVES ON IN HIS MUSIC STOP PLEASE ADVISE FULL STOP
        -- Nick Moffitt
%%
Connect and let go.  That's flirting.  Don't connect then forget to let go.  That's stalking.
        -- Ginie Sayles
%%
There is nothing in the world more helpless and irresponsible and depraved than a man in the depths of an ether binge.
        -- Dr. Hunter S. Thompson
%%
Strange memories on this nervous night in Las Vegas.  Five years later?  Six?  It seems like a lifetime, or at least a Main Era -- the kind of peak that never comes again.  San Francisco in the middle sixties was a very special time and place to be a part of.  Maybe it meant something.  Maybe not, in the long run...  There was madness in any direction, at any hour.  If not across the Bay, then up the Golden Gate or down 101 to Los Altos or La Honda...  You could strike sparks anywhere. There was a fantastic universal sense that whatever we were doing was right, that we were winning...

And that, I think, was the handle -- that sense of inevitable victory over the forces of Old and Evil.  Not in any mean or military sense; we didn't need that. Our energy would simply prevail.  There was no point in fighting -- on our side or theirs.  We had all the momentum; we were riding the crest of a high and beautiful wave.  So now, less than five years later, you can go up on a steep hill in Las Vegas and look West, and with the right kind of eyes you can almost see the high-water mark -- that place where the wave finally broke and rolled back.
        -- Dr. Hunter S. Thompson
%%
Every now and then, when your life gets complicated and the weasels start closing in, the only cure is to load up on heinous chemicals and then drive like a bastard from Hollywood to Las Vegas ... with the music at top volume and at least a pint of ether.
        -- Hunter S. Thompson, "Fear and Loathing in Las Vegas"
%%
A calmness came over me when I realized computers were just like any other machine. They just don't have grease all over them.
        -- Bill Schoolcraft
%%
ACHTUNG!!!

Das machine is nicht fur gefingerpoken und mittengrabben.  Ist easy schnappen der springenwerk, blowenfusen und corkenpoppen mit spitzensparken.  Ist nicht fur gewerken by das dummkopfen.  Das rubbernecken sightseeren keepen hands in das pockets.  Relaxen und vatch das blinkenlights!!!
%%
Love is like a snowmobile flying over the frozen tundra that suddenly flips, pinning you underneath. At night, the ice weasels come.
        -- Matt Groening
%%
UNIX was not designed to stop you from doing stupid things, because that would also stop you from doing clever things.
        -- Doug Gwyn
%%
"Elegance?" 
"Pardon me, Your Honor, the concept is not easy to explain--there is
an ineffable quality to some technology, described by its creators as
a concinnitous, or technically sweet, or a nice hack--signs that it
was made with great care by one who was not merely motivated but
inspired.  It is the difference between an engineer and a hacker."
        -- Judge Fang and Miss Pao in Neal Stephenson's The Diamond Age, or, A Young Lady's Illustrated Primer
%%
Shut up, be happy. The conveniences you demanded are now mandatory.
        -- Jello Biafra
%%
We had to disable that for security.
        -- System Administrator's Excuse Handbook
%%
No country with a McDonald's outlet has ever gone to war with another.
        -- James Langton
%%
Same sudden on unseen lips.  None unseen. Bones on key on mod on preying in on never out. Feet fade if same hands nohow.  Ill seen worsen unseen.  Know knowing same seen none.  None same same hand unseen.  Somehow boundless old same still somehow unpack.
        -- from the output of perl2beckett < rsa_in_5_lines_of_perl
%%
I am an enchanted fortune program.  chmod u+s /usr/games/fortune and  I will give you three wishes.
%%
Opportunity is missed by most people because it is dressed in overalls and looks like work.
        -- Thomas Edison
%%
I pity the fool ... wait, that fool is me!
        -- Nat Torkington (http://use.perl.org/~gnat/journal/2907)
%%
The trouble with the world is that the stupid are cocksure and the intelligent are full of doubt.
        -- Bertrand Russell
%%
Luck is the residue of design.
        -- Branch Rickey
%%
There are two ways of constructing a software design. One way is to make it so simple that there are obviously no deficiencies. And the other way is to make it so complicated that there are no obvious deficiencies.
        -- C.A.R. Hoare
%%
From an RDBMS perspective, nullable columns in your primary key are pretty gackish, even if the particular database _does_ support it. You're saying "I need this thing to be able to uniquely identify an entity, but it's OK if it isn't there." That gives me quite a bit of cognitive dissonance 8^})
        -- http://www.kpi.com.au/jawsarchive/0006/0098.html
%%
Useless use of time in void context.
        -- .sig of John Porter (jdporter@min.net)
%%
To the untrained eye, it might seem that I made a couple of feature additions after freeze to the panel today. No, they were bugfixes, I swear (all cool and easily implementable features magically become bugfixes during freeze time, I can't explain this phenomenon, but it just happens).
        -- vicious, diary entry from www.advogato.org, 7 Mar 2001
%%
I'd argue that the coming decade shares much with Bob Metcalfe's "best efforts" networking system, Ethernet, developed at PARC, which Alan Kay called "one of the great finesses of all time, an object lesson in how to make something work when you don't know how to make it work well."
        -- Steve Champeon (http://www.oreillynet.com/pub/a/mac/2001/03/30/sxsw.html)
%%
Comparing infomration and knowledge is like asking whether the fatness of a pig is more or less green than the designated hitter rule.
        -- David Guaspari  (quoted in "The Java Programming Language", p. 562.)
%%
Make easy things easy, hard things possible.
        -- Perl motto
%%
Good, fast, cheap -- pick two.
        -- Realistic programmer motto
%%
Keep things simple until they need to be complex.
        -- Unknown
%%
Optimize for the norm, not for the exception.
        -- Unknown
%%
Always remember that different people optimize for different qualities at different times -- something that's blindingly obvious to you might also be for them, but since they're optimizing for something else they don't really care. Ask: "What do you want to do?"
        -- Chris Winters
%%
Ripples travel faster in a connected medium.
        -- Unknown
%%
Things that are constrained need to know their boundaries before you can handle them. For instance, if a product can only be purchased a certain way, you need to know the purchase method *before* choosing the product. This is basic usability stuff, and people expect computers to simply "know" this.
        -- Chris Winters
%%
An operating system is just a name you give the features you left out of your editor.
        -- Per Abrahamsen in comp.emacs
%%
Job security begins with C. It has no memory management model except what grows in the programmer's head. This programmer cannot be fired.
        --Mark-Jason Dominus, on EFNet #perl, 19 July 1999
%%
Free software projects without good input filtering of ideas turn into bloated sludge. Egcs has good filtering (you should hear some of the things people say about the Cygnus guys after they get told "no" a few times ;)) so it works.
        --Alan Cox
%%
Sometimes you have to make products just because they are cool.
        --Larry Augustin
%%
Of course, this is a heuristic, which is a fancy way of saying that it doesn't work.
        --Mark-Jason Dominus
%%
Those who know that they are profound strive for clarity. Those who would like to seem profound to the crowd strive for obscurity.
        --Friedrich Nietzsche
%%
... implementations should follow a general principle of robustness: be conservative in what you do, be liberal in what you accept from others.
        --Jon Postel, RFC 761
%%
The designer of a new kind of system must participate fully in the implementation.
        --Donald E. Knuth
%%
More good code has been written in languages denounced as ``bad'' than in languages proclaimed ``wonderful'' -- much more.
        --Bjarne Stroustrup, "The Design and Evolution of C++" (1994)
%%
I have yet to see any problem, however complicated, which, when you looked at it in the right way, did not become still more complicated.
        --Paul Anderson
%%
... with proper design, the features come cheaply. This approach is arduous, but continues to succeed.
        --Dennis Ritchie
%%
Simple things should be simple and complex things should be possible.
        --Alan Kay
%%
Premature optimization is the root of all evil in programming.
        --C.A.R. Hoare
%%
The key to performance is elegance, not battalions of special cases. The terrible temptation to tweak should be resisted unless the payoff is really noticeable.
        --Jon Bentley and Doug McIlroy
%%
The lyf so short, the craft so long to lerne.
        --Geoffrey Chaucer
%%
There are features that should not be used.
There are concepts that should not be exploited.
There are problems that should not be solved.
There are programs that should not be written.
        --Richard Harter, <rh@smds.com>
%%
Writing code ... is not an exercise in manliness.
        --Mark Hahn, <hahn@neurocog.lrdc.pitt.edu>
%%
It's hard to read through a book on the principles of magic without glancing at the cover periodically to make sure it isn't a book on software design.
        --Bruce Tognazzini
%%
Programs must be written for people to read, and only incidentally for machines to execute.
        --Abelson and Sussman
%%
A language that doesn't have everything is actually easier to program in than some that do.
        --Dennis Ritchie
%%
Designing pages in HTML is like having sex in a bathtub. If you don't know anything about sex, it won't do you any good to know a lot about bathtubs.
        -- vagabond@mcgurkus.circus.com (comp.infosystems.www.providers)
%%
Anyone who's to (sic) rude to answer a question nicely shouldn't post.
   -- gburnore@databasix.com, <35c20fb6.57357791@nntpd.databasix.com>
%%
It's not that perl programmers are idiots, it's that the language rewards idiotic behavior in a way that no other language or tool has ever done.
        --Erik Naggum
%%
Milking a dromedary -- a highly intelligent and not always good-natured beast -- is, she confesses, "a process of negotiation."
        -- CNN story, Nov. 30, 2000
%%
Programming languages teach you not to want what they cannot provide.
        -- Paul Graham, ANSI Common Lisp
%%
Do not be too timid and squeamish about your actions. All life is an experiment. The more experiments you make the better. What if they are a little coarse, and you may get your coat soiled or torn? What if you do fail, and get fairly rolled in the dirt once or twice. Up again, you shall never be so afraid of a tumble.
        -- Ralph Waldo Emerson
%%
No amount of experimentation can ever prove me right; a single experiment can prove me wrong.
        -- Albert Einstein
%%
The man who is denied the opportunity of making decisions of importance begins to regard as important the decisions he is allowed to make.
        -- C. Northcote Parkinson
%%
You think you know when you can learn, are more sure when you can write, even more when you can teach, but certain when you can program.
        -- Alan Perlis
%%
One of the great commandments of science is: 'Mistrust arguments from authority.'
        -- Carl Sagan
%%
So... to avoid nasty vendor lock-in, go with MicroSoft. And to avoid getting rained on, jump in the river.
        -- GeorgePaci (http://c2.com/cgi/wiki?WhatsWrongWithEjb)
%%
I recall the old story about the place that decided to use first initial + first seven letters of last name.  It was pointed out to them that Steve Hittinger would not like this.
        -- http://groups.google.com/groups?q=g:thl1803897064d&dq=&hl=en&selm=ab9bfh%241ik%241%40reader1.panix.com
%%
        > you didn't address the problem.  what do you do when another Joe Smith
        > shows up?
        Ah, that's the easy part.  After a week, hold a vote of the users, 
        and decide which one to keep, and which to fire.
        There's no problem that can't be solved, if you're creative enough.
        -- http://groups.google.com/groups?dq=&hl=en&selm=abb9ob%24h2gu9%247%40ID-134476.news.dfncis.de
%%
Maybe you do need malaria. Then you'll have a real reason to complain.
        -- "quitter = strategist" (http://discuss.fogcreek.com/joelonsoftware/default.asp?cmd=show&ixPost=8409&ixReplies=25)
%%
The plural of 'anecdote' is not 'data'.
        --Random slashdot poster
%%
There is this special biologist word we use for 'stable'. It is 'dead'.
        -- Jack Cohen
%%
A large number of installed systems work by fiat. That is, they work by being declared to work.
        -- Anatol Holt
%%
When someone says "I want a programming language in which I need only say what I wish done," give him a lollipop.
        -- Alan Perlis
%%
You can do three things with a computer. You can try to make money and that is unlikely. You can try to become famous and that never happens. And you can have fun and that always works.
        -- Chuck Forth
%%
A good programming language should have features that make the kind of people who use the phrase "software engineering" shake their heads disapprovingly.
        -- Paul Graham
%%
We are what we pretend to be, so we must be careful what we pretend to be.
        -- Kurt Vonnegut
%%
Moral indignation is jealousy with a halo.
        -- H. G. Wells
%%
The conception of two people living together for twenty-five years without
having a cross word suggests a lack of spirit only to be admired in sheep.
        -- Alan Patrick Herbert
