use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'rpm-build-perl',
	VERSION_FROM => 'lib/B/PerlReq.pm',
	EXE_FILES => [ "perl.req", "perl.prov" ],
	PREREQ_PM => { B => 0, Safe => 0, Test::More => 0 },
	AUTHOR => 'Alexey Tourbin <at@altlinux.org>',
	ABSTRACT => 'Calculate dependencies for Perl sources',
	dist => { COMPRESS => 'gzip -9f' },
);

package MY;
sub install {
	my $self = shift;
	return $self->SUPER::install(@_) . <<'EOF';

# for maintainer
buildreq: dist
	buildreq --args "--define '_sourcedir $$PWD'" $(NAME).spec

rpm: dist
	rpm -ba --define "_sourcedir $$PWD" $(NAME).spec

.PHONY: buildreq rpm

EOF

}
