#!/usr/bin/perl -I../lib

use Exception::Base ':all';
use Exception::Died '%SIG';

try eval {
    try eval { open $file, "z", "/badmodeexample" };
    warn "\$@ = $@";
    if (catch 'Exception::Died' => my $e) {
	warn "\$e = $e";
	Exception::Died->throw( $e, message=>"cannot open" );
    }
};
if (catch my $e) {
    Exception::Died->throw( $e );
}
