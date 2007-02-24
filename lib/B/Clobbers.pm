package B::Clobbers;
our $VERSION = '0.01';

use strict;
use B::Walker qw(padval walk);
use B qw(ppname OPpLVAL_INTRO);

sub gvname ($) {
	my $op = shift;
	return padval($op->padix)->SAFENAME;
}

our @vars = qw(_ /);
our %vars = map { $_ => 1 } @vars;
our $Verbose = 1;

sub do_rv2sv ($) {
	my $op = shift;
	$op = $op->first;
	return unless $op->name eq "gvsv";
	my $var = gvname($op);
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
	my $var = gvname($op);
	return unless $vars{$var};
	return if $B::Walker::BlockData{$var};
	print "\t*** \$$var clobbered at $0 line $B::Walker::Line\n";
}


%B::Walker::Ops = (
	pp_rv2sv	=> \&do_rv2sv,
	readline	=> \&do_readline,
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
