#!/usr/bin/perl -c

package Exception::Died;
use 5.006;
our $VERSION = 0.03;

=head1 NAME

Exception::Died - Convert simple die into real exception object

=head1 SYNOPSIS

  # Can be loaded via Exception::Base pragma
  use Exception::Base 'Exception::Died';

  eval { open $f, "x", "bad_open_mode" };
  Exception::Died->throw( message=>"cannot open" ) if $@;

  eval { die "Bum!\n" };
  if ($@) {
    my $e = Exception::Died->catch;
    $e->throw;
  }

  # Can replace die hook globally
  use Exception::Died '%SIG' => 'die';
  eval { die "Boom!\n" };
  print ref $@;           # "Exception::Died"
  print $@->eval_error;   # "Boom!"

  # Can be used in local scope only
  use Exception::Died;
  {
      local $SIG{__DIE__} = \&Exception::Died::__DIE__;
      eval { die "Boom!"; }
      print ref $@;           # "Exception::Died"
      print $@->eval_error;   # "Boom!"
  }
  eval { die "Boom"; }
  print ref $@;       # ""

=head1 DESCRIPTION

This class extends standard L<Exception::Base> and converts eval's error into
real exception object.  The eval's error message is stored in I<eval_error>
attribute.

=for readme stop

=cut


use strict;
use warnings;


# Extend Exception::Base class
use Exception::Base 0.19;
use base 'Exception::Base';


# List of class fields (name => {is=>ro|rw, default=>value})
use constant ATTRS => {
    %{ Exception::Base->ATTRS },     # SUPER::ATTRS
    stringify_attributes => { default => [ 'message', 'eval_error' ] },
    default_attribute => { default => 'eval_error' },
    eval_attribute    => { default => 'eval_error' },
    catch_can_rebless => { is => 'ro' },
    eval_error        => { is => 'ro' },
};


# Handle %SIG tag
sub import {
    my $pkg = shift;

    my @export;
    my @params;

    while (defined $_[0]) {
        my $name = shift @_;
        if ($name eq '%SIG') {
            if (defined $_[0] and $_[0] eq 'die') {
                shift @_;
            }
            # Handle die hook
            $SIG{__DIE__} = \&__DIE__;
        }
        else {
            # Other parameters goes to SUPER::import
            push @params, $name;
            push @params, shift @_ if defined $_[0] and ref $_[0] eq 'HASH';
        }
    }

    if (@export) {
        my $callpkg = caller;
        Exporter::export($pkg, $callpkg, @export);
    }

    if (@params) {
        return $pkg->SUPER::import(@params);
    }

    return 1;
}


# Reset %SIG
sub unimport {
    my $pkg = shift;
    my $callpkg = caller;

    # Unexport all by default
    my @export = scalar @_ ? @_ : ':all';

    while (my $name = shift @export) {
        if ($name eq '%SIG') {
            # Undef die hook
            $SIG{__DIE__} = '';
        }
    }

    return 1;
}


# Rebless Exception::Died into another exception class
sub catch {
    my $self = shift;

    my $class = ref $self ? ref $self : $self;

    my $want_object;

    my $return = $self->SUPER::catch(@_);

    if (scalar @_ > 0) {
        # Save object into argument
        if (do { local $@; local $SIG{__DIE__}; eval { $_[0]->isa(__PACKAGE__) } }
            and ref $_[0] ne $class and $_[0]->{catch_can_rebless})
        {
            # Rebless if called as Exception::DiedDerivedClass->catch()
            bless $_[0] => $class;
        }
        $want_object = 0;
    }
    else {
        # Otherwise: return from sub
        if (do { local $@; local $SIG{__DIE__}; eval { $return->isa(__PACKAGE__) } }
            and ref $return ne $class and $return->{catch_can_rebless})
        {
            # Rebless if called as Exception::DiedDerivedClass->catch()
            bless $return => $class;
        }
        $want_object = 1;
    }

    return $want_object ? $return : defined $return;
}


# Collect system data
sub _collect_system_data {
    my $self = shift;

    if (not ref $@) {
        $self->{eval_error} = $@;
        while ($self->{eval_error} =~ s/\t\.\.\.propagated at (?!.*\bat\b.*).* line \d+( thread \d+)?\.\n$//s) { }
        $self->{eval_error} =~ s/( at (?!.*\bat\b.*).* line \d+( thread \d+)?\.)?\n$//s;
    }
    else {
        $self->{eval_error} = undef;
    }

    return $self->SUPER::_collect_system_data(@_);
}


# Die hook
sub __DIE__ {
    if (not ref $_[0]) {
        # Do not recurse on Exception::Died & Exception::Warning
        die $_[0] if $_[0] =~ /^Exception::(Died|Warning): /;

        # Simple die: recover eval error
        my $message = $_[0];
        while ($message =~ s/\t\.\.\.propagated at (?!.*\bat\b.*).* line \d+( thread \d+)?\.\n$//s) { }
        $message =~ s/( at (?!.*\bat\b.*).* line \d+( thread \d+)?\.)?\n$//s;

        my $e = __PACKAGE__->new;
        $e->{eval_error} = $message;
        $e->{catch_can_rebless} = 1;
        die $e;
    }
    # Otherwise: throw unchanged exception
    die $_[0];
}


# Module initialization
sub __init {
    __PACKAGE__->_make_accessors;
}


__init;


1;


__END__

=begin umlwiki

= Class Diagram =

[                          <<exception>>
                          Exception::Died
 -----------------------------------------------------------------
 +catch_can_rebless : Bool                                   {new}
 +eval_error : Str
 #default_attribute : Str = "eval_error"
 #eval_attribute : Str = "eval_error"
 #stringify_attributes : ArrayRef[Str] = ["message", "eval_error"]
 -----------------------------------------------------------------
 +catch( out variable : Exception::Base ) : Bool          {export}
 +catch() : Exception::Base                               {export}
 #_collect_system_data()
 <<utility>> -__DIE__()
 <<constant>> +ATTRS() : HashRef                                  ]

[Exception::Died] ---|> [Exception::Base]

=end umlwiki

=head1 BASE CLASSES

=over

=item *

L<Exception::Base>

=back

=head1 IMPORTS

=over

=item use Exception::Died '%SIG';

=item use Exception::Died '%SIG' => 'die';

Changes B<$SIG{__DIE__}> hook to B<Exception::Died::__DIE__>.

=item no Exception::Died '%SIG';

Undefines B<$SIG{__DIE__}> hook.

=back

=head1 CONSTANTS

=over

=item ATTRS

Declaration of class attributes as reference to hash.

See L<Exception::Base> for details.

=back

=head1 ATTRIBUTES

This class provides new attributes.  See L<Exception::Base> for other
descriptions.

=over

=item eval_error (ro)

Contains the message from failed B<eval> block.  This attribute is
automatically filled on object creation.

  use Exception::Died '%SIG';
  eval { die "string" };
  print $@->eval_error;  # "string"

=item catch_can_rebless (rw)

Contains the flag for B<catch> method which marks that this exception
object should be reblessed.  The flag is marked by internal B<__DIE__>
hook.

=item eval_attribute (default: 'eval_error')

Meta-attribute contains the name of the attribute which is filled if
error stack is empty.  This attribute will contain value of B<$@>
variable.  This class overrides the default value from
L<Exception::Base> class.

=item stringify_attributes (default: ['message', 'eval_error'])

Meta-attribute contains the format of string representation of exception
object.  This class overrides the default value from L<Exception::Base>
class.

=item default_attribute (default: 'eval_error')

Meta-attribute contains the name of the default attribute.  This class
overrides the default value from L<Exception::Base> class.

=back

=head1 METHODS

=over

=item I<CLASS>-E<gt>catch([$I<variable>])

This method overwrites the default B<catch> method.  It works as method
from base class and has one exception in its behaviour.

If the popped value is an B<Exception::Died> object and has an attribute
B<catch_can_rebless> set, this object is reblessed to class I<CLASS> with its
attributes unchanged.  It is because original L<Exception::Base>-E<gt>B<catch>
method doesn't change exception class but it should be changed if
B<Exception::Died> handles B<$SIG{__DIE__}> hook.

  use Exception::Base 'Exception::Fatal' => { isa => 'Exception::Died' },
                      'Exception::Simple' => { isa => 'Exception::Died' };
  use Exception::Died '%SIG' => 'die';

  eval { die "Died\n"; };
  my $e = Exception::Fatal->catch;
  print ref $e;   # "Exception::Fatal"

  eval { Exception::Simple->throw; };
  my $e = Exception::Fatal->catch;
  print ref $e;   # "Exception::Simple"


=back

=head1 PRIVATE METHODS

=over

=item _collect_system_data

Collect system data and fill the attributes of exception object.  This
method is called automatically if exception if throwed.  This class
overrides the method from L<Exception::Base> class.

See L<Exception::Base>.

=back

=head1 PRIVATE FUNCTIONS

=over

=item __DIE__

This is a hook function for $SIG{__DIE__}.  This hook can be enabled with pragma:

  use Exception::Died '%SIG';

or manually, i.e. for local scope:

  local $SIG{__DIE__} = \&Exception::Died::__DIE__;

=back

=head1 PERFORMANCE

The B<Exception::Died> module can change B<$SIG{__DIE__}> hook.  It
costs a speed for simple die operation.  The failure scenario was
benchmarked with default setting and with changed B<$SIG{__DIE__}> hook.

  -----------------------------------------------------------------------
  | Module                              | Without %SIG  | With %SIG     |
  -----------------------------------------------------------------------
  | eval/die string                     |      237975/s |        3069/s |
  -----------------------------------------------------------------------
  | eval/die object                     |      124853/s |       90575/s |
  -----------------------------------------------------------------------
  | Exception::Base eval/if             |        8356/s |        7984/s |
  -----------------------------------------------------------------------
  | Exception::Base try/catch           |        9218/s |        8891/s |
  -----------------------------------------------------------------------
  | Exception::Base eval/if verbosity=1 |       14899/s |       14300/s |
  -----------------------------------------------------------------------
  | Exception::Base try/catch verbos.=1 |       18232/s |       16992/s |
  -----------------------------------------------------------------------

It means that B<Exception::Died> with die hook makes simple die 30 times
slower.  However it has no significant difference if the exception
objects are used.

Note that B<Exception::Died> will slow other exception implementations,
like L<Class::Throwable> and L<Exception::Class>.

=head1 SEE ALSO

L<Exception::Base>.

=head1 BUGS

If you find the bug, please report it.

=for readme continue

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright (C) 2008 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
