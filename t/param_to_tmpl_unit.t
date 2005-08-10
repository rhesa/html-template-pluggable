use Test::More qw/no_plan/;
use Test::MockObject;

use HTML::Template::Pluggable;
use HTML::Template::Plugin::Dot;
use strict;

my $mock = Test::MockObject->new();
$mock->mock( 'some', sub { $mock } );
$mock->mock( 'method', sub { "chained methods work" } );

is( 
    HTML::Template::Plugin::Dot->_param_to_tmpl('wants.to_be.literal','wants.to_be.literal', "Literals tokens with dots work"),
    "Literals tokens with dots work",
    "Literals tokens with dots work"
);

is( 
    HTML::Template::Plugin::Dot->_param_to_tmpl('desires.to_be.hashref', 'desires', { to_be => { hashref => "nested hashrefs work" } }),
    "nested hashrefs work",
    "nested hashrefs work",
);

is( 
    HTML::Template::Plugin::Dot->_param_to_tmpl('should_be.some.method','should_be', $mock),
     "chained methods work",
     "chained methods work",
);

