package fake;
use strict;

# from autoconf_2.5.spec:
# %define __spec_autodep_custom_pre export autom4te_perllibdir=%buildroot%_datadir/%realname%suff
#
# from /usr/bin/autoheader-2.5:
# BEGIN
# {
#   my $datadir = $ENV{'autom4te_perllibdir'} || '/usr/share/autoconf-2.5';
#   unshift @INC, "$datadir";
# }
#
# The problem is that whenever autoconf is getting built, files from
# /usr/share/autoconf-2.5 of already installed autoconf package are used
# for dependency tracking.
#
# To solve this @INC should be reordered at INIT stage, so that %buildroot
# directories take precedence.
#
# Typical invocation:
# perl -Mfake -MO=Deparse $RPM_BUILD_ROOT/usr/bin/autoheader-2.5

sub adjusted_inc {
	my @inc;
	foreach my $path (grep { /^\// } @INC) {
		push @inc, "$ENV{RPM_BUILD_ROOT}$path"
			unless index($path, $ENV{RPM_BUILD_ROOT}) == 0
				and grep { $_ eq "$ENV{RPM_BUILD_ROOT}$path" } @inc;
		push @inc, $path unless grep { $_ eq $path } @inc;
	}
	return @inc;
}

INIT {
	@INC = adjusted_inc()
		if $ENV{RPM_BUILD_ROOT};
}

1;
