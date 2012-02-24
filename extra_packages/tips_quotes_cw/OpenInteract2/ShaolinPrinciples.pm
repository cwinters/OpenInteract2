package OpenInteract2::ShaolinPrinciples;

# $Id: ShaolinPrinciples.pm,v 1.2 2005/03/06 16:54:11 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use HTML::Entities;
use Text::Wrap qw( wrap );

my @QUOTES = ();

BEGIN: {
        local $/ = undef;
        my $raw = <DATA>;
        my @raw_quotes = split( "%%\n", $raw );
        foreach my $full_quote ( @raw_quotes ) {
            chomp $full_quote;
            my ( $linenum, $quote ) = split /\s/, $full_quote, 2;
            push @QUOTES, [ $linenum, $quote ];
        }
}


sub get {
    return @{ $QUOTES[ int( rand( scalar @QUOTES ) ) ] };
}

sub get_wrapped {
    my ( $num, $principle ) = get();
    local $Text::Wrap::columns = 60;
    return wrap( undef, undef, "$num: $principle" );
}

sub get_html {
    my ( $num, $principle ) = get();
    return "<b>$num</b>: " . HTML::Entities::encode( $principle );
}

sub get_full_html {
    return get_html();
}

1;

=pod

=head1 NAME

OpenInteract2::ShaolinPrinciples - Choose a random shaolin priciple

=head1 SYNOPSIS

 use OpenInteract2::ShaolinPrinciples;
 my ( $principle_num, $principle ) = OpenInteract2::ShaolinPrinciple->get;
 
 print "In HTML: ", OpenInteract2::ShaolinPrinciple->get_html();

=head1 DESCRIPTION

This returns a random Shaolin Action Principle from the book by Bill
Fitzpatrick.

=head1 SEE ALSO

100 Action Principles of the Shaolin by Bill Fitzpatrick
http://www.amazon.com/exec/obidos/tg/detail/-/1884864104/

=head1 COPYRIGHT

Copyright (c) 1998 Bill Fitzpatrick (for the actual words)

Copyright (c) 2004 Chris Winters (for putting it in this format)

=cut

__DATA__
1 Set Goals
%%
2 Develop Winning Strategies
%%
3 Be Decisive
%%
4 Maintain a Positive Attitude
%%
5 Relax Your Body
%%
6 Look in the Mirror
%%
7 Enjoy Your Own Company
%%
8 Share the Credit
%%
9 Make Everyone Feel Important
%%
10 Build Networks
%%
11 Think About Selling
%%
12 Understand Courage
%%
13 Stay Fit and Healthy
%%
14 Write a Personal Mission Statement
%%
15 Be the Warrior
%%
16 Build Your Team
%%
17 Have Faith
%%
18 Ask Yourself
%%
19 Seize the Moment
%%
20 Set the Example
%%
21 Act As If
%%
22 Act Independently
%%
23 Seek Change
%%
24 Give Freely
%%
25 Communicate With Ease
%%
26 Invest in Your Future
%%
27 Appreciate Your Students
%%
28 Ask a Lot of Questions
%%
29 Run the Short Road
%%
30 March the Long Road
%%
31 Don't Allways Apologize
%%
32 Find Beauty Everywhere
%%
33 Accept Differences
%%
34 Blame No One
%%
35 Be Outwardly Focused
%%
36 Face Fear
%%
37 Challenge Yourself
%%
38 Follow Through
%%
39 Choose Your Master First
%%
40 Do What You Love Doing
%%
41 How to Wear a Green Belt
%%
42 How to Wear a Brown Belt
%%
43 How to Wear a Black Belt
%%
44 Allow Your Opponent to Save Face
%%
45 Don't be a Perfectionist
%%
46 Applaud the Courage of the White Belt
%%
47 Read Bibliographys
%%
48 Give Yourself the Gift of Self Reliance
%%
49 Focus on Your Priorities
%%
50 Don't Complicate Matters
%%
51 Assume Leadership
%%
52 Listen to Your Instincts
%%
53 Accept Hard Work
%%
54 Remain Flexible
%%
55 Play to the Winners
%%
56 Be Open to New Ideas
%%
57 Heed the Warnings
%%
58 Set the Bar High
%%
59 Practice Your Katas
%%
60 Define Integrity
%%
61 Follow Your Code of Honor
%%
62 Stay Centered
%%
63 Commit to Self Dicipline
%%
64 Accept Your Limitations
%%
65 Be Grateful to Your Sensei
%%
66 Retire Early
%%
67 Observe and Be Aware
%%
68 Go Ahead
%%
69 Love Many Things
%%
70 Live Simply
%%
71 Make Today Special
%%
72 Record Your Thoughts
%%
73 Be of No Mind
%%
74 Forget Everybody
%%
75 Maintain Your Sai
%%
76 Count the Time
%%
77 Imagine
%%
78 Walk Away
%%
79 Work at Work
%%
80 Inch Forward
%%
81 Stop Talking
%%
82 Look Forward to Tommorow
%%
83 Pass Along the Secret
%%
84 Give Generously
%%
85 Build a Business
%%
86 Develop Your Special Talent
%%
87 Appreciate Your Appeal
%%
88 Remember these Words
%%
89 Teach Yourself
%%
90 Form Your Day
%%
91 Do What Others Can't
%%
92 Build Upon Your Basics
%%
93 Avoid Thinking That ...
%%
94 Be the Monk
%%
95 Use the Power of Patience
%%
96 Develop Your Sense of Humor
%%
97 Control Conflict
%%
98 Take the Punch
%%
99 Become Grateful
%%
100 Rejoice in the Day
