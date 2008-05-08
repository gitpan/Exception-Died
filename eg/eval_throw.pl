#!/usr/bin/perl -I../lib

use Exception::Base
    'Exception::Died';

eval { open $file, "x", "/badmodeexample" };
warn "\$@ = $@";
Exception::Died->throw( $@, message=>"cannot open" ) if $@;
