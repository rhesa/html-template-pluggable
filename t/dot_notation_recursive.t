use Test::More;
use Test::MockObject;

use strict;

my @tests = (
[q/Formatter.sprintf('%.2f', mock.value)/,					q/ 3.20 / ],
[q/Formatter.sprintf('%.2f', mock.nested(3.1459).key)/,		q/ 3.15 / ],
# [q/mock.nested(Formatter.sprintf('%.3f', 3.14159)).key/,	q/ 3.142 / ], ### eeewww. other way around obviously doesn't work, as it needs the param setting reversed.
);

plan tests => 3						# use_ok
			  + scalar(@tests)		# recursion tests
	;

use_ok('HTML::Template::Pluggable');
use_ok('HTML::Template::Plugin::Dot');
use_ok('Test::MockObject');

my $formatter = Test::MockObject->new();
$formatter->mock( 'sprintf' , sub { shift; sprintf("$_[0]", $_[1]) } );

my $mock = Test::MockObject->new();
$mock->mock( 'name',   sub { 'Mock' } );
$mock->mock( 'value',  sub { '3.196002'  } );
$mock->mock( 'nested', sub { $mock->{key} = $_[1]; $mock } );

foreach my $test(@tests) {
	my ($pat, $out) = @$test;
	
	my ( $output, $template, $result );

	my $tag =  qq{ <tmpl_var name="$pat"> := <tmpl_var name="mock.name"> <tmpl_var name="Formatter.sprintf('%s','')"> }; # 
	
	my $t = HTML::Template::Pluggable->new(
			scalarref => \$tag,
			debug => 0
		);
	$t->param( mock		 => $mock );
	$t->param( Formatter => $formatter );
	$output = $t->output;
	# diag("template tag is $tag");
	# diag("output is $output");
	# diag("mock is ", $t->param('mock'));
	like( $output, qr/$out/, $pat);
}

# vi: filetype=perl

__END__
1..5
ok 1 - use HTML::Template::Pluggable;
ok 2 - use HTML::Template::Plugin::Dot;
ok 3 - use Test::MockObject;
# template tag is  <tmpl_var name="Formatter.sprintf('%.2f', mock.value)"> := <tmpl_var name="mock.name"> <tmpl_var name="Formatter.sprintf('%s','')"> 
ok 4 - Formatter.sprintf('%.2f', mock.value)
# template tag is  <tmpl_var name="Formatter.sprintf('%.2f', mock.nested(3.1459).key)"> := <tmpl_var name="mock.name"> <tmpl_var name="Formatter.sprintf('%s','')"> 
ok 5 - Formatter.sprintf('%.2f', mock.nested(3.1459).key)
