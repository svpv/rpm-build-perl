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

use 5.006;
use strict;

use B qw(class begin_av init_av main_cv main_root OPf_KIDS walksymtable);
use PerlReq::Utils qw(mod2path path2mod path2dep verf verf_perl sv_version);

our $VERSION = "0.5.1";

our ($CurCV, $CurEval, $CurLine);
our ($Strict, $Relaxed, $Verbose, $Debug);

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
# most common
	qr(^Carp\.pm$),
	qr(^DynaLoader\.pm$),
	qr(^Exporter\.pm$),
	qr(^strict\.pm$),
	qr(^vars\.pm$),
);

sub const_sv ($) {
	my $op = shift;
	my $sv = $op->sv;
	$sv = (($CurCV->PADLIST->ARRAY)[1]->ARRAY)[$op->targ] unless $$sv;
	return $sv;
}

sub RequiresPerl ($) {
	my $v = shift;
	my $dep = "perl-base >= " . verf_perl($v);
	if (not $Strict and $v < 5.006) {
		print STDERR "# $dep at line $CurLine (old perl SKIP)\n" if $Verbose;
		return;
	}
	print STDERR "# $dep at line $CurLine\n" if $Verbose;
	print "$dep\n";
}

sub Requires ($$) {
	my ($f, $v) = @_;
	my $dep = path2dep($f) . ($v ? " >= " . verf($v) : "");
	if ($f !~ /^\w+(?:\/\w+(?:-\w+)?)*\.p[lmh]$/) { # bits/ioctl-types.ph
		print STDERR "# $dep at line $CurLine (invalid SKIP)\n";
		return;
	}
	if (not $Strict and grep { $f =~ $_ } @Skip) {
		print STDERR "# $dep at line $CurLine (builtin SKIP)\n" if $Verbose;
		return;
	}
	if (not $Strict and $CurEval) {
		print STDERR "# $dep at line $CurLine inside eval (SKIP)\n";
		return;
	}
	print STDERR "# $dep at line $CurLine\n" if $Verbose;
	print "$dep\n";
}

sub grok_args ($$$) { # big bucks
	my ($OP, $module, $method) = @_;
	for (1..4) {
		my $op = $OP;
		$op = $op->next  if $$op and $op->name eq "nextstate";
		$op = $op->first if $$op and $op->name eq "lineseq";
		$op = $op->next  if $$op and $op->name eq "nextstate";
		next unless $$op and $op->name eq "pushmark";
		$op = $op->next;
		next unless $$op and $op->name eq "const";
		my $sv = const_sv($op);
		next unless $sv->can("PV") and $sv->PV eq $module;
		$op = $op->sibling;
		my @ops;
		while ($$op and $op->name eq "const") {
			push @ops, $op;
			$op = $op->sibling;
		}
		next unless $$op and $op->name eq "method_named";
		next unless const_sv($op)->PV eq $method;
		return wantarray ? @ops : $ops[0];
	} continue {
		$OP = $OP->sibling;
		return unless $$OP;
	}
	return;
}

sub grok_version ($$) {
	my ($op, $module) = @_;
	$op = grok_args($op, $module, "VERSION");
	return $op ? sv_version(const_sv($op)) : undef;
}

sub grok_import ($$) {
	my ($op, $module) = @_;
	my @ops = grok_args($op, $module, "import");
	my @words;
	for my $op (@ops) {
		my $sv = const_sv($op);
		push @words, $sv->PV if $sv->can("PV");
	}
	return @words;
}

sub grok_req ($) {
	my $op = shift;
	return unless $op->first->name eq "const";
	my $sv = const_sv($op->first);
	my $v = sv_version($sv);
	if ($v) {
		RequiresPerl($v);
		return;
	}
	my $f = $sv->PV;
	my $m = path2mod($f);
	$v = grok_version($op, $m);
	Requires($f, $v);
	return if $Relaxed;
	my @args = grok_import($op, $m);
	return unless @args;
	if ($m eq "base") {
		foreach my $m (@args) {
			my $f = mod2path($m);
			Requires($f, undef)
				if grep { -f "$_/$f" } @INC;
		}
	}
	Requires(mod2path($args[$0]), undef)
		if $m eq "autouse";
}

sub grok_optree ($;$);
sub grok_optree ($;$) {
	my ($op, $level) = (@_, 1);
	$CurLine = $op->line if $op->can("line");
	if ($CurEval and $level <= $CurEval) {
		print STDERR "# exit eval at line $CurLine\n" if $Debug;
		undef $CurEval;
	}
	if (not $CurEval and $op->name eq "leavetry") {
		$CurEval = $level;
		print STDERR "# enter eval at line $CurLine\n" if $Debug;
	}
	unless ($Relaxed and $level > 4) {
		grok_req($op) if $op->name eq "require";
		grok_req($op) if $op->name eq "dofile" and not $Relaxed;
	}
	if ($op->flags & OPf_KIDS) {
		for (my $kid = $op->first; $$kid; $kid = $kid->sibling) {
			grok_optree($kid, $level + 1);
		}
	}
	if (class($op) eq "PMOP") {
		my $root = $op->pmreplroot;
		grok_optree($root, $level + 1)
			if ref($root) and $root->isa("B::OP");
	}
}

sub grok_cv ($);
sub grok_cv ($) {
	my $cv = $CurCV = shift;
	return if $cv->FILE ne $0;
	grok_optree($cv->ROOT) if ${$cv->ROOT};
	return unless $cv->PADLIST->can("ARRAY");
	for my $anon ($cv->PADLIST->ARRAY->ARRAY) {
		next if class($anon) ne "CV";
		grok_cv($anon);
	}
}

sub B::GV::grok_gv ($) {
	my $gv = shift;
	my $cv = $gv->CV;
	$CurLine = $gv->LINE;
	grok_cv($cv) if $$cv;
}

sub grok_subs () {
	walksymtable(\%::, 'grok_gv', sub { 1 }, undef);
}

sub grok_blocks () {
	for my $block (begin_av, init_av) {
		next unless $block->isa("B::AV");
		grok_cv($_) for $block->ARRAY;
	}
}

sub grok_main () {
	my $cv = $CurCV = main_cv;
	grok_optree(main_root) if ${main_root()};
	return unless $cv->PADLIST->can("ARRAY");
	for my $anon ($cv->PADLIST->ARRAY->ARRAY) {
		next if class($anon) ne "CV";
		grok_cv($anon);
	}
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
			print STDERR "# died at $0 line $CurLine:\n# @_";
			require Carp; Carp::confess;
		};
		grok_blocks();
		grok_main();
		grok_subs() if not $Relaxed;
	}
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

Copyright (c) 2004 Alexey Tourbin, ALT Linux Team.

This is free software; you can redistribute it and/or modify it under
the terms of the GNU Library General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

=head1	SEE ALSO

L<B>, L<B::Deparse>, L<PerlReq::Utils>, L<perl.req>
