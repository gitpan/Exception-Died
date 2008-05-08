#!/usr/bin/perl -I../lib

use Exception::Base;
use Exception::Died '%SIG';

eval { open $file, "x", "/badmodeexample" };
warn "\$@ = $@";
Exception::Died->throw( $@, message=>"cannot open" ) if $@;
