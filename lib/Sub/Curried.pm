=head1 NAME

Sub::Curried - automatically curried subroutines

=head1 SYNOPSIS

 curry add_n_to ($n, $val) {
    return $n+$val;
 }

 my $add_10_to = add_n_to( 10 );

 say $add_10_to->(4);  # 14

 # but you can also
 say add_n_to(10,4);  # also 14

 # or more traditionally
 say add_n_to(10)->(4);

=head1 DESCRIPTION

Currying and Partial Application come from the heady world of functional
programming, but are actually useful techniques.  Partial Application is used
to progressively specialise a subroutine, by pre-binding some of the arguments.

Partial application is the generic term, that also encompasses the concept of
plugging in "holes" in arguments at arbitrary positions.  Currying is more
specifically the application of arguments progressively from left to right
until you have enough of them.

=head1 USAGE

Define a curried subroutine using the C<curry> keyword.  You should list the
arguments to the subroutine in parentheses.  This isn't a sophisticated signature
parser, just a common separated list of scalars (or C<@array> or C<%hash> arguments,
which will be returned as a I<reference>).

    curry greet ($greeting, $greetee) {
        return "$greeting $greetee";
    }

    my $hello = greet("Hello");
    say $hello->("World"); # Hello World

=head2 Currying

Currying applies the arguments from left to right, returning a more specialised function
as it goes until all the arguments are ready, at which point the sub returns its value.

    curry three ($one,$two,$three) {
        return $one + $two * $three
    }

    three(1,2,3)  # normal call - returns 7

    three(1)      # a new subroutine, with $one bound to the number 1
        ->(2,3)   # call the new sub with these arguments

    three(1)->(2)->(3) # You could call the curried sub like this, 
                       # instead of commas (1,2,3)

What about calling with I<no> arguments?  By extension that would return a function exactly
like the original one... but with I<no> arguments prebound (i.e. it's an alias!)

    my $fn = three;   # same as my $fn = \&three;

=head2 Anonymous curries

Just like you can have anonymous subs, you can have anonymous curried subs:

    my $greet = curry ($greeting, $greetee) { ... }

=head2 Composition

Curried subroutines are I<composable>.  This means that we can create a new
subroutine that takes the result of the second subroutine as the input of the
first.

Let's say we wanted to expand our greeting to add some punctuation at the end:

    curry append  ($r, $l) { $l . $r }
    curry prepend ($l, $r) { $l . $r }

    my $ciao = append('!') << prepend('Ciao ');
    say $ciao->('Bella'); # Ciao Bella!

How does this work?  Follow the pipeline in the direction of the E<lt>E<lt>...
First we prepend 'Ciao ' to get 'Ciao Bella', then we pass that to the curry that
appends '!'.  We can also write them in the opposite order, to match evaluation
order, by reversing the operator:

    my $ciao = prepend('Ciao ') >> append('!');
    say $ciao->('Bella'); # Ciao Bella!

Finally, we can create a shell-like pipeline:

    say 'Bella' | prepend('Ciao ') | append('!'); # Ciao Bella!

The overloaded syntax is provided by C<Sub::Composable> which is distributed with 
this module as a base class.

=head2 Argument aliasing

When all the arguments are supplied and the function body is executed, the
arguments values are available in both the named parameters and the C<@_>
array.  Just as in a normal subroutine call, the elements of C<@_> (but
I<not> the named parameters) are aliased to the variables supplied by the
caller, so you can use pass-by-reference semantics.

    curry set ($a, $b) {
      foreach my $arg (@_) { $arg = 1; } # affects the caller
      $a = $b = 2;                       # doesn't affect the caller
    }
    my ($x, $y) = (0, 0);
    set($x)->($y); # $x == 1, $y == 1

=head2 Stack traces

The innermost stack frame has the function name you defined, with all the
accumulated arguments.  Any intermediate stack frames have the same or
similar function names; currently there is a C<__curried> suffix, but that
may change in the future.  Currently there is only one intermediate stack
frame, showing just the arguments that were passed in the final call that
reached the required number of arguments, but that may change in the future.
If you supply all the arguments in one call, there are no intermediate stack
frames.

    use Carp 'confess';
    curry func ($a, $b, $c, $d) {
      confess('ERROR MESSAGE');
    }
    sub call {
      func(1)->(2)->(3, 4);
    }
    call();

    ERROR MESSAGE at script.pl line 3
           main::func(1, 2, 3, 4) called at .../Sub/Curried.pm line 202
           main::func__curried(3, 4) called at script.pl line 6
           main::call() called at script.pl line 8

=cut

package Sub::Curried;
use base 'Sub::Composable';
use strict; use warnings;
use Carp 'croak';

use Devel::Declare;
use Sub::Name;
use Sub::Identify 'sub_fullname';
use B::Hooks::EndOfScope;
use Devel::BeginLift;

our $VERSION = '0.12';

# cargo culted
sub import {
    my $class = shift;
    my $caller = caller;

    Devel::Declare->setup_for(
        $caller,
        { curry => { const => \&parser } }
    );

    # would be nice to sugar this
    no strict 'refs';
    *{$caller.'::curry'} = sub (&) {};
}

sub mk_my_var {
    my ($name, $i) = @_;
    my ($vsigil, $vname) = ($name=~/^([\$%@])(\w+)$/)
        or die "Bad sigil: $_!"; # not croak, this is in compilation phase
    my $arg = '$_['.$i.']';
    if ($vsigil ne '$') {
      $arg = $vsigil.'{'.$arg.'}';
    }
    return qq[my $vsigil$vname = $arg;];
}

sub trim {
    s/^\s*//;
    s/\s*$//;
    $_;
}
sub get_decl {
    my $decl = shift || '';
    map trim, split /,/ => $decl;
}

sub curried {
    my ($expected_args, $func) = @_;
    my $name = sub_fullname($func).'__curried';
    my $wrapper;
    $wrapper = sub {
        if (@_>$expected_args) { die($name.', expected '.$expected_args.' args but got '.@_); }
        if (@_==$expected_args) { goto &$func; }
        my $args = \@_;
        my $curried = sub { $wrapper->(@$args, @_) };
        bless($curried, __PACKAGE__);
        subname($name, $curried);
        return $curried;
    };
    bless($wrapper, __PACKAGE__);
    subname($name, $wrapper);
    $wrapper;
}

# Stolen from Devel::Declare's t/method-no-semi.t / Method::Signatures
{
    our ($Declarator, $Offset);
    sub skip_declarator {
        $Offset += Devel::Declare::toke_move_past_token($Offset);
    }

    sub skipspace {
        $Offset += Devel::Declare::toke_skipspace($Offset);
    }

    sub strip_name {
        skipspace;
        if (my $len = Devel::Declare::toke_scan_word($Offset, 1)) {
            my $linestr = Devel::Declare::get_linestr();
            my $name = substr($linestr, $Offset, $len);
            substr($linestr, $Offset, $len) = '';
            Devel::Declare::set_linestr($linestr);
            return $name;
        }
        return;
    }

    sub strip_proto {
        skipspace;
    
        my $linestr = Devel::Declare::get_linestr();
        if (substr($linestr, $Offset, 1) eq '(') {
            my $length = Devel::Declare::toke_scan_str($Offset);
            my $proto = Devel::Declare::get_lex_stuff();
            Devel::Declare::clear_lex_stuff();
            $linestr = Devel::Declare::get_linestr();
            substr($linestr, $Offset, $length) = '';
            Devel::Declare::set_linestr($linestr);
            return $proto;
        }
        return;
    }

    sub shadow {
        my $pack = Devel::Declare::get_curstash_name;
        Devel::Declare::shadow_sub("${pack}::${Declarator}", $_[0]);
    }

    sub inject_if_block {
        my $inject = shift;
        skipspace;
        my $linestr = Devel::Declare::get_linestr;
        if (substr($linestr, $Offset, 1) eq '{') {
            substr($linestr, $Offset+1, 0) = $inject;
            Devel::Declare::set_linestr($linestr);
        }
    }

    sub parser {
        local ($Declarator, $Offset) = @_;
        skip_declarator;
        my $name = strip_name;
        my $proto = strip_proto;

        my @decl = get_decl($proto);

        my $installer = sub (&) {
            my $f = shift;
            if (defined($name) and $name ne '') {
                subname($name, $f);
            }
            $f = curried(scalar(@decl), $f);

            if (defined($name) and $name ne '') {
                no strict 'refs';
                *{$name} = $f;
                ()
            } else {
                $f;
            }
          };
        my $si = scope_injector_call(', "Sub::Curried"; ($f,@r)=$f->($_) for @_; wantarray ? ($f,@r) : $f}');
            
        my $inject = join('', map(mk_my_var($decl[$_], $_), 0..$#decl));

        if (defined $name) {
            my $lift_id = Devel::BeginLift->setup_for_cv($installer) if $name;

            $inject = scope_injector_call(";Devel::BeginLift->teardown_for_cv($lift_id);").$inject;
        }

        inject_if_block($inject);

        if (defined $name) {
            $name = join('::', Devel::Declare::get_curstash_name(), $name)
              unless ($name =~ /::/);
        }

        shadow($installer);
    }

    # Set up the parser scoping hacks that allow us to omit the final
    # semicolon
    sub scope_injector_call {
        my $pkg  = __PACKAGE__;
        my $what = shift || ';';
        return " BEGIN { B::Hooks::EndOfScope::on_scope_end { ${pkg}::add_at_end_of_scope('$what') } }; ";
    }
    sub add_at_end_of_scope {
        my $what = shift || ';';
        my $linestr = Devel::Declare::get_linestr;
        my $offset = Devel::Declare::get_linestr_offset;
        substr($linestr, $offset, 0) = $what;
        Devel::Declare::set_linestr($linestr);
    }
}


=head1 BUGS

No major bugs currently open.  Please report any bugs via RT or email, or ping
me on IRC (osfameron on irc.perl.org and freenode)

=head1 SEE ALSO

L<Devel::Declare> provides the magic (yes, there's a teeny bit of code
generation involved, but it's not a global filter, rather a localised
parsing hack).

There are several modules on CPAN that already do currying or partial evaluation:

=over 4

=item *

L<Perl6::Currying> - Filter based module prototyping the Perl 6 system

=item * 

L<Sub::Curry> - seems rather complex, with concepts like blackholes and antispices.  Odd.

=item *

L<AutoCurry> - creates a currying variant of all existing subs automatically.  Very odd.

=item *

L<Sub::DeferredPartial> - partial evaluation with named arguments (as hash keys).  Has some
great debugging hooks (the function is a blessed object which displays what the current
bound keys are).

=item *

L<Attribute::Curried> - exactly what we want minus the sugar.  (The attribute has
to declare how many arguments it's expecting)

=back

=head1 AUTHOR and LICENSE

 (c)2008-2013 osfameron@cpan.org

=head2 CONTRIBUTORS

=over 4

=item *

Florian (rafl) Ragwitz

=item *

Paul (prj) Jarc

=back

This module is distributed under the same terms and conditions as Perl itself.

Please submit bugs to RT or shout at me on IRC (osfameron on #london.pm on irc.perl.org)

A git repo is available at L<http://github.com/osfameron/Sub--Curried/tree/master>

=cut

1;
