package PerlReq::Utils;

=head1	NAME

PerlReq::Utils - auxiliary routines for L<B::PerlReq>, L<perl.req> and L<perl.prov>

=cut

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(path2mod mod2path path2dep mod2dep sv_version adjust_inc verf verf_perl);

use strict;

sub path2mod ($) {
	local $_ = shift;
	s/\//::/g;
	s/\.pm$//;
	return $_;
}

sub mod2path ($) {
	local $_ = shift;
	s/::/\//g;
	return $_ . ".pm";
}

sub path2dep ($) {
	my $path = shift;
	return "perl($path)";
}

sub mod2dep ($) {
	my $mod = shift;
	return path2dep(mod2path($mod));
}	

sub adjust_inc () {
	my @inc;
	my @lib = split /[:,\s]+/, $ENV{RPM_PERL_LIB_PATH};
	push @inc, map { "$ENV{RPM_BUILD_ROOT}$_" } grep { /^\// } @lib, @INC
		if $ENV{RPM_BUILD_ROOT};
	push @inc, grep { /^\// } @lib, @INC;
	return grep { -d } @inc;
}

sub verf ($) {
	my $v = shift;
	$v = sprintf("%.3f", int($v * 1000 + 1e-3) / 1000 + 1e-6);
	$v =~ s/\.000$/.0/g;
	return $v;
}

sub verf_perl ($) {
	my $v = shift;
	my $major = int($v);
	my $minor = ($v * 1000) % ($major * 1000);
	my $micro = ($v * 1000 * 1000) % ($minor * 1000 + $major * 1000 * 1000);
	return "1:$major.$minor.$micro";
}

use B qw(class svref_2object);
sub sv_version ($) {
	my $arg = shift;
	my $sv = ref($arg) ? $arg : svref_2object(\$arg);
	my $class = class($sv);
	if ($class eq "IV" or $class eq "PVIV") {
		return $sv->int_value;
	}
	if ($class eq "NV" or $class eq "PVNV") {
		return $sv->NV;
	}
	if ($class eq "PVMG") {
		my @v;
		for (my $mg = $sv->MAGIC; $mg; $mg = $mg->MOREMAGIC) {
			next if $mg->TYPE ne "V";
			@v = $mg->PTR =~ /(\d+)/g;
			last;
		}
		@v = map ord, split //, $sv->PV unless @v;
		return $v[0] + $v[1] / 1000 + $v[2] / 1000 / 1000;
	}
	if ($class eq "PV") {
		my $v = $sv->PV;
		if ($v =~ /^\d/) {
			$v =~ s/_//g;
			return $v + 0;
		}
	}
	return undef;
}

1;

__END__

=head1	AUTHOR

Written by Alexey Tourbin <at@altlinux.org>.

=head1	COPYING

Copyright (c) 2004 Alexey Tourbin, ALT Linux Team.

This is free software; you can redistribute it and/or modify it under
the terms of the GNU Library General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

=head1	SEE ALSO

L<B::PerlReq>, L<perl.req>, L<perl.prov>
