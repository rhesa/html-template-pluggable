package HTML::Template::Plugin::Dot;
use vars qw/$VERSION/;
$VERSION = '0.93';
use strict;

=head1 NAME

HTML::Template::Plugin::Dot - Add Magic Dot notation to HTML::Template

=head1 SYNOPSIS 

 use HTML::Template::Pluggable;
 use HTML::Template::Plugin::Dot;

 my $t = HTML::Template::Pluggable->new(...);

Now you can use chained accessor calls and nested hashrefs as params, and access
them with a dot notation. You can even pass arguments to the methods. 

For example, in your code: 

  $t->param( my_complex_struct => $struct ); 

And then in your template you can reference specific values in the structure:

  my_complex_struct.key.obj.accessor('hash')
  my_complex_struct.other_key

=head1 DESCRIPTION

By adding support for this dot notation to L<HTML::Template>, the programmers'
job of sending data to the template is easier, and designers have easier access
to more data to display in the template, without learning any more tag syntax. 

The dot notation is supported on the following tags: C<< <TMPL_VAR> >>,
C<< <TMPL_IF> >> and C<< <TMPL_UNLESS> >>. 

=head2 EXAMPLES

=head2 Class::DBI integration

L<Class::DBI> accessors can be used in the template.  If the accessor is never
called in the template, that data doesn't have to be loaded. 

In the code:

  $t->param ( my_row => $class_dbi_obj );

In the template:

  my_row.last_name

This extends to related objects or inflated columns (commonly used for date
fields). Here's an example with a date column that's inflated into a DateTime
object:

  my_row.my_date.mdy('/')
  my_row.my_date.strftime('%D')

Of course, if date formatting strings look scary to the designer, you can keep
them in the application, or even a database layer to insure consistency in all
presentations.

Here's an example with related objects. Suppose you have a Customer object, that
has_a BillingAddress object attached to it. Then you could say something like
this:

  <tmpl_if customer.billing_address>
    <tmpl_var customer.billing_address.street>
    <tmpl_var customer.billing_address.city>
    ...
  </tmpl_if>

=head2 More complex uses

The dot notation allows you to pass arguments to method calls (as in the 
C<my_date.dmy('/')> example above). In fact, you can pass other objects in the 
template as well, and this enables more complex usage.
Imagine we had a (fictional) Formatter object which could perform some basic
string formatting functions. This could be used in e.g. currencies, or dates.

In your code:

  $t->param( Formatter => Formatter->new,
             order	   => $order_obj     );

In your template:

  Amount: <tmpl_var Formatter.format_currency('US',order.total_amount)>

(hint: see L<Number::Format>)

This even extends to references to plain tmpl_vars in your template:

 $t->param( Formatter => Formatter->new,
            plain     => 'Jane'         );

 <tmpl_var Formatter.reverse(plain)> is
 <tmpl_var plain> backwards


=head2 LIMITATIONS

=over 4

=item * TMPL_VARs inside of loops won't work unless a simple patch is applied
to HTML::Template.

We hope it will be updated with this patch soon. See
http://rt.cpan.org/NoAuth/Bug.html?id=14037 for details.

Alternately, you can apply the patch to your own copy.  

=item * TMPL_LOOPs are not (yet) supported.

In the sense that you can't have a dot expression in them (even when it returns
a suitable data structure). You still need to pass an array of hashrefs
yourself. Something like this is a reasonable idiom:

 $t->param( deloop => [                      # array ref
                       map {
                        { object => $_ }     # hash ref
                       }
                       @your_objects
                      ]
 );

=item * Casing of parameter names

Casing of parameter names follows the option C<case_sensitive> of
HTML::Template. If you do not use that option, all parameter names are 
converted to lower case. I suggest turning this option on to avoid confusion.

=item * Quotes and spaces

Because of the way HTML::Template parses parameter names (which follows the
rules of HTML attributes), you have to be careful when your expressions contain
spaces or quote characters. You can say
C<< <tmpl_var something.without.spaces> >>, but not
C<< <tmpl_var something with spaces> >>. You can use single or double quotes
around your entire expression, and then use the other one inside:
C<< <tmpl_var name="some.method('with arguments')"> >> This is the recommended
way to write your expressions.

(Note: within expressions, the characters in C<< [`'"] >> are recognised as
quote characters. So if you need to pass literal quotes to a method, you could
do it like this: C<< <tmpl_var name='some.method(`need a " here`)'> >>. )

=back

=head2 PERFORMANCE

No attempt to even measure performance has been made. For now the focus is on
usability and stability. If you carry out benchmarks, or have suggestions for
performance improvements, be sure to let us know!

=cut

use Carp; 
use Data::Dumper;
use Regexp::Common qw/balanced delimited number/;
use Scalar::Util qw/reftype/;
use base 'Exporter';

sub import {
        # my $caller = scalar(caller);
        HTML::Template::Pluggable->add_trigger('pre_param', \&dot_notation);
		goto &Exporter::import;
}

sub dot_notation {
    my $self = shift;
    my $options = $self->{options};
    my $param_map = $self->{param_map};

	# carp("dot_notation called for $_[0]");
    # @_ has already been setup for us by the time we're called. 

    for (my $x = 0; $x <= $#_; $x += 2) {
        my $param = $options->{case_sensitive} ? $_[$x] : lc $_[$x];
        my $value = $_[($x + 1)];

        # necessary to cooperate with plugin system
        next if ($self->{param_map_done}{$param} and not $self->{num_vars_left_in_loop});

        my ($exists,@dot_matches) = _exists_in_tmpl($param_map, $param);
        # We don't have to worry about "die on bad params", because that will be handled
        # by HTML::Template's param().
        next unless $exists;

        my $value_type = ref($value);
        if (@dot_matches) {
            for (@dot_matches) {
                my $value_for_tmpl = _param_to_tmpl($self,$_,$param,$value);
				# carp("_param_to_tmpl returned '$value_for_tmpl' for '$_', '$param', '$value'");
                unless (defined($value_type) and length($value_type) and ($value_type eq 'ARRAY' 
                       or (ref($value_for_tmpl) and (ref($value_for_tmpl) !~ /^(CODE)|(HASH)|(SCALAR)$/) and $value_for_tmpl->isa('ARRAY')))) {
                    (ref($param_map->{$_}) eq 'HTML::Template::VAR') or
                    croak("HTML::Template::param() : attempt to set parameter '$param' with a scalar - parameter is not a TMPL_VAR!");
                    ${$param_map->{$_}} = $value_for_tmpl;
                }

                # Necessary for plugin system compatibility
                $self->{num_vars_left_in_loop} -= 1;
                $self->{param_map_done}{$param} = $value; # store the object for future reference
            }
        }
        # We still need to care about tmpl_loops that aren't dot matches so we can adjust their loops
        elsif (defined($value_type) and length($value_type) and ($value_type eq 'ARRAY' 
                            or ((ref($value) !~ /^(CODE)|(HASH)|(SCALAR)$/) and $value->isa('ARRAY')))) {
                    (ref($param_map->{$param}) eq 'HTML::Template::LOOP') or
                    croak("HTML::Template::param() : attempt to set parameter '$param' with an array ref - parameter is not a TMPL_LOOP!");

         #  TODO: Use constant names instead of "0"
         $self->{num_vars_left_in_loop} += keys %{ $param_map->{$param}[0]{'0'}{'param_map'} };

    } 
    else {
        (ref($param_map->{$param}) eq 'HTML::Template::VAR') or
         croak("HTML::Template::param() : attempt to set parameter '$param' with a scalar - parameter is not a TMPL_VAR!");
         # intetionally /don't/ set the values for non-dot notation  params,
         # and don't mark them as done, just that they exist.    
         $self->{num_vars_left_in_loop} -= 1;
    }
  }
        
}
        
# Check to see if a param exists in the template, with support for dot notation
# returns an an array
#  - bool for any matches
#  - array of keys with dot notation that matched. 
sub _exists_in_tmpl {
    my ($param_map,$param) = @_;
    return 1 if exists $param_map->{$param};
    if (my @matching_dot_tokes = grep { /^$param\./ } keys %$param_map) {
        return (1, @matching_dot_tokes);
    }
    else {
        return undef;
    }
}

# =head2 _param_to_tmpl()
# 
#  my $result = _param_to_tmpl($pluggable,$tmpl_token_name,$param_name,$param_value);
# 
# Returns the right thing to put in the template given a token name, a param name
# and a param value. Returns undef if this template token name and param name
# don't match.
# 
# The template token name supports the dot notation, which means that method
# calls and nested hashes are expanded. 
# 
# However, first we check for a literal match, for backwards compatibility with
# HTML::Template.
# 
# =cut 

sub _param_to_tmpl {
    my ($self,$toke_name,$param_name,$param_value) = @_;

	# carp("_param_to_tmpl called for '$toke_name', '$param_name', '$param_value'");
    # This clause may not be needed because the non-dot-notation
    # cases are handled elsewhere. 
    if ($toke_name eq $param_name) {
		# carp("toke equals param: $toke_name == $param_name");
        return $param_value;
    }
    elsif (my ($one, $the_rest) = split /\./, $toke_name, 2) { 
        if ($one eq $param_name) {
            # NOTE: we do the can-can because UNIVSERAL::isa($something, 'UNIVERSAL')
            # doesn't appear to work with CGI, returning true for the first call
            # and false for all subsequent calls. 
            # This is exactly what TT does.

			# Rhesa (Thu Aug  4 18:33:30 CEST 2005)
			# Patch for mixing method calls and attribute access mixing,
			# and optional parameter lists!
			# 
			# First we're setting $ref to $param_value
			# 
			# We're going to loop over $the_rest by finding anything that matches
			# - a valid identifier $id ( [_a-z]\w* )
			# - optionally followed by something resembling an argument list $data
			# - optionally followed by a dot or $
			# then we're checking if
			# - $ref is an object
			#	- if we can call $id on it
			#	  - in this case we further parse the argument list for strings
			#	  or numbers or references to other h-t params
			#	- or if it's an attribute
			# - or a hashref and we have no $data
			# We'll use the result of that operation for $ref as long as there are dots
			# followed by an identifier

			my $ref = $param_value;	
			
			while( $the_rest =~ s/^
						([_a-z]\w*)				# an identifier
						($RE{balanced})?		# optional param list
						(?:\.|$)				# dot or end of string
					//xi ) {
				my ($id, $data) = ($1, $2);
				
				if (ref($ref) && UNIVERSAL::can($ref, 'can')) {
					# carp("$ref is an object, and its ref=", ref($ref), Dumper($ref));
					if($ref->can($id)) {
						my @args = ();
						if($data) {
							$data =~ s/^\(//; $data =~ s/\)$//;
							while( $data ) {
								if ($data =~ s/
									^\s*
									(
										$RE{delimited}{-delim=>q{'"`}}	# a string
										|
										$RE{num}{real}					# or a number
									)
									(?:,\s*)?
									//xi
								) {
									my $m = $1;
									$m =~ s/^["'`]//; $m =~ s/["'`]$//;
									push @args, $m;
								}
								elsif( $data =~ s/
									^\s*
									(									# ($1) a sub-expression of the form "object.method(args)"
										([_a-z]\w+)						# ($2) the object in question
										(?:
											\.
											[_a-z]\w+					# method name
											$RE{balanced}?				# optional argument list
										)*
									)
									(?:,\s*)?
									//xi
								) {
									my ($m, $o) = ($1, $2); 
									# carp("found subexpression '$m'");
									if( exists($self->{param_map}->{$m}) ) {
										my $prev = $self->param($m);
										# carp("found '$prev' for '$m' in param_map");
										push @args, $prev; 
									}
									elsif( exists($self->{param_map_done}{$o}) ) {
										my $prev = _param_to_tmpl($self, $m, $o, $self->{param_map_done}{$o});
										# carp("found '$prev' for '$o' in param_map_done");
										push @args, $prev;
									}
									else {
										# croak("Can't resolve '$m': '$o' not available. Remember to set nested objects before the ones that call them!");
										croak("Attempt to reference nonexisting parameter '$m' in argument list to '$id' in dot expression '$toke_name': $m is not a TMPL_VAR!");
									}
								}
								else {
									local $,= ', ';
									carp("Parsing is in some weird state. args so far are '@args'. data = '$data'. id='$id'");
									last;
								}
							}
							croak("Bare word '$data' not allowed in argument list to '$id' in dot expression '$toke_name'") if $data;
						}
						# carp("calling '$id' on '$ref' with '@args'");
						eval {
							$ref = $ref->$id(@args);
						} or return undef;
						
					}
					elsif(reftype($ref) eq'HASH') {
						croak("Can't access hash key '$id' with a parameter list! ($data)") if $data;
						
						$ref = exists( $ref->{$id} ) ? $ref->{$id} : undef;
					}
					else {
						croak("Don't know what to do with reference '$ref', identifier '$id' and data '$data', giving up.");
					}
				}
				elsif(ref($ref) eq 'HASH') {
					# carp("accessing key $id on $ref");
					$ref = exists( $ref->{$id} ) ? $ref->{$id} : undef;	# this is paranoid: my tests indicated just doing the assignment doesn't create the new key either. still, better err on the side of caution
				}
			}
			
			croak("Trailing characters '$the_rest' in dot expression '$toke_name'") if $the_rest;
			# carp("we got $ref. the rest = $the_rest");
			return $ref;
		}
        # no match. give up. 
        else {
			# carp("No match: one=$one, param_name=$param_name, the rest=$the_rest");
            return undef;
        }
    }
    # no dots and no literal match: give up
    else {
		# carp("No dots, no literal match: toke=$toke_name, name=$param_name, value=$param_value");
        return undef;
    }

}

=head1 CONTRIBUTING

Patches, questions and feedback are welcome. This project is managed using
the darcs source control system ( http://www.darcs.net/ ). My darcs archive is here:
http://mark.stosberg.com/darcs_hive/ht-dot/

=head1 AUTHORS

Mark Stosberg, E<lt>mark@summersault.comE<gt>;
Rhesa Rozendaal, E<lt>rhesa@cpan.orgE<gt>

=head1 Copyright & License

 Parts copyright 2005 Mark Stosberg
 Parts copyright 2005 Rhesa Rozendaal

This program is free software; you can redistribute it and/or modify it
under the same terms as perl itself.

=cut

1;
