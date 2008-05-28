#!/usr/bin/perl -c

package Exception::Died;
use 5.006;
our $VERSION = 0.02;

=head1 NAME

Exception::Died - Convert simple die into real exception object

=head1 SYNOPSIS

  # Can be loaded via Exception::Base pragma
  use Exception::Base,
      'Exception::Died';

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


# Base class
use base 'Exception::Base';


# List of class fields (name => {is=>ro|rw, default=>value})
use constant ATTRS => {
    %{ Exception::Base->ATTRS },     # SUPER::ATTRS
    default_attribute => { default => 'eval_error' },
    eval_attribute    => { default => 'eval_error' },
    eval_error        => { is => 'ro' },
    eval_thrown       => { is => 'rw' },
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
        if (do { local $@; local $SIG{__DIE__}; eval { $_[0]->isa(__PACKAGE__) } } and ref $_[0] ne $class and $_[0]->{eval_thrown}) {
            # Rebless if called as Exception::Died->catch()
            bless $_[0] => $class;
        }
        $want_object = 0;
    }
    else {
        # Otherwise: return from sub
        if (do { local $@; local $SIG{__DIE__}; eval { $return->isa(__PACKAGE__) } } and ref $return ne $class and $return->{eval_thrown}) {
            # Rebless if called as Exception::Died->catch()
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


# Convert an exception to string
sub stringify {
    my ($self, $verbosity, $message) = @_;

    $verbosity = defined $self->{verbosity}
               ? $self->{verbosity}
               : $self->{defaults}->{verbosity}
        if not defined $verbosity;

    # The argument overrides the field
    $message = $self->{message} unless defined $message;

    my $is_message = defined $message && $message ne '';
    my $is_eval_error = $self->{eval_error};
    if ($is_message or $is_eval_error) {
        $message = ($is_message ? $message : '')
                 . ($is_message && $is_eval_error ? ': ' : '')
                 . ($is_eval_error ? $self->{eval_error} : '');
    }
    else {
        $message = $self->{defaults}->{message};
    }
    return $self->SUPER::stringify($verbosity, $message);
}


# Stringify for overloaded operator. The same as SUPER but Perl needs it here.
sub __stringify {
    return $_[0]->stringify;
}


# Die hook
sub __DIE__ {
    if (not ref $_[0]) {
        # Simple die: recover eval error
        my $message = $_[0];
        while ($message =~ s/\t\.\.\.propagated at (?!.*\bat\b.*).* line \d+( thread \d+)?\.\n$//s) { }
        $message =~ s/( at (?!.*\bat\b.*).* line \d+( thread \d+)?\.)?\n$//s;
        my $e = Exception::Died->new;
        $e->{eval_error} = $message;
        $e->{eval_thrown} = 1;
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

=head1 ATTRIBUTES

This class provides new attributes.  See L<Exception::Base> for other
descriptions.

=over

=item eval_error (ro)

Contains the message which returns B<eval> block.  This attribute is
automatically filled on object creation.

=item eval_thrown (rw)

Contains the flag for B<catch> method if it should rebless thrown
exception based on simple die.  The flag is marked by internal
B<__DIE__> hook.

=back

=head1 METHODS

=over

=item I<CLASS>-E<gt>catch([$I<variable>])

This method overwrites the default B<catch> method.  It works as method
from base class and has one exception in its behaviour.

If the popped value is an B<Exception::Died> object and has an attribute
B<eval_thrown> set, this object is reblessed to class I<CLASS> with its
attributes unchanged.  It will mimic the behaviour of L<Exception::Base> if it
was caught simple L<die|perlfunc>.

  use Exception::Base 'Exception::Fatal' => { isa => 'Exception::Died' };
  use Exception::Died '%SIG' => 'die';

  eval { die "Died\n"; };
  my $e = Exception::Fatal->catch;
  print ref $e;   # "Exception::Fatal"

  eval { Exception::Base->throw; };
  my $e = Exception::Fatal->catch;
  print ref $e;   # "Exception::Base"

=item stringify([$I<verbosity>[, $I<message>]])

Returns the string representation of exception object.  It is called
automatically if the exception object is used in scalar context.  The method
can be used explicity and then the verbosity level can be used.

The format of output is "I<message>: I<eval_error>".

=back

=head1 PRIVATE METHODS

=over

=item _collect_system_data

Collect system data and fill the attributes of exception object.  This method
is called automatically if exception if throwed.

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
