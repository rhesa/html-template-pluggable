use strict;
use Test::More tests => 7;
use Test::MockObject;
use strict;

use_ok('HTML::Template::Pluggable');
use_ok('HTML::Template::Plugin::Dot');
use_ok('Test::MockObject');

my $mock = Test::MockObject->new();
$mock->mock( 'some', sub { $mock } );
$mock->mock( 'method', sub { "chained methods work" } );

my ($output, $template, $result);

# test a simple template
my $t = HTML::Template::Pluggable->new( scalarref => 
    \ qq{ <tmpl_var wants.to_be.literal>
          <tmpl_var desires.to_be.hashref>
          <tmpl_var should_be.some.method> <tmpl_var should_be.some.method>
          \n},
                                   debug => 0
                                  );

$t->param('wants.to_be.literal', "Literals tokens with dots work");
$t->param('desires', { to_be => { hashref => "nested hashrefs work" } });
$t->param('should_be',$mock);

$output =  $t->output;

like($output ,qr/Literals tokens with dots work/,'backwards compatibility');
like($output ,qr/nested hashrefs work/);
like($output ,qr/chained methods work/);
like($output ,qr/chained methods work.*chained methods work/, "using a dot var more than once works" );

# vi: filetype=perl
__END__
