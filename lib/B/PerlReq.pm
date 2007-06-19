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
our $VERSION = "0.6.1";

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

our ($Strict, $Relaxed, $Verbose, $Debug);

use B::Walker qw(const_sv);

sub RequiresPerl ($) {
	my $v = shift;
	my $dep = "perl-base >= " . verf_perl($v);
	my $msg = "$dep at line $B::Walker::Line (depth $B::Walker::Level)";
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
	my $msg = "$dep at line $B::Walker::Line (depth $B::Walker::Level)";
	if ($f !~ m#^\w+(?:[/-]\w+)*[.]p[lmh]$#) { # bits/ioctl-types.ph
		print STDERR "# $msg invalid SKIP\n";
		return;
	}
	if ($B::Walker::Sub eq "BEGIN" and not $INC{$f} and $B::Walker::Opname ne "autouse") {
		print STDERR "# $msg not loaded at BEGIN SKIP\n";
		return;
	}
	if (not $Strict and grep { $f =~ $_ } @Skip) {
		print STDERR "# $msg builtin SKIP\n" if $Verbose;
		return;
	}
	if ($B::Walker::Sub eq "BEGIN" and $INC{$f}) {
		goto req;
	}
	if (not $Strict and $B::Walker::BlockData{Eval}) {
		print STDERR "# $msg inside eval SKIP\n";
		return;
	}
	if ($Relaxed and $B::Walker::Level > 4) {
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
	local $B::Walker::Opname = $opname;
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
	local $B::Walker::Opname = $class;
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
}

sub grok_version ($$@) {
	my ($class, undef, $version) = @_;
	return unless $version;
	my $f = mod2path($class);
	local $B::Walker::Opname = "version";
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
		my $arg = sv_version($sv);
		unless (defined $arg) {
			last unless $sv->can("PV");
			$arg = $sv->PV;
		}
		push @args, $arg;
		$op = $op->sibling;
	}
	return unless $$OP == $$op;
	$methods{$method}->($class, $method, @args);
}

%B::Walker::Ops = (
	'require'	=> \&grok_require,
	'dofile'	=> \&grok_require,
	'method_named'	=> \&grok_method,
	'open'		=> \&grok_perlio,
	'binmode'	=> \&grok_perlio,
	'dbmopen'	=> sub { Requires("AnyDBM_File.pm") },
	'leavetry'	=> sub { $B::Walker::BlockData{Eval} = $B::Walker::Level },
);

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
			print STDERR "dying at $0 line $CurLine\n" unless $^S;
		};
		B::Walker::walk_blocks();
		B::Walker::walk_main();
		B::Walker::walk_subs() if not $Relaxed;
		finalize();
	};
}

END {
	print STDERR "# Eval=$B::Walker::BlockData{Eval}\n" if $B::Walker::BlockData{Eval};
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
