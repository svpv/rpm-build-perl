package fake;
use strict;

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
