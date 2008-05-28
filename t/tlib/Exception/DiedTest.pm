package Exception::DiedTest;

use strict;
use warnings;

use base 'Test::Unit::TestCase';

use Exception::Died '%SIG';

sub test___isa {
    my $self = shift;
    my $obj = Exception::Died->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("Exception::Died"), '$obj->isa("Exception::Died")');
    $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');
}

sub test_attribute {
    my $self = shift;
    local $@;
    my $obj = Exception::Died->new(message=>'Message');
    $self->assert_equals('Message', $obj->{message});
    $self->assert_equals('', $obj->{eval_error});
}

sub test_accessor {
    my $self = shift;
    my $obj = Exception::Died->new(message=>'Message');
    $self->assert_equals('Message', $obj->message);
    $self->assert_equals('New message', $obj->message = 'New message');
    $self->assert_equals('New message', $obj->message);
    $self->assert_equals('', $obj->eval_error);
    eval { $self->assert_equals(0, $obj->eval_error = 123) };
    $self->assert_matches(qr/modify non-lvalue subroutine call/, $@);
}

sub test_collect_system_data {
    my $self = shift;

    local $SIG{__DIE__};
    eval {
        eval { die "Boom1"; };

        my $obj1 = Exception::Died->new(message=>'Collect1');
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa("Exception::Died"), '$obj1->isa("Exception::Died")');
        $self->assert_equals('Collect1', $obj1->{message});
        $self->assert_equals('Boom1', $obj1->{eval_error});

        eval { die "Boom2\n"; };

        my $obj2 = Exception::Died->new(message=>'Collect2');
        $self->assert_not_null($obj2);
        $self->assert($obj2->isa("Exception::Died"), '$obj2->isa("Exception::Died")');
        $self->assert_equals('Collect2', $obj2->{message});
        $self->assert_equals('Boom2', $obj2->{eval_error});

        eval { Exception::Died->throw(message=>'Throw3') };

        my $obj3 = Exception::Died->new(message=>'Collect3');
        $self->assert_not_null($obj3);
        $self->assert($obj3->isa("Exception::Died"), '$obj3->isa("Exception::Died")');
        $self->assert_equals('Collect3', $obj3->{message});
        $self->assert_null($obj3->{eval_error});

        eval { eval { die "Boom4\n" }; die };

        my $obj4 = Exception::Died->new(message=>'Collect4');
        $self->assert_not_null($obj4);
        $self->assert($obj4->isa("Exception::Died"), '$obj4->isa("Exception::Died")');
        $self->assert_equals('Collect4', $obj4->{message});
        $self->assert_equals('Boom4', $obj4->{eval_error});

        eval { eval { eval { die "Boom5\n" }; die }; die; };

        my $obj5 = Exception::Died->new(message=>'Collect5');
        $self->assert_not_null($obj5);
        $self->assert($obj5->isa("Exception::Died"), '$obj5->isa("Exception::Died")');
        $self->assert_equals('Collect5', $obj5->{message});
        $self->assert_equals('Boom5', $obj5->{eval_error});
    };
    die "$@" if $@;
}

sub test_stringify {
    my $self = shift;

    eval {
        my $obj = Exception::Died->new(message=>'Stringify');

        $self->assert_not_null($obj);
        $self->assert($obj->isa("Exception::Died"), '$obj->isa("Exception::Died")');
        $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');
        $self->assert_equals('', $obj->stringify(0));
        $self->assert_equals("Stringify\n", $obj->stringify(1));
        $self->assert_matches(qr/Stringify at .* line \d+.\n/s, $obj->stringify(2));
        $self->assert_matches(qr/Exception::Died: Stringify at .* line \d+\n/s, $obj->stringify(3));
        $self->assert_equals("Message\n", $obj->stringify(1, "Message"));
        $self->assert_equals("Unknown exception\n", $obj->stringify(1, ""));

        $obj->{eval_error} = 'Error';
        $self->assert_equals('', $obj->stringify(0));
        $self->assert_equals("Stringify: Error\n", $obj->stringify(1));
        $self->assert_matches(qr/Stringify: Error at .* line \d+.\n/s, $obj->stringify(2));
        $self->assert_matches(qr/Exception::Died: Stringify: Error at .* line \d+\n/s, $obj->stringify(3));
        $self->assert_equals("Message: Error\n", $obj->stringify(1, "Message"));
        $self->assert_equals("Error\n", $obj->stringify(1, ""));

        $self->assert_equals(1, $obj->{defaults}->{verbosity} = 1);
        $self->assert_equals(1, $obj->{defaults}->{verbosity});
        $self->assert_equals("Stringify: Error\n", $obj->stringify);
        $self->assert_not_null($obj->{defaults}->{verbosity});
        $obj->{defaults}->{verbosity} = Exception::Died->ATTRS->{verbosity}->{default};
        $self->assert_equals(1, $obj->{verbosity} = 1);
        $self->assert_equals("Stringify: Error\n", $obj->stringify);

        $self->assert_equals("Stringify: Error\n", "$obj");
    };
    die "$@" if $@;
}

sub test_throw {
    my $self = shift;

    # Secure with eval
    eval {
        # Simple die hooked with Exception::Died::__DIE__
        eval {
            die 'Die1';
        };
        my $obj1 = $@;
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa("Exception::Died"), '$obj1->isa("Exception::Died")');
        $self->assert($obj1->isa("Exception::Base"), '$obj1->isa("Exception::Base")');
        $self->assert_equals("Die1\n", $obj1->stringify(1));
        $self->assert_equals('Die1', $obj1->{eval_error});
        $self->assert_equals(__PACKAGE__ . '::test_throw', $obj1->{caller_stack}->[3]->[3]);
        $self->assert(ref $self, ref $obj1->{caller_stack}->[3]->[8]);

        # Rethrow via object method
        eval {
            $obj1->throw(message=>'Message2');
        };
        my $obj2 = $@;
        $self->assert_not_null($obj2);
        $self->assert($obj2->isa("Exception::Died"), '$obj2->isa("Exception::Died")');
        $self->assert($obj2->isa("Exception::Base"), '$obj2->isa("Exception::Base")');
        $self->assert_equals("Message2: Die1\n", $obj2->stringify(1));
        $self->assert_equals('Die1', $obj2->{eval_error});

        # Rethrow via class method with object as argument
        eval {
            Exception::Died->throw($obj2, message=>'Message3');
        };
        my $obj3 = $@;
        $self->assert_not_null($obj3);
        $self->assert($obj3->isa("Exception::Died"), '$obj3->isa("Exception::Died")');
        $self->assert($obj3->isa("Exception::Base"), '$obj3->isa("Exception::Base")');
        $self->assert_equals("Message3: Die1\n", $obj3->stringify(1));
        $self->assert_equals('Die1', $obj3->{eval_error});

        # Rethrow via class method with string as argument
        eval {
            Exception::Died->throw('String4', message=>'Message4');
        };
        my $obj4 = $@;
        $self->assert_not_null($obj4);
        $self->assert($obj4->isa("Exception::Died"), '$obj4->isa("Exception::Died")');
        $self->assert($obj4->isa("Exception::Base"), '$obj4->isa("Exception::Base")');
        $self->assert_equals("Message4\n", $obj4->stringify(1));
        $self->assert_equals('', $obj4->{eval_error});

        # Rethrow via class method with object as argument
        my $obj5 = Exception::Base->new(message=>'Message5');
        eval {
            Exception::Died->throw($obj5, message=>'Message6');
        };
        my $obj6 = $@;
        $self->assert_not_null($obj6);
        $self->assert($obj6->isa("Exception::Died"), '$obj6->isa("Exception::Died")');
        $self->assert($obj6->isa("Exception::Base"), '$obj6->isa("Exception::Base")');
        $self->assert_equals("Message6\n", $obj6->stringify(1));
        $self->assert_null($obj6->{eval_error});

        # Simple die with propagated message.
        eval {
            eval { die 'Die7' };
            die;
        };
        my $obj7 = $@;
        $self->assert_not_null($obj7);
        $self->assert($obj7->isa("Exception::Died"), '$obj7->isa("Exception::Died")');
        $self->assert($obj7->isa("Exception::Base"), '$obj7->isa("Exception::Base")');
        $self->assert_equals("Die7\n", $obj7->stringify(1));
        $self->assert_equals('Die7', $obj7->{eval_error});

        # Simple die with propagated message.
        eval {
            eval {
                eval { die 'Die8' };
                die;
            };
            die;
        };
        my $obj8 = $@;
        $self->assert_not_null($obj8);
        $self->assert($obj8->isa("Exception::Died"), '$obj8->isa("Exception::Died")');
        $self->assert($obj8->isa("Exception::Base"), '$obj8->isa("Exception::Base")');
        $self->assert_equals("Die8\n", $obj8->stringify(1));
        $self->assert_equals('Die8', $obj8->{eval_error});
    };
    die "$@" if $@;
}

sub test_catch {
    my $self = shift;

    # Secure with eval
    eval {
        # Simple die
        Exception::Base->try( eval {
            die 'Message1';
        } );
        my $obj1 = Exception::Died->catch;
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa("Exception::Died"), '$obj1->isa("Exception::Died")');
        $self->assert($obj1->isa("Exception::Base"), '$obj1->isa("Exception::Base")');
        $self->assert_equals("Message1\n", $obj1->stringify(1));
        $self->assert_equals('Message1', $obj1->{eval_error});
        $self->assert_equals(__PACKAGE__ . '::test_catch', $obj1->{caller_stack}->[3]->[3]);
        $self->assert(ref $self, ref $obj1->{caller_stack}->[3]->[8]);

        # Exception
        Exception::Base->try( eval {
            Exception::Died->throw(message=>'Message2');
        } );
        my $obj2 = Exception::Died->catch;
        $self->assert_not_null($obj2);
        $self->assert($obj2->isa("Exception::Died"), '$obj2->isa("Exception::Died")');
        $self->assert($obj2->isa("Exception::Base"), '$obj2->isa("Exception::Base")');
        $self->assert_equals("Message2\n", $obj2->stringify(1));
        $self->assert_equals('', $obj2->{eval_error});
        $self->assert_equals(__PACKAGE__ . '::test_catch', $obj2->{caller_stack}->[3]->[3]);
        $self->assert_equals(ref $self, ref $obj2->{caller_stack}->[3]->[8]);

        # Pop all error stack
        while (Exception::Base->catch) { 1; }

        # Simple die
        eval {
            die 'Message3';
        };
        my $obj3 = Exception::Died->catch;
        $self->assert_not_null($obj3);
        $self->assert($obj3->isa("Exception::Died"), '$obj3->isa("Exception::Died")');
        $self->assert($obj3->isa("Exception::Base"), '$obj3->isa("Exception::Base")');
        $self->assert_equals("Message3\n", $obj3->stringify(1));
        $self->assert_equals('Message3', $obj3->{eval_error});
        $self->assert_equals(__PACKAGE__ . '::test_catch', $obj3->{caller_stack}->[3]->[3]);
        $self->assert(ref $self, ref $obj3->{caller_stack}->[3]->[8]);

        # Exception
        eval {
            Exception::Died->throw(message=>'Message4');
        };
        my $obj4 = Exception::Died->catch;
        $self->assert_not_null($obj4);
        $self->assert($obj4->isa("Exception::Died"), '$obj4->isa("Exception::Died")');
        $self->assert($obj4->isa("Exception::Base"), '$obj4->isa("Exception::Base")');
        $self->assert_equals("Message4\n", $obj4->stringify(1));
        $self->assert_equals('', $obj4->{eval_error});
        $self->assert_equals(__PACKAGE__ . '::test_catch', $obj4->{caller_stack}->[3]->[3]);
        $self->assert_equals(ref $self, ref $obj4->{caller_stack}->[3]->[8]);

        # Derived class exception
        eval q{
            package Exception::DiedTest::catch::Exception1;
            use base 'Exception::Died';
        };
        $self->assert_equals('', $@);

        # Simple die with reblessing class
        eval {
            die 'Message5';
        };
        my $obj5 = Exception::DiedTest::catch::Exception1->catch;
        $self->assert_not_null($obj5);
        $self->assert($obj5->isa("Exception::DiedTest::catch::Exception1"), '$obj5->isa("Exception::DiedTest::catch::Exception1")');
        $self->assert($obj5->isa("Exception::Died"), '$obj5->isa("Exception::Died")');
        $self->assert($obj5->isa("Exception::Base"), '$obj5->isa("Exception::Base")');
        $self->assert_equals("Message5\n", $obj5->stringify(1));
        $self->assert_equals('Message5', $obj5->{eval_error});
        $self->assert_equals(__PACKAGE__ . '::test_catch', $obj5->{caller_stack}->[3]->[3]);
        $self->assert(ref $self, ref $obj5->{caller_stack}->[3]->[8]);

        # Throw without reblessing class
        eval {
            Exception::Died->throw(message=>'Message6');
        };
        my $obj6 = Exception::DiedTest::catch::Exception1->catch;
        $self->assert_not_null($obj6);
        $self->assert(!$obj6->isa("Exception::DiedTest::catch::Exception1"), '!$obj6->isa("Exception::DiedTest::catch::Exception1")');
        $self->assert($obj6->isa("Exception::Died"), '$obj6->isa("Exception::Died")');
        $self->assert($obj6->isa("Exception::Base"), '$obj6->isa("Exception::Base")');
        $self->assert_equals("Message6\n", $obj6->stringify(1));
        $self->assert_equals('Message6', $obj6->{message});
        $self->assert_equals(__PACKAGE__ . '::test_catch', $obj6->{caller_stack}->[3]->[3]);
        $self->assert(ref $self, ref $obj6->{caller_stack}->[3]->[8]);
    };
    die "$@" if $@;
}

sub test_import_keywords {
    my $self = shift;

    local $SIG{__DIE__};
    eval {
        $self->assert_equals('', ref $SIG{__DIE__});

        eval 'Exception::Died->import(qw<%SIG>);';
        $self->assert_equals('CODE', ref $SIG{__DIE__});

        eval 'Exception::Died->unimport(qw<%SIG>);';
        $self->assert_equals('', ref $SIG{__DIE__});

        eval 'Exception::Died->import(qw<%SIG die>);';
        $self->assert_equals('CODE', ref $SIG{__DIE__});

        eval 'Exception::Died->unimport(qw<%SIG die>);';
        $self->assert_equals('', ref $SIG{__DIE__});

        eval 'Exception::Died->import(qw<Exception::Died::test::Import1>);';
        $self->assert_matches(qr/can only be created with/, "$@");

        eval 'Exception::Died->import(qw<Exception::Died::test::Import1> => { has => "attr" });';
        $self->assert_matches(qr/can only be created with/, "$@");

        eval 'Exception::Died->import(qw<Exception::Died::test::Import1> => "%SIG");';
        $self->assert_matches(qr/can only be created with/, "$@");
        $self->assert_equals('CODE', ref $SIG{__DIE__});
    };
    die "$@" if $@;
}

1;
