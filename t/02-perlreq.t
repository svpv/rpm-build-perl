use Test::More qw(no_plan);
use strict;

use Config qw(%Config);
use Fcntl qw(F_SETFD);

sub spawn ($) {
	my $file = shift;
	use 5.007_001; # the list form of open() for pipes
	open my $pipe, "-|", $^X, qw(-Mblib perl.req) => $file
		or return (undef, undef);
	my $output = join '' => <$pipe>;
	return (close($pipe), $output);
}

sub grok ($) {
	my $file = shift;
	fcntl(STDERR, F_SETFD, 1);
	my ($ok, $output) = spawn($file);
	if (not $ok) {
		fcntl(STDERR, F_SETFD, 0);
		spawn($file);
	}
	chomp $output;
	$output =~ s/\s+/ /g;
	return $output;
}

sub Requires ($$) {
	my ($f, $expected) = @_;
	ok -f $f, "$f exists";
	my $got = grok($f);
	cmp_ok $got, "eq", $expected, "$f dependencies";
	ok $? == 0, "$f zero exit status";
}

my ($lib, $arch) = @Config{qw{installprivlib installarchlib}};

# Valid for perl-5.8.0 - perl-5.8.9.
Requires "$lib/AutoLoader.pm"	=> "perl-base >= 1:5.6.1";
Requires "$lib/constant.pm"	=> "perl(warnings/register.pm) perl-base >= 1:5.6.0";
Requires "$lib/Exporter.pm"	=> "perl(Exporter/Heavy.pm) perl-base >= 1:5.6.0";
Requires "$lib/File/Basename.pm" => "perl(re.pm) perl(warnings.pm) perl-base >= 1:5.6.0";
Requires "$arch/IO/File.pm"	=> "perl(File/Spec.pm) perl(IO/Seekable.pm) perl(SelectSaver.pm) perl(Symbol.pm) perl-base >= 1:5.6.1";
Requires "$arch/File/Glob.pm"	=> "perl(Text/ParseWords.pm) perl(XSLoader.pm)";
Requires "$arch/Socket.pm"	=> "perl(warnings/register.pm) perl(XSLoader.pm)";

