#!/usr/bin/perl

use strict;
use warnings;

use File::Spec;
use Cwd;

BEGIN {
    unshift @INC, map { /(.*)/; $1 } split(/:/, $ENV{PERL5LIB}) if defined $ENV{PERL5LIB} and ${^TAINT};

    my $cwd = ${^TAINT} ? do { local $_=getcwd; /(.*)/; $1 } : '.';
    unshift @INC, File::Spec->catdir($cwd, 'inc');
    unshift @INC, File::Spec->catdir($cwd, 'lib');
}

use Test::Unit::Lite;

use Exception::Base
    max_arg_nums => 0, max_arg_len => 200, verbosity => 4,
    'Exception::DiedTest::Warning';
use Exception::Died '%SIG';

local $SIG{__WARN__} = sub { Exception::DiedTest::Warning->throw($_[0], ignore_level => 1) };

Test::Unit::HarnessUnit->new->start('Test::Unit::Lite::AllTests');
