package B::Walker;
our $VERSION = 0.12;

use 5.006;
use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(padname padval const_methop const_sv walk);

our $CV;

sub padname ($) {
	my $targ = shift;
	return $CV->PADLIST->ARRAYelt(0)->ARRAYelt($targ);
}

sub padval ($) {
	my $targ = shift;
	return $CV->PADLIST->ARRAYelt(1)->ARRAYelt($targ);
}

## by viy@; from Module::Info 0.37
sub const_sv {
    my $op = shift;
    my $sv;
    
    if ($op->name eq 'method_named' && $op->can('meth_sv')) {
        $sv = $op->meth_sv;
    }
    elsif ($op->can('sv')) {
        $sv = $op->sv;
    }
    # the constant could be in the pad (under useithreads)
    $sv = padval($op->targ) unless ref($sv) && $$sv;
    return $sv;
}

sub const_methop ($) {
	my $op = shift;
	my $sv = $op->meth_sv;
	$sv = padval($op->targ) unless $$sv;
	return $sv;
}

our $Level = 0;
our $Line;
our $Sub;
our $Opname;

our %Ops;
our %BlockData;

my %startblock = map { $_ => 1 }
	qw(leave leaveloop leavesub leavesublv leavetry
		grepwhile mapwhile scope);

sub walk_root ($);
sub walk_root ($) {
	my $op = shift;
	my $ref = ref($op);
	if ($ref eq "B::COP") {
		$Line = $op->line;
		return;
	}
	my $name = $op->name;
	use B qw(ppname);
	$name = ppname($op->targ) if $name eq "null";
	local $Level = $Level + 1;
	local %BlockData = %BlockData if $startblock{$name};
	local $Opname = $name if $Ops{$name};
	$Ops{$name}->($op) if $Ops{$name} and $Line;
	if ($ref eq "B::PMOP") {
		my $root = $op->pmreplroot;
		if (ref($root) and $root->isa("B::OP")) {
			walk_root($root);
		}
	}
	use B qw(OPf_KIDS);
	if ($op->flags & OPf_KIDS) {
		if ($ref eq 'B::OP') {
			# B::OP has no ->first method; 
			# can be returned from bad xs (see optimizer 0.08 with perl 5.22)
			# (can't determine class of operator method_named, assuming BASEOP)
			return;
		}
		for ($op = $op->first; $$op; $op = $op->sibling) {
			walk_root($op);
		}
	}
}

sub walk_cv ($);

sub walk_av ($$) {
	my ($name, $av) = @_;
	return if ref($av) ne "B::AV";
	local $Sub = $name;
	walk_cv($_) for $av->ARRAY;
}

sub walk_pad ($) {
	my $pad = shift;
	return unless $pad->can("ARRAY");
	walk_av ANON => $pad->ARRAY;
}

sub walk_cv ($) {
	my $cv = shift;
	return if ref($cv) ne "B::CV";
	return if $cv->FILE and $cv->FILE ne $0;
	local $CV = $cv;
	walk_root($cv->ROOT) if ${$cv->ROOT};
	walk_pad($cv->PADLIST);
}

sub walk_blocks () {
	use B qw(begin_av init_av);
	walk_av "BEGIN" => begin_av;
	walk_av "INIT" => init_av;
}

sub walk_main () {
	use B qw(main_cv main_root);
	local $Sub = "MAIN";
	local $CV = main_cv;
	walk_root(main_root) if ${main_root()};
	walk_cv(main_cv);
}

sub walk_gv ($) {
	my $gv = shift;
	my $cv = $gv->CV;
	return unless ( $$cv && ref($cv) eq "B::CV" );
	return if $cv->XSUB;
	local $Sub = $gv->SAFENAME;
	$Line = $gv->LINE;
	walk_cv($cv);
}

sub walk_stash ($$);
sub walk_stash ($$) { # similar to B::walksymtable
	my ($symref, $prefix) = @_;
	for my $sym (keys %$symref) {
		no strict 'refs';
		my $fullname = "*main::". $prefix . $sym;
		if ($sym =~ /::\z/) {
			$sym = $prefix . $sym;
			walk_stash(\%$fullname, $sym)
				if $sym ne "main::" && $sym ne "<none>::";
		}
		else {
			use B qw(svref_2object);
			walk_gv(svref_2object(\*$fullname))
				if *$fullname{CODE};
		}
	}
}

sub walk_subs () {
	walk_stash \%::, '';
}

sub walk () {
	walk_blocks();
	walk_main();
	walk_subs();
}

1;

__END__

=head1	NAME

B::Walker - dumb walker, optree ranger

=head1	COPYING

Copyright (c) 2006, 2007 Alexey Tourbin, ALT Linux Team.
Adapted to perl 2.2x' B by Igor Vlasenko, ALT Linux Team.

This is free software; you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation;
either version 2 of the License, or (at your option) any later version.

=head1	SEE ALSO

L<B::Utils>
