package OpenInteract2::PPTip;

# $Id: PPTip.pm,v 1.1 2004/06/03 13:04:41 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );

my @ADVICE = (
   [ 1, q{Care About Your Craft<br>Why spend your life developing software unless you care about doing it well?} ],
   [ 2, q{Provide Options, Don't Make Lame Excuses<br>Instead of excuses, provide options. Don't say it can't be done; explain what can be done.} ],
   [ 3, q{Be a Catalyst for Change<br>You can't force change on people. Instead, show them how the future might be and help them participate in creating it.} ],
   [ 4, q{Make Quality a Requirements Issue<br>Involve your users in determining the project's real quality requirements.} ],
   [ 5, q{Critically Analyze What You Read and Hear<br>Don't be swayed by vendors, media hype, or dogma. Analyze information in terms of you and your project.} ],
   [ 6, q{DRY --- Don't Repeat Yourself<br>Every piece of knowledge must have a single, unambiguous, authoritative representation within a system.} ],
   [ 7, q{Eliminate Effects Between Unrelated Things<br>Design components that are self-contained, independent, and have a single, well-defined purpose.} ],
   [ 8, q{Use Tracer Bullets to Find the Target<br>Tracer bullets let you home in on your target by trying things and seeing how close they land.} ],
   [ 9, q{Program Close to the Problem Domain<br>Design and code in your user's language.} ],
   [ 10, q{Iterate the Schedule with the Code<br>Use experience you gain as you implement to refine the project time scales.} ],
   [ 11, q{Use the Power of Command Shells<br>Use the shell when graphical user interfaces don't cut it.} ],
   [ 12, q{Always Use Source Code Control<br>Source code control is a time machine for your work --- you can go back.} ],
   [ 13, q{Don't Panic When Debugging<br>Take a deep breath and THINK! about what could be causing the bug.} ],
   [ 14, q{Don't Assume It --- Prove It<br>Prove your assumptions in the actual environment --- with real data and boundary conditions.} ],
   [ 15, q{Write Code That Writes Code<br>Code generators increase your productivity and help avoid duplication.} ],
   [ 16, q{Design with Contracts<br>Use contracts to document and verify that code does no more and no less than it claims to do. } ],
   [ 17, q{Use Assertions to Prevent the Impossible<br>Assertions validate your assumptions. Use them to protect your code from an uncertain world.} ],
   [ 18, q{Finish What You Start<br>Where possible, the routine or object that allocates a resource should be responsible for deallocating it.} ],
   [ 19, q{Configure, Don't Integrate<br>Implement technology choices for an application as configuration options, not through integration or engineering.} ],
   [ 20, q{Analyze Workflow to Improve Concurrency<br>Exploit concurrency in your user's workflow.} ],
   [ 21, q{Always Design for Concurrency<br>Allow for concurrency, and you'll design cleaner interfaces with fewer assumptions.} ],
   [ 22, q{Use Blackboards to Coordinate Workflow<br>Use blackboards to coordinate disparate facts and agents, while maintaining independence and isolation among participants.} ],
   [ 23, q{Estimate the Order of Your Algorithms<br>Get a feel for how long things are likely to take before you write code.} ],
   [ 24, q{Refactor Early, Refactor Often<br>Just as you might weed and rearrange a garden, rewrite, rework, and re-architect code when it needs it. Fix the root of the problem.} ],
   [ 25, q{Test Your Software, or Your Users Will<br>Test ruthlessly. Don't make your users find bugs for you.} ],
   [ 26, q{Don't Gather Requirements --- Dig for Them<br>Requirements rarely lie on the surface. They're buried deep beneath layers of assumptions, misconceptions, and politics.} ],
   [ 27, q{Abstractions Live Longer than Details<br>Invest in the abstraction, not the implementation. Abstractions can survive the barrage of changes from different implementations and new technologies.} ],
   [ 28, q{Don't Think Outside the Box --- Find the Box<br>When faced with an impossible problem, identify the real constraints. Ask yourself: ``Does it have to be done this way? Does it have to be done at all?"} ],
   [ 29, q{Some Things Are Better Done than Described<br>Don't fall into the specification spiral --- at some point you need to start coding.} ],
   [ 30, q{Costly Tools Don't Produce Better Designs<br>Beware of vendor hype, industry dogma, and the aura of the price tag. Judge tools on their merits.} ],
   [ 31, q{Don't Use Manual Procedures<br> A shell script or batch file will execute the same instructions, in the same order, time after time. } ],
   [ 32, q{Coding Ain't Done 'Til All the Tests Run<br>'Nuff said.} ],
   [ 33, q{Test State Coverage, Not Code Coverage<br>Identify and test significant program states. Just testing lines of code isn't enough.} ],
   [ 34, q{English is Just a Programming Language<br>Write documents as you would write code: honor the DRY principle, use metadata, MVC, automatic generation, and so on.} ],
   [ 35, q{Gently Exceed Your Users' Expectations<br>Come to understand your users' expectations, then deliver just that little bit more.} ],
   [ 36, q{Think! About Your Work<br>Turn off the autopilot and take control. Constantly critique and appraise your work.} ],
   [ 37, q{Don't Live with Broken Windows<br>Fix bad designs, wrong decisions, and poor code when you see them.} ],
   [ 38, q{Remember the Big Picture<br>Don't get so engrossed in the details that you forget to check what's happening around you.} ],
   [ 39, q{Invest Regularly in Your Knowledge Portfolio<br>Make learning a habit.} ],
   [ 40, q{It's Both What You Say and the Way You Say It<br>There's no point in having great ideas if you don't communicate them effectively.} ],
   [ 41, q{Make It Easy to Reuse<br>If it's easy to reuse, people will. Create an environment that supports reuse.} ],
   [ 42, q{There Are No Final Decisions<br>No decision is cast in stone. Instead, consider each as being written in the sand at the beach, and plan for change.} ],
   [ 43, q{Prototype to Learn<br>Prototyping is a learning experience. Its value lies not in the code you produce, but in the lessons you learn.} ],
   [ 44, q{Estimate to Avoid Surprises<br>Estimate before you start. You'll spot potential problems up front.} ],
   [ 45, q{Keep Knowledge in Plain Text<br>Plain text won't become obsolete. It helps leverage your work and simplifies debugging and testing.} ],
   [ 46, q{Use a Single Editor Well<br>The editor should be an extension of your hand; make sure your editor is configurable, extensible, and programmable.} ],
   [ 47, q{Fix the Problem, Not the Blame<br>It doesn't really matter whether the bug is your fault or someone else's --- it is still your problem, and it still needs to be fixed.} ],
   [ 48, q{"select" Isn't Broken<br>It is rare to find a bug in the OS or the compiler, or even a third-party product or library. The bug is most likely in the application.} ],
   [ 49, q{Learn a Text Manipulation Language<br>You spend a large part of each day working with text. Why not have the computer do some of it for you?} ],
   [ 50, q{You Can't Write Perfect Software<br>Software can't be perfect. Protect your code and users from the inevitable errors.} ],
   [ 51, q{Crash Early<br>A dead program normally does a lot less damage than a crippled one.} ],
   [ 52, q{Use Exceptions for Exceptional Problems<br>Exceptions can suffer from all the readability and maintainability problems of classic spaghetti code. Reserve exceptions for exceptional things.} ],
   [ 53, q{Minimize Coupling Between Modules<br>Avoid coupling by writing "shy" code and applying the Law of Demeter.} ],
   [ 54, q{Put Abstractions in Code, Details in Metadata<br>Program for the general case, and put the specifics outside the compiled code base.} ],
   [ 55, q{Design Using Services<br>Design in terms of services --- independent, concurrent objects behind well-defined, consistent interfaces.} ],
   [ 56, q{Separate Views from Models<br>Gain flexibility at low cost by designing your application in terms of models and views.} ],
   [ 57, q{Don't Program by Coincidence<br>Rely only on reliable things. Beware of accidental complexity, and don't confuse a happy coincidence with a purposeful plan.} ],
   [ 58, q{Test Your Estimates<br>Mathematical analysis of algorithms doesn't tell you everything. Try timing your code in its target environment.} ],
   [ 59, q{Design to Test<br>Start thinking about testing before you write a line of code.} ],
   [ 60, q{Don't Use Wizard Code You Don't Understand<br>Wizards can generate reams of code. Make sure you understand all of it before you incorporate it into your project.} ],
   [ 61, q{Work with a User to Think Like a User<br>It's the best way to gain insight into how the system will really be used. } ],
   [ 62, q{Use a Project Glossary<br>Create and maintain a single source of all the specific terms and vocabulary for a project.} ],
   [ 63, q{Start When You're Ready<br>You've been building experience all your life. Don't ignore niggling doubts.} ],
   [ 64, q{Don't Be a Slave to Formal Methods<br>Don't blindly adopt any technique without putting it into the context of your development practices and capabilities.} ],
   [ 65, q{Organize Teams Around Functionality<br>Don't separate designers from coders, testers from data modelers. Build teams the way you build code.} ],
   [ 66, q{Test Early. Test Often. Test Automatically.<br>Tests that run with every build are much more effective than test plans that sit on a shelf. } ],
   [ 67, q{Use Saboteurs to Test Your Testing<br>Introduce bugs on purpose in a separate copy of the source to verify that testing will catch them.} ],
   [ 68, q{Find Bugs Once<br>Once a human tester finds a bug, it should be the last time a human tester finds that bug. Automatic tests should check for it from then on.} ],
   [ 69, q{Build Documentation In, Don't Bolt It On<br>Documentation created separately from code is less likely to be correct and up to date.} ],
   [ 70, q{Sign Your Work<br>Craftsmen of an earlier age were proud to sign their work. You should be, too.} ],
   [ 71, q{Languages to Learn<br>Tired of C, C++, and Java? Try CLOS, Dylan, Eiffel, Objective C, Prolog, Smalltalk, or Tom. Each of these languages has different capabilities and a different "flavor." Try a small project at home using one or more of them.} ],
   [ 72, q{The WISDOM Acrostic<br>                     W hat do you want them to learn?<br>       What is their i nterest in what you've got to say?<br>                 How s ophisticated are they?<br>            How much d etail do they want?<br> Whom do you want to o wn the information?<br>         How can you m otivate them to listen to you?} ],
   [ 73, q{How to Maintain Orthogonality<br>- Design independent, well-defined components.<br>- Keep your code decoupled.<br>- Avoid global data.<br>- Refactor similar functions.} ],
   [ 74, q{Things to prototype<br>- Architecture<br>- New functionality in an existing system<br>- Structure or contents of external data<br>- Third-party tools or components<br>- Performance issues<br>- User interface design} ],
   [ 75, q{Architectural Questions<br>- Are responsibilities well defined?<br>- Are the collaborations well defined?<br>- Is coupling minimized?<br>- Can you identify potential duplication?<br>- Are interface definitions and constraints acceptable?<br>- Can modules access needed data --- *when* needed?} ],
   [ 76, q{Debugging Checklist<br>- Is the problem being reported a direct result of the  underlying bug, or merely a symptom?<br>- Is the bug *really* in the compiler? Is it in the OS? Or is it in your code?<br>- If you explained this problem in detail to a coworker, what would you say?<br>- If the suspect code passes its unit tests, are the tests complete enough? What happens if you run the unit test with *this* data?<br>- Do the conditions that caused this bug exist anywhere else in the system?} ],
   [ 77, q{Law of Demeter for Functions<br>An object's method should call only methods belonging to: <br>- Itself<br>- Any parameters passed in<br>- Objects it creates<br>- Component objects} ],
   [ 78, q{How to Program Deliberately<br>- Stay aware of what you're doing.<br>- Don't code blindfolded.<br>- Proceed from a plan.<br>- Rely only on reliable things.<br>- Document your assumptions.<br>- Test assumptions as well as code.<br>- Prioritize your effort.<br>- Don't be a slave to history.} ],
   [ 79, q{When to Refactor<br>- You discover a violation of the DRY principle.<br>- You find things that could be more orthogonal.<br>- Your knowledge improves.<br>- The requirements evolve.<br>- You need to improve performance.} ],
   [ 80, q{Cutting the Gordian Knot<br>When solving *impossible* problems, ask yourself:<br>- Is there an easier way?<br>- Am I solving the right problem?<br>- *Why* is this a problem?<br>- What makes it hard?<br>- Do I have to do it this way?<br>- Does it have to be done at all?} ],
   [ 81, q{Aspects of Testing<br>- Unit testing<br>- Integration testing<br>- Validation and verification<br>- Resource exhaustion, errors, and recovery<br>- Performance testing<br>- Usability testing<br>- Testing the tests themselves} ],
);

sub get {
    my ( $num, $tip ) = @{ $ADVICE[ int( rand( scalar @ADVICE ) ) ] };
    $tip =~ s/<br>/\n/g;
    return ( $num, $tip );
}

sub get_html {
    my ( $num, $tip ) = get();
    $tip =~ s/\n/<br>\n/g;
    return "<b>Tip $num</b><br>$tip";
}

sub get_full_html {
    return 'From <a href="http://www.pragmaticprogrammer.com/ppbook/index.shtml">The Pragmatic Programmer</a><br>' .
           get_html();
}

__END__

=head1 NAME

OpenInteract2::PPTip - Choose a random tip from "The Pragmatic Programmer"

=head1 SYNOPSIS

 use OpenInteract2::PPTip;
 my ( $tip_num, $advice ) = OpenInteract2::PPTip->get();
 print "In HTML: ", OpenInteract2::PPTip->get_html();
 print "With linked attribution: ", OpenInteract2::PPTip->get_full_html();

=head1 DESCRIPTION

This returns a random tip from the great book, "The Pragmatic Programmer".

=head1 SEE ALSO

Christian Lemburg originally put this in a digital tip format:

 http://www.clemburg.com/pptip

Pragmatic Programmer website:

 http://www.pragmaticprogrammer.com/ppbook/index.shtml

=head1 COPYRIGHT

Copyright (c) 2000 by Addison Wesley Longman, Inc. (data)

Copyright (c) 2002 Chris Winters (for putting it in this format)
