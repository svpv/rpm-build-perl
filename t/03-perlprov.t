use Test::More qw(no_plan);
use strict;

use Config qw(%Config);
use Fcntl qw(F_SETFD);

sub spawn ($) {
	my $file = shift;
	open my $pipe, "-|", $^X, qw(-Mblib perl.prov) => $file
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

sub Provides ($$) {
	my ($f, $expected) = @_;
	ok -f $f, "$f exists";
	my $got = grok($f);
	like $got, qr/^\Q$expected\E(\d|$)/, "$f dependencies";
	ok $? == 0, "$f zero exit status";
}

my ($lib, $arch) = @Config{qw{installprivlib installarchlib}};

Provides "$lib/attributes.pm"	=> "perl(attributes.pm) = 0.";
Provides "$lib/AutoLoader.pm"	=> "perl(AutoLoader.pm) = 5.";
Provides "$lib/base.pm"		=> "perl(base.pm) = ";
Provides "$lib/constant.pm"	=> "perl(constant.pm) = 1.0";
Provides "$lib/Exporter.pm"	=> "perl(Exporter.pm) = 5.5";
Provides "$lib/fields.pm"	=> "perl(fields.pm) = ";
Provides "$lib/File/Basename.pm" => "perl(File/Basename.pm) = 2.";
Provides "$lib/Getopt/Long.pm"	=> "perl(Getopt/Long.pm) = 2.";
Provides "$lib/perl5db.pl"	=> "perl(perl5db.pl)";

Provides "$arch/Cwd.pm"		=> "perl(Cwd.pm) = ";
Provides "$arch/Data/Dumper.pm"	=> "perl(Data/Dumper.pm) = 2.1";
Provides "$arch/IO/File.pm"	=> "perl(IO/File.pm) = 1.";
Provides "$arch/File/Glob.pm"	=> "perl(File/Glob.pm) = ";
Provides "$arch/Socket.pm"	=> "perl(Socket.pm) = 1.7";
Provides "$arch/POSIX.pm"	=> "perl(POSIX.pm) = 1.0";

