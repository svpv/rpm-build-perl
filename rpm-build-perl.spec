Name: rpm-build-perl
Version: 0.1
Release: alt8

Summary: RPM helper scripts that calculate Perl dependencies
License: GPL or LGPL
Group: Development/Other

Source0: rpm-perl.req
Source1: rpm-perl.prov
Source2: perl5-alt-rpm-macros

# http://www.google.com/search?q=%22base.pm+and+eval%22&filter=0
# http://www.google.com/search?q=%22base.pm%20import%20stuff%22&filter=0
Patch0: perl5-alt-base_pm-syntax-hack.patch.gz

BuildArch: noarch

Requires: %_sysconfdir/rpm/macros.d
Requires: perl(B/Deparse.pm) perl(O.pm)

BuildPreReq: perl(base.pm)

Conflicts: rpm-build <= 4.0.4-alt24
Conflicts: perl-devel <= 1:5.8.1-alt4

%description
These herlper scripts will look at perl source files in your package,
and will use this information to generate automatic Requires and Provides
tags for the package.

%prep
%setup -cT
%__cp -a %SOURCE0 perl.req
%__cp -a %SOURCE1 perl.prov
%__cp -a %(eval "`%__perl -V:installprivlib`"; echo "$installprivlib")/base.pm .
%patch0 -p4

%build
pod2man perl.req > perl.req.1

%install
%__install -pD -m755 perl.req	%buildroot%_libdir/rpm/perl.req
%__install -pD -m755 perl.prov	%buildroot%_libdir/rpm/perl.prov
%__install -pD -m644 base.pm	%buildroot%_libdir/rpm/base.pm
%__install -pD -m644 perl.req.1	%buildroot%_man1dir/perl.req.1
%__install -pD -m644 %SOURCE2	%buildroot%_sysconfdir/rpm/macros.d/perl5

%files
%_libdir/rpm/perl.req
%_libdir/rpm/perl.prov
%_libdir/rpm/base.pm
%_man1dir/perl.*
%config	%_sysconfdir/rpm/macros.d/perl5

%changelog
* Tue Nov 04 2003 Alexey Tourbin <at@altlinux.ru> 0.1-alt8
- perl.req:
  + use $RPM_BUILD_ROOT%_bindir/perl whenever available (experimental,
    makes it possible to build incompatible perl)
- macros.d/perl5
  + check for undefined symbols added
  + turned macro arguments into shell function arguments
  + %%CPAN macro added for easy URLs

* Thu Oct 09 2003 Alexey Tourbin <at@altlinux.ru> 0.1-alt7
- perl.req: 
  + counter of perl variables in isPerl() fixed
  + prolog detection enhanced

* Tue Oct 07 2003 Alexey Tourbin <at@altlinux.ru> 0.1-alt6
- perl.req: 
  + isPerl(): try to detect non-perl files (in particular, Polish
    and Prolog *.pl files) and allow failures even in normal mode
  + PRINT_PREREQ dependencies used only in strict mode

* Fri Oct 03 2003 Alexey Tourbin <at@altlinux.ru> 0.1-alt5
- perl.req: strip comments in shebang

* Sun Sep 28 2003 Alexey Tourbin <at@altlinux.ru> 0.1-alt4
- base.pm hacked and placed into %_libdir/rpm in order to avoid
  some weird syntax-check problems

* Fri Sep 26 2003 Alexey Tourbin <at@altlinux.ru> 0.1-alt3
- handling of #!perl command line options implemented

* Tue Sep 23 2003 Alexey Tourbin <at@altlinux.ru> 0.1-alt2
- /etc/rpm/macros.d/perl5 moved here from perl-devel package
- fixed RPM_PERL_LIB_PATH processing

* Thu Sep 18 2003 Alexey Tourbin <at@altlinux.ru> 0.1-alt1
- the package spawned from rpm-build
- fixed handling of taint-mode scripts
- perl.req(1) manual page created
