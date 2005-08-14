use Test::More;
use Test::MockObject;

use strict;

plan tests => 3						# use_ok
			+ 3						# hash keys, dying methods
	;

use_ok('HTML::Template::Pluggable');
use_ok('HTML::Template::Plugin::Dot');
use_ok('Test::MockObject');

my $mock = Test::MockObject->new();
$mock->mock( 'method_that_dies', sub { die "horribly..." } );

# methods that die
	get_output(
		'<tmpl_var name="object.method_that_dies">',
		$mock,
	);
ok($@ eq '', "method calls die silently");

# accessing non-existent hash keys
	my %in = ( a => 1, b => 2 );
	get_output(
		'<tmpl_var object.a><tmpl_var name="object.c.e">',
		\%in,
	);
is_deeply(\%in, { a=>1, b=>2 }, 'No side effects on hashes');

# accessing non-existent object properties
	$mock->{old_key} = 'old value';
	get_output(
		'<tmpl_var object.old_key><tmpl_var name="object.new_key">',
		$mock,
	);
ok(!exists($mock->{new_key}), 'No side effects on object properties');


sub get_output {
	my ($tag, $data) = @_;
	my ( $output );
	my $t = HTML::Template::Pluggable->new(
			scalarref => \$tag,
			debug => 0
		);
	eval {
		$t->param( object => $data );
		$output = $t->output;
	};

	# diag("template tag is $tag");
	# diag("output is $output");
	# diag("exception is $@") if $@;
	return $output;
}

# vi: filetype=perl

__END__
