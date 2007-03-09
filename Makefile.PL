use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'rpm-build-perl',
	VERSION_FROM => 'lib/B/PerlReq.pm',
	EXE_FILES => [ qw(perl.req perl.req.files perl.prov perl.prov.files) ],
	PREREQ_PM => { B => 0, O => 0, Safe => 0, Test::More => 0, Encode => 0 },
	AUTHOR => 'Alexey Tourbin <at@altlinux.org>',
	ABSTRACT => 'Calculate dependencies for Perl sources',
	dist => { COMPRESS => 'gzip -9f' },
);

package MY;
sub install {
	my $self = shift;
	return $self->SUPER::install(@_) . <<'EOF';

perl.prov.files: perl.req.files
	$(PERL) -pe 's/requires/provides/g; s/req/prov/g' $< >$@
	$(CHMOD) $(PERM_RWX) $@

EOF

}
