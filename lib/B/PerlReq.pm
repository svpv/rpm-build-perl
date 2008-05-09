# From `The UNIX-HATERS Handbook', p.55:
#
#	Anyone who had both access to the source code and the
#	inclination to read it soon found themselves in for a rude
#	surprise:
#
#		/* You are not expected to understand this */
#
#	Although this comment originally appeared in the Unix V6 kernel
#	source code, it could easily have applied to any of the original
#	AT&T code, which was a nightmare of in-line hand-optimizations
#	and micro hacks.

package B::PerlReq;
our $VERSION = "0.6.8";

use 5.006;
use strict;
use PerlReq::Utils qw(mod2path path2dep verf verf_perl sv_version);

our @Skip = (
	qr(^Makefile\b),
# OS-specific
	qr(^machine/ansi\b),		# gcc 3.3 stddef.h (FreeBSD 4)
	qr(^sys/_types\b),		# gcc 3.3 stddef.h (FreeBSD 5)
	qr(^sys/systeminfo\b),		# solaris
	qr(^Convert/EBCDIC\b),		# os390
	qr(^ExtUtils/XSSymSet\b),	# VMS
	qr(\bOS2|OS2\b),
	qr(\bMacPerl|\bMac\b),
	qr(\bMacOS|MacOS\b),
	qr(\bMacOSX|MacOSX\b),
	qr(\bvmsish\b),
	qr(\bVMS|VMS\b),
	qr(\bWin32|Win32\b),
	qr(\bCygwin|Cygwin\b),
# most common
	qr(^Carp\.pm$),
	qr(^Exporter\.pm$),
	qr(^strict\.pm$),
	qr(^vars\.pm$),
);

our $CurCV;
sub const_sv ($) {
	my $op = shift;
	my $sv = $op->sv;
	$sv = (($CurCV->PADLIST->ARRAY)[1]->ARRAY)[$op->targ] unless $$sv;
	return $sv;
}

our $CurLevel = 0;
our $CurEval;
our $CurLine;
our $CurSub;
our $CurOpname;

our ($Strict, $Relaxed, $Verbose, $Debug);

sub RequiresPerl ($) {
	my $v = shift;
	my $dep = "perl-base >= " . verf_perl($v);
	my $msg = "$dep at line $CurLine (depth $CurLevel)";
	if (not $Strict and $v < 5.006) {
		print STDERR "# $msg old perl SKIP\n" if $Verbose;
		return;
	}
	print STDERR "# $msg REQ\n" if $Verbose;
	print "$dep\n";
}

# XXX prevDepF is a hack to please t/01-B-PerlReq.t
my $prevDepF;

sub Requires ($;$) {
	my ($f, $v) = @_;
	my $dep = path2dep($f) . ($v ? " >= " . verf($v) : "");
	my $msg = "$dep at line $CurLine (depth $CurLevel)";
	if ($f !~ m#^\w+(?:[/-]\w+)*[.]p[lmh]$#) { # bits/ioctl-types.ph
		print STDERR "# $msg invalid SKIP\n";
		return;
	}
	if ($CurSub eq "BEGIN" and not $INC{$f} and $CurOpname ne "autouse") {
		print STDERR "# $msg not loaded at BEGIN SKIP\n";
		return;
	}
	if (not $Strict and grep { $f =~ $_ } @Skip) {
		print STDERR "# $msg builtin SKIP\n" if $Verbose;
		return;
	}
	if ($CurSub eq "BEGIN" and $INC{$f}) {
		goto req;
	}
	if (not $Strict and $CurEval) {
		print STDERR "# $msg inside eval SKIP\n";
		return;
	}
	if ($Relaxed and $CurLevel > 4) {
		print STDERR "# $msg deep SKIP\n";
		return;
	}
req:	print STDERR "# $msg REQ\n" if $Verbose;
	if ($prevDepF and $prevDepF ne $f) {
		print path2dep($prevDepF) . "\n";
	}
	undef $prevDepF;
	if ($v) {
		print "$dep\n";
	} else {
		$prevDepF = $f;
	}
}
sub finalize {
	print path2dep($prevDepF) . "\n"
		if $prevDepF;
}

sub check_encoding ($) {
	my $enc = shift;
	eval { local $SIG{__DIE__}; require Encode; } or do {
		print STDERR "Encode.pm not available at $0 line $CurLine\n";
		return;
	};
	my $e = Encode::resolve_alias($enc) or do {
		print STDERR "invalid encoding $enc at $0 line $CurLine\n";
		return;
	};
	my $mod = $Encode::ExtModule{$e} || $Encode::ExtModule{lc($e)} or do {
		print STDERR "no module for encoding $enc at $0 line $CurLine\n";
		return;
	};
	Requires(mod2path($mod));
}

sub check_perlio_string ($) {
	local $_ = shift;
	while (s/\b(\w+)[(](\S+?)[)]//g) {
		Requires("PerlIO.pm");
		Requires("PerlIO/$1.pm");
		if ($1 eq "encoding") {
			Requires("Encode.pm");
			check_encoding($2);
		}
	}
}

sub grok_perlio ($) {
	my $op = shift;
	my $opname = $op->name;
	$op = $op->first; return unless $$op;		# pushmark
	$op = $op->sibling; return unless $$op;		# gv[*FH] -- arg1
	$op = $op->sibling; return unless $$op and $op->name eq "const";
	my $sv = const_sv($op); return unless $sv->can("PV");
	local $CurOpname = $opname;
	my $arg2 = $sv->PV; $arg2 =~ s/\s//g;
	if ($opname eq "open") {
		return unless $arg2 =~ s/^[+]?[<>]+//;	# validate arg2
		$op = $op->sibling; return unless $$op;	# arg3 required
		if ($op->name eq "srefgen") {		# check arg3
			Requires("PerlIO.pm");
			Requires("PerlIO/scalar.pm");
		}
	}
	check_perlio_string($arg2);
}

sub grok_require ($) {
	my $op = shift;
	return unless $op->first->name eq "const";
	my $sv = const_sv($op->first);
	my $v = sv_version($sv);
	defined($v)  
		? RequiresPerl($v)
		: Requires($sv->PV)
		;
}

sub grok_import ($$@) {
	my ($class, undef, @args) = @_;
	return unless @args;
	local $CurOpname = $class;
	if ($class eq "base") {
		foreach my $m (@args) {
			my $f = mod2path($m);
			# XXX Requires($f) if $INC{$f};
			foreach (@INC) {
				if (-f "$_/$f") {
					Requires($f);
					last;
				}
			}
		}
	}
	elsif ($class eq "autouse") {
		my $f = mod2path($args[0]);
		Requires($f);
	}
	elsif ($class eq "encoding") {
		require Config;
		Requires("PerlIO/encoding.pm") if $Config::Config{useperlio};
		check_encoding($args[0]) if $args[0] =~ /^[^:]/;
		Requires("Filter/Util/Call.pm") if grep { $_ eq "Filter" } @args;
	}
	else {
		# the first import arg is possibly a version
		my $v = $args[0];
		if ($v =~ /^\d/ and $v > 0 and (0 + $v) eq $v) {
			my $f = mod2path($class);
			Requires($f, $v);
		}
	}
}

sub grok_version ($$@) {
	my ($class, undef, $version) = @_;
	return unless $version;
	my $f = mod2path($class);
	local $CurOpname = "version";
	Requires($f, $version);
}

our %methods = (
	'import' => \&grok_import,
	'VERSION' => \&grok_version,
	'require_version' => \&grok_version,
);

sub grok_method ($) { # class->method(args)
	my $OP = my $op = shift;
	my $method = const_sv($op)->PV;
	return unless $methods{$method};
	$op = $op->next; return unless $op->name eq "entersub";
	$op = $op->first; return unless $op->name eq "pushmark";
	$op = $op->sibling; return unless $op->name eq "const";
	my $sv = const_sv($op); return unless $sv->can("PV");
	my $class = $sv->PV;
	my @args;
	$op = $op->sibling;
	while ($$op and $op->name eq "const") {
		my $sv = const_sv($op);
		my $arg;
		unless (@args) {
			# the first arg is possibly a version
			$arg = sv_version($sv);
		}
		unless (defined $arg) {
			# dereference sv value
			if ($sv->can("object_2svref")) {
				my $rv = $sv->object_2svref;
				$arg = $$rv if ref $rv;
			}
			# object_2svref is new to perl >= 5.8.1
			# try to save constants for older perls
			elsif ($sv->can("PV")) {
				$arg = $sv->PV;
			}
			elsif ($sv->can("NV")) {
				$arg = $sv->NV;
			}
			elsif ($sv->can("int_value")) {
				$arg = $sv->int_value;
			}
		}
		push @args, $arg;
		$op = $op->sibling;
	}
	return unless $$OP == $$op;
	$methods{$method}->($class, $method, @args);
}

our %ops = (
	'require'	=> \&grok_require,
	'dofile'	=> \&grok_require,
	'method_named'	=> \&grok_method,
	'open'		=> \&grok_perlio,
	'binmode'	=> \&grok_perlio,
	'dbmopen'	=> sub { Requires("AnyDBM_File.pm") },
);

sub grok_root ($);
sub grok_root ($) {
	my $op = shift;
	my $ref = ref($op);
	return unless $ref and $$op;
# caller is OP, gvsv is PADOP
#	return if $ref eq "B::PADOP" or $ref eq "B::OP";
	if ($ref eq "B::COP") {
		$CurLine = $op->line;
		return;
	}
	my $name = $op->name;
	local $CurLevel = $CurLevel + 1;
	local $CurEval = $CurLevel if $name eq "leavetry";
	if ($ops{$name}) {
		local $CurOpname = $name;
		$ops{$name}->($op);
	}
	grok_root($op->pmreplroot) if $ref eq "B::PMOP";
	use B qw(OPf_KIDS);
	if ($op->flags & OPf_KIDS) {
		for ($op = $op->first; $$op; $op = $op->sibling) {
			grok_root($op);
		}
	}
}

sub grok_cv ($);

sub grok_av ($$) {
	my ($name, $av) = @_;
	return if ref($av) ne "B::AV";
	local $CurSub = $name;
	grok_cv($_) for $av->ARRAY;
}

sub grok_pad ($) {
	my $pad = shift;
	return unless $pad->can("ARRAY");
	grok_av ANON => $pad->ARRAY;
}

sub grok_cv ($) {
	my $cv = shift;
	return if ref($cv) ne "B::CV";
	return if $cv->FILE and $cv->FILE ne $0;
	local $CurCV = $cv;
	grok_root($cv->ROOT);
	grok_pad($cv->PADLIST);
}

sub grok_blocks () {
	use B qw(begin_av init_av);
	grok_av "BEGIN" => begin_av;
	grok_av "INIT" => init_av;
}

sub grok_main () {
	use B qw(main_cv main_root);
	local $CurSub = "MAIN";
	grok_cv(main_cv);
	local $CurCV = main_cv;
	grok_root(main_root);
}

sub grok_gv ($) {
	my $gv = shift;
	my $cv = $gv->CV;
	return unless $$cv;
	return if $cv->XSUB;
	local $CurSub = $gv->SAFENAME;
	$CurLine = $gv->LINE;
	grok_cv($cv);
}

sub grok_stash { # similar to B::walksymtable
	my ($symref, $prefix) = @_;
	while (my ($sym) = each %$symref) {
		no strict 'refs';
		my $fullname = "*main::". $prefix . $sym;
		if ($sym =~ /::\z/) {
			$sym = $prefix . $sym;
			grok_stash(\%$fullname, $sym)
				if $sym ne "main::" && $sym ne "<none>::";
		}
		else {
			use B qw(svref_2object);
			grok_gv(svref_2object(\*$fullname))
				if *$fullname{CODE};
		}
	}
}

sub grok_subs () {
	grok_stash \%::, '';
}

sub compile {
	my $pkg = __PACKAGE__;
	for my $opt (@_) {
		$opt =~ /^-(?:s|-?strict)$/	and $Strict = 1 or
		$opt =~ /^-(?:r|-?relaxed)$/	and $Relaxed = 1 or
		$opt =~ /^-(?:v|-?verbose)$/	and $Verbose = 1 or
		$opt =~ /^-(?:d|-?debug)$/	and $Verbose = $Debug = 1 or
		die "$pkg: unknown option: $opt\n";
	}
	die "$pkg: options -strict and -relaxed are mutually exclusive\n"
		if $Strict and $Relaxed;
	return sub {
		$| = 1;
		local $SIG{__DIE__} = sub {
			# checking $^S is unreliable because O.pm uses eval
			print STDERR "dying at $0 line $CurLine\n";
			require Carp;
			Carp::cluck();
		};
		grok_blocks();
		grok_main();
		grok_subs() if not $Relaxed;
		finalize();
	};
}

END {
	print STDERR "# CurEval=$CurEval\n" if $CurEval;
}

1;

__END__

=for comment
We use C<print STDERR> instead of C<warn> because we don't want to
trigger C<$SIG{__WARN__}>, which affects files that use L<diagnostics>.

=head1	NAME

B::PerlReq - Perl compiler backend to extract Perl dependencies

=head1	SYNOPSIS

B<perl> B<-MO=PerlReq>[B<,-strict>][B<,-relaxed>][B<,-v>][B<,-d>] I<prog.pl>

=head1	DESCRIPTION

B::PerlReq is a backend module for the Perl compiler that extracts
dependencies from Perl source code, based on the internal compiled
structure that Perl itself creates after parsing a program. The output
of B::PerlReq is suitable for automatic dependency tracking (e.g. for
RPM packaging).

=head1	OPTIONS

=over

=item	B<-strict>

Operate in strict mode.  See L<perl.req> for details.

=item	B<-relaxed>

Operate in relaxed mode.  See L<perl.req> for details.

=item	B<-v>, B<--verbose>

Output extra information about the work being done.

=item	B<-d>, B<--debug>

Enable debugging output (implies --verbose option).

=back

=head1	AUTHOR

Written by Alexey Tourbin <at@altlinux.org>.

=head1	COPYING

Copyright (c) 2004, 2006 Alexey Tourbin, ALT Linux Team.

This is free software; you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation;
either version 2 of the License, or (at your option) any later version.

=head1	SEE ALSO

L<B>,
L<B::Deparse>,
L<Module::Info>,
L<Module::ScanDeps>,
L<perl.req>
