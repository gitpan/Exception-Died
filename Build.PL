#!/usr/bin/perl

use 5.006;
use Module::Build;

use strict;
use warnings;

my $build = Module::Build->new(
    module_name => 'Exception::Died',
    dist_author => 'Piotr Roszatycki <dexter@debian.org>',
    license => 'perl',
    requires => {
        'constant::boolean'  => 0,
        'perl'               => 5.006,
        'Exception::Base'    => 0.21,
    },
    optional => {
    },
    build_requires => {
        'parent'             => 0,
        'Test::Assert'       => 0.05,
	'Test::Unit::Lite'   => 0.11,
    },
    create_makefile_pl => 'traditional',
    create_readme => 1,
    recursive_test_files => 1,
    add_to_cleanup => [
        'META.yml', '*.bak', '*.gz', '*.tgz', '*.ppd', '*.deb', '*.bat',
        'Makefile.PL', 'Makefile', 'pm_to_blib', 'README', 'cover_db',
        'Debian_CPANTS.txt',
        'Exception-Died-*',
    ],
);

$build->create_build_script;
