use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'rpm-build-perl',
	VERSION_FROM => 'lib/B/PerlReq.pm',
	EXE_FILES => [ "perl.req", "perl.prov" ],
	PREREQ_PM => { B => 0, Safe => 0, Test::More => 0 },
	AUTHOR => 'Alexey Tourbin <at@altlinux.org>',
	ABSTRACT => '',
	dist => { COMPRESS => 'gzip -9f' },
);

package MY;
sub install {
	my $self = shift;
	return $self->SUPER::install(@_) . <<'EOF';

# for maintainer
rpm: dist
	buildreq --args "--define '_sourcedir $$PWD'" $(NAME).spec
	rpm -ba --define "_sourcedir $$PWD" $(NAME).spec

.PHONY: rpm

EOF

}
