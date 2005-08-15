use Test::More;
use Test::MockObject;
use Data::Dumper;

use strict;

plan tests => 3						# use_ok
			+ 6						# my tests
	;

use_ok('HTML::Template::Pluggable');
use_ok('HTML::Template::Plugin::Dot');
use_ok('Test::MockObject');

my $mock = Test::MockObject->new();
$mock->mock( 'that_returns_loopdata', sub {
		my ($self, $count) = @_;
		$count ||= 5;
		return $self->ar($count);
	} );
$mock->mock( 'ar', sub {
		my ($self, $count) = @_;
		my @ret = ();
		
		for( 1.. $count) {
			push @ret, {
					a => $_,
					b => $_*10,
			};
		}
		return @ret;
	} );
$mock->mock( 'arrayref', sub {
		my ($self, $count) = @_;
		$count ||= 5;
		return [ $self->ar($count) ];
	} );
$mock->mock( 'nested', sub {
		my ($self, $count) = @_;
		$count ||= 2;
		my @ret;
		for (1..$count) {
			push @ret, {
				a => $_,
				b => [ map { { c=>$_*3 } } (1..$_) ],
			};
		}
		return @ret;
	} );

my ($tag, $out);

$tag = q{ <tmpl_loop name="object.that_returns_loopdata(3)"><tmpl_var this.a>, <tmpl_var this.b>. </tmpl_loop> };
$out = get_output($tag, $mock);
SKIP: {
	skip "HTML::Template subclassing bug for tmpl_loop support. See: http://rt.cpan.org/NoAuth/Bug.html?id=14037", 6 if $@;
	like($out, qr/1, 10/, 'Wrapped loops work with implicit "this" mapping');

	$tag = q{ <tmpl_loop name="object.that_returns_loopdata(4) : that"><tmpl_var that.a>, <tmpl_var that.b>. </tmpl_loop> };
	$out = get_output($tag, $mock);
	like($out, qr/1, 10/, 'Wrapped loops work with explicit "that" mapping');

	$tag = q{ <tmpl_loop name="object.arrayref : d"><tmpl_var d.a>, <tmpl_var d.b>. </tmpl_loop> };
	$out = get_output($tag, $mock);
	like($out, qr/1, 10/, 'Wrapped loops work with arrayrefs');

	$tag = q{ <tmpl_loop name="object.nested(3) : outer"><tmpl_var outer.a>, <tmpl_loop outer.b>(<tmpl_var this.c>)</tmpl_loop>. </tmpl_loop> };
	$out = get_output($tag, $mock);
	like($out, qr/\Q3, (3)(6)(9)./, 'Wrapped nested loops work with arrayrefs');

	$tag = q{ <tmpl_loop name="object.nested(3) : outer"><tmpl_var outer.a>, <tmpl_loop outer.b:inner>(<tmpl_var inner.c>)</tmpl_loop>. </tmpl_loop> };
	$out = get_output($tag, $mock);
	like($out, qr/\Q3, (3)(6)(9)./, 'Wrapped nested loops work with arrayrefs and explicit "inner" mapping');

	$tag = q{ <tmpl_loop name="object.nested(3)"><tmpl_var this.a>, <tmpl_loop this.b>(<tmpl_var this.c>)</tmpl_loop>. </tmpl_loop> };
	$out = get_output($tag, $mock);
	like($out, qr/\Q3, (3)(6)(9)./, 'Wrapped nested loops work with arrayrefs and implicit mapping everywhere');
}

sub get_output {
	my ($tag, $data) = @_;
	my ( $output );
	my $t = HTML::Template::Pluggable->new(
			scalarref	=> \$tag,
			global_vars	=> 0,
			debug		=> 0
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
