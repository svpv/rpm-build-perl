package B::Clobbers;
our $VERSION = '0.01';

use strict;
use B::Walker qw(padval walk);
use B qw(ppname OPpLVAL_INTRO);

our @vars = qw(_ /);
our %vars = map { $_ => 1 } @vars;
our $Verbose = 1;

sub do_rv2sv ($) {
	my $op = shift;
	$op = $op->first;
	return unless $op->name eq "gvsv";
	my $var = padval($op->padix)->SAFENAME;
	return unless $vars{$var};
	if ($op->private & OPpLVAL_INTRO) {
		$B::Walker::BlockData{$var} = 1;
		print STDERR "local \$$var at $0 line $B::Walker::Line\n" if $Verbose;
	}
	elsif ($op = $op->next and $$op and $op->name eq "sassign") {
		return if $B::Walker::BlockData{$var};
		print "\t*** \$$var clobbered at $0 line $B::Walker::Line\n";
	}
}

sub do_readline ($) {
	my $op = shift;
	$op = $op->next;
	$op = $op->first while ref($op) eq "B::UNOP";
	return unless $op->name eq "gvsv";
	my $var = padval($op->padix)->SAFENAME;
	return unless $vars{$var};
	return if $B::Walker::BlockData{$var};
	print "\t*** \$$var clobbered at $0 line $B::Walker::Line\n";
}

sub do_enteriter ($) {
	my $op = shift;
	my $op = $op->first->sibling->sibling;
	return unless $$op;
	$op = $op->first if $op->name eq "rv2gv";
	return unless $op->name eq "gv";
	my $gv = ref($op) eq "B::PADOP" ? padval($op->padix) : $op->gv;
	my $var = $gv->SAFENAME;
	return unless $vars{$var};
	print STDERR "implicitly localized \$$var at $0 line $B::Walker::Line\n" if $Verbose;
	$B::Walker::BlockData{_} = 1;
}

%B::Walker::Ops = (
	pp_rv2sv	=> \&do_rv2sv,
	readline	=> \&do_readline,
	enteriter	=> \&do_enteriter,
	grepwhile	=> sub { $B::Walker::BlockData{_} = 1 },
	mapwhile	=> sub { $B::Walker::BlockData{_} = 1 },
);

sub compile {
	return sub {
		local $| = 1;
		walk();
	}
}

1;
