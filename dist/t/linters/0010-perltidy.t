#!/usr/bin/perl

use strict;
use warnings;

use Test::PerlTidy qw( run_tests );

run_tests(
    exclude => [
        '../dist/t/0010-obs-bootstrap-api.t', '../dist/t/0030-installed-files.t',
        '../src/api/vendor/',                 '../src/backend/'
    ],
    path => '..'
);
