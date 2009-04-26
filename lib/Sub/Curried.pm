#!/usr/bin/perl

=head1 NAME

Sub::Curried - Currying of subroutines via a new 'curry' declarator

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
programming, but are actually useful techniques.  Partial Application is
used to progressively specialise a subroutine, by pre-binding some of the
arguments.

Partial application is the generic term, that also encompasses the concept
of plugging in "holes" in arguments at arbitrary positions.  Currying is
(I think) more specifically the application of arguments progressively from
left to right until you have enough of them.

=cut

package Sub::Curried;
use strict; use warnings;
use Carp 'croak';

use Devel::Declare;
use Sub::Name;
use Scope::Guard;

our $VERSION = '0.06';

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
    my ($name) = @_;
    my ($vsigil, $vname) = /^([\$%@])(\w+)$/
        or die "Bad sigil: $_!"; # not croak, this is in compilation phase
    my $shift = $vsigil eq '$' ?
        'shift'
      : "${vsigil}{+shift}";
    return qq[my $vsigil$vname = $shift;];
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
        my $exp= scalar @decl;

        # We nest each layer of currying in its own sub.
        # if we were passed more than one argument, then we call more than one layer.
        # We use the closing brace '}' trick as per monads, but also place the calling
        # logic here.

        my $si = scope_injector_call(', "Sub::Curried"; $f=$f->($_) for @_; $f}');

        my $inject = "my \$exp = $exp; " 
            . qq[ die ("Expected $exp args but got ".\@_) if \@_>$exp; \$exp-=\@_; ]
            . join qq[ my \$f = bless sub { $si; ],
                map { 
                    mk_my_var($_)
                } @decl;

        if (defined $name) {
            $inject = scope_injector_call().$inject;
        }

        inject_if_block($inject);

        if (defined $name) {
            $name = join('::', Devel::Declare::get_curstash_name(), $name)
              unless ($name =~ /::/);
        }
        my $installer = sub (&) {
            my $f = shift;
            bless $f, __PACKAGE__;
            if ($name) {
                no strict 'refs';
                *{$name} = subname $name => $f;
            }
            $f;
          };
        shadow($installer);
    }

    # Set up the parser scoping hacks that allow us to omit the final
    # semicolon
    sub scope_injector_call {
        my $pkg  = __PACKAGE__;
        my $what = shift || ';';
        return " BEGIN { ${pkg}::inject_scope ('$what') }; ";
    }
    sub inject_scope {
        my $what = shift || ';';
        $^H |= 0x120000;
        $^H{DD_METHODHANDLERS} = Scope::Guard->new(sub {
            my $linestr = Devel::Declare::get_linestr;
            my $offset = Devel::Declare::get_linestr_offset;
            substr($linestr, $offset, 0) = $what;
            Devel::Declare::set_linestr($linestr);
        });
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

 (c)2008-2009 osfameron@cpan.org

This module is distributed under the same terms and conditions as Perl itself.

Please submit bugs to RT or shout at me on IRC (osfameron on #london.pm on irc.perl.org)

=cut

1;
