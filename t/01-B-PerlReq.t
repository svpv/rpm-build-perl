use Test::More qw(no_plan);
use strict;

use B::PerlReq;
use PerlReq::Utils;
use Fcntl qw(F_SETFD);

sub spawn ($) {
	my $code = shift;
	open my $pipe, "-|", $^X, qw(-Mblib -MO=PerlReq -e) => $code
		or return (undef, undef);
	my $output = join '' => <$pipe>;
	return (close($pipe), $output);
}

sub grok ($) {
	my $code = shift;
	fcntl(STDERR, F_SETFD, 1);
	my ($ok, $output) = spawn($code);
	if (not $ok) {
		fcntl(STDERR, F_SETFD, 0);
		spawn($code);
	}
	chomp $output;
	return $output;
}

my $m = "Data::Dumper";
my $f = "Data/Dumper.pm";
my $d = "perl($f)";

my $m2 = "File::Basename";
my $f2 = "File/Basename.pm";
my $d2 = "perl($f2)";

my $m3 = "Tie::Hash";
my $f3 = "Tie/Hash.pm";
my $d3 = "perl($f3)";

cmp_ok $d, "eq", grok qq(use $m;);
cmp_ok $d, "eq", grok qq(require $m;);
cmp_ok $d, "eq", grok qq(require "$f";);

cmp_ok $d, "eq", grok qq(BEGIN { use $m; });
cmp_ok $d, "eq", grok qq(BEGIN { require $m; });
cmp_ok $d, "eq", grok qq(INIT  { require "$f"; });

cmp_ok $d, "eq", grok qq(sub x { require $m; });
cmp_ok $d, "eq", grok qq(sub x { my \$x = sub { require $m; }});
cmp_ok $d, "eq", grok qq(my \$x = sub { require $m; });
cmp_ok $d, "eq", grok qq(my \$x = sub { my \$x = sub { require $m; }});

cmp_ok $d, "eq", grok qq(sub x { local *x = sub { require $m; }});
cmp_ok $d, "eq", grok qq(local *x = sub { require $m; });
cmp_ok $d, "eq", grok qq(local *x = sub { local *x = sub { require $m; }});

cmp_ok '',  'eq', grok qq(eval { require $m; };);
cmp_ok $d2, 'eq', grok qq(eval { require $m; }; require $m2; eval { require $m3 };);
cmp_ok $d2, 'eq', grok qq({eval { require $m; };} require $m2; {eval { require $m3 };});
cmp_ok $d2, 'eq', grok qq(my \$x = sub { eval { require $m; }; require $m2; };);
cmp_ok $d2, 'eq', grok qq(eval { eval { require $m; }; require $m; }; require $m2;);
cmp_ok $d2, 'eq', grok qq(eval { require $m; } || eval { require $m3; }; require $m2;);

cmp_ok "$d >= 2.0",	'eq', grok qq(use $m 2;);
cmp_ok "$d >= 2.0",	'eq', grok qq(use $m 2.0;);
cmp_ok "$d >= 2.0",	'eq', grok qq(use $m 2.00;);
cmp_ok "$d >= 2.0",	'eq', grok qq(use $m 2.000998;);
cmp_ok "$d >= 2.001",	'eq', grok qq(use $m 2.000999;);
cmp_ok "$d >= 2.010",	'eq', grok qq(use $m 2.01;);
cmp_ok "$d >= 2.012",	'eq', grok qq(use $m 2.012;);
cmp_ok "$d >= 2.019",	'eq', grok qq(use $m 2.0199;);
cmp_ok "$d >= 2.0",	'eq', grok qq(use $m v2;);
cmp_ok "$d >= 2.0",	'eq', grok qq(use $m v2.0;);
cmp_ok "$d >= 2.0",	'eq', grok qq(use $m v2.0.998;);
cmp_ok "$d >= 2.001",	'eq', grok qq(use $m v2.0.999;);
cmp_ok "$d >= 2.001",	'eq', grok qq(use $m 2.1.1;);
cmp_ok "$d >= 2.001",	'eq', grok qq(use $m v2.1.1;);

cmp_ok "perl(base.pm)\n$d",		'eq', grok qq(use base qw($m););
cmp_ok "perl(base.pm) >= 1.0\n$d",	'eq', grok qq(use base 1 qw($m););
cmp_ok "perl(base.pm)\n$d\n$d2",	'eq', grok qq(use base qw($m $m2););
cmp_ok "$d3\nperl(base.pm)",		'eq', grok qq(use $m3; use base "Tie::StdHash";);

cmp_ok "perl(autouse.pm)\n$d", 'eq', grok qq(use autouse "$m";);
cmp_ok "perl(autouse.pm)\n$d", 'eq', grok qq(use autouse $m => qw(Dumper););

cmp_ok '', 'eq', grok qq(   \$path="$f"; require \$path;);
cmp_ok '', 'eq', grok qq(my \$path="$f"; require \$path;);
cmp_ok '', 'eq', grok qq(require "./Data/Dumper.pm";);

cmp_ok "$d >= 2.0",			'eq', grok "require $m; $m->VERSION(2);";
cmp_ok "$d >= 2.0",			'eq', grok "require $m; $m->require_version(2);";
cmp_ok "perl(base.pm)\n$d",		'eq', grok "require base; base->import($m)";
cmp_ok "perl(base.pm) >= 1.0\n$d",	'eq', grok "require base; base->VERSION(1); base->import($m)";
cmp_ok "perl(base.pm) >= 1.0\n$d",	'eq', grok "require base; base->import($m); base->VERSION(1);";

cmp_ok "perl-base >= 1:5.6.0\n$d", 'eq', grok qq(require 5.006; *x = sub { require $m;};);

cmp_ok "$d\n$d2", "eq", grok qq(require $m; *x = sub { require $m2; };);
cmp_ok "$d\n$d2", "eq", grok qq(require $m; my \$x = sub { require $m2; };);

cmp_ok "perl(PerlIO.pm)\nperl(PerlIO/scalar.pm)", "eq", grok q(open FH, "<", \$ref);
cmp_ok "perl(PerlIO.pm)\nperl(PerlIO/scalar.pm)", "eq", grok q(open my $fh, "<", \my $ref);

cmp_ok "perl(PerlIO.pm)\nperl(PerlIO/encoding.pm)\nperl(Encode.pm)", "eq", grok q(open FH, "<:encoding(cp1251)", $0);
cmp_ok "perl(PerlIO.pm)\nperl(PerlIO/encoding.pm)\nperl(Encode.pm)", "eq", grok q(binmode STDOUT, ":encoding(cp1251)");

#END { $? = 0; }
