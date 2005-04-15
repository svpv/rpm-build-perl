Name: rpm-build-perl
Version: 0.5.1
Release: alt5

Summary: RPM helper scripts to calculate Perl dependencies
License: GPL
Group: Development/Other

URL: %CPAN %name
Source: %name-%version.tar.gz

# http://www.google.com/search?q=%22base.pm+and+eval%22&filter=0
# http://www.google.com/search?q=%22base.pm%20import%20stuff%22&filter=0
Patch0: perl5-alt-base_pm-syntax-hack.patch

# for x86_64
%define _libdir %_prefix/lib

BuildArch: noarch
Requires: perl(B.pm) perl(O.pm) perl(Safe.pm)

Conflicts: rpm-build <= 4.0.4-alt24
Conflicts: perl-devel <= 1:5.8.1-alt4

# Automatically added by buildreq on Fri Apr 15 2005
BuildRequires: perl-devel

%description
These herlper scripts will look at perl source files in your package,
and will use this information to generate automatic Requires and Provides
tags for the package.

%prep
%setup -q
%__cp -av %(eval "`%__perl -V:installprivlib`"; echo "$installprivlib")/base.pm .
%patch0 -p4

%build
%perl_vendor_build

%install
%perl_vendor_install INSTALLSCRIPT=%_libdir/rpm
%__mv %buildroot%perl_vendor_privlib/{base,fake}.pm %buildroot%_libdir/rpm
%__ln_s `relative %perl_vendor_privlib/B %_libdir/rpm/B` %buildroot%_libdir/rpm/B
%__ln_s `relative %perl_vendor_privlib/PerlReq %_libdir/rpm/PerlReq` %buildroot%_libdir/rpm/PerlReq

%__mkdir_p %buildroot%_sysconfdir/rpm/macros.d
%__cp -av perl5-alt-rpm-macros %buildroot%_sysconfdir/rpm/macros.d/perl5

%files
%doc README.ALT
%_libdir/rpm/perl.req
%_libdir/rpm/perl.prov
%_libdir/rpm/base.pm
%_libdir/rpm/fake.pm
#_libdir/rpm/B
#_libdir/rpm/PerlReq
%dir %perl_vendor_privlib/B
%perl_vendor_privlib/B/PerlReq.pm
%dir %perl_vendor_privlib/PerlReq
%perl_vendor_privlib/PerlReq/Utils.pm
%config	%_sysconfdir/rpm/macros.d/perl5

%changelog
* Fri Apr 15 2005 Alexey Tourbin <at@altlinux.ru> 0.5.1-alt5
- B/PerlReq.pm: track require_version() calls
- perl.req: restrict LD_LIBRARY_PATH to /usr/lib64 and /usr/lib

* Wed Apr 06 2005 Alexey Tourbin <at@altlinux.ru> 0.5.1-alt4
- B/PerlReq.pm: track PerlIO dependencies for "open" and "binmode"
- perl.prov: allow more opcodes for Safe->reval

* Wed Mar 16 2005 Alexey Tourbin <at@altlinux.ru> 0.5.1-alt3
- %name.spec: use the same %_prefix/lib/rpm directory on x86_64
- perl.prov: decrease verbosity when processing *.al files
- macros.d/perl5: preserve timestamps when making test

* Thu Dec 23 2004 Alexey Tourbin <at@altlinux.ru> 0.5.1-alt2
- perl.req: explode() was not imported

* Wed Dec 22 2004 Alexey Tourbin <at@altlinux.ru> 0.5.1-alt1
- released on CPAN (see %url)
- perl.prov: workaround perl bug #32967
- added partial support for relative paths
- restored OS2 pattern in skip lists (Andrei Bulava, #5713)
- enhanced error handling and debugging output

* Mon Dec 06 2004 Alexey Tourbin <at@altlinux.ru> 0.5-alt1
- bumped version (0.3 -> 0.5) to reflect major changes
- implemented B::PerlReq and made perl.req use it instead of B::Deparse
- new PerlReq::Utils module (convertion and formatting routines)
- version numbers now rounded to 3 digits after decimal point
- v-string versions now treated as floats (e.g. 1.2.3 -> 1.002)
- all dependencies on particular perl version converted to 1:5.x.y form
- enabled version extraction from PREREQ_PM in Makefile.PL
- wrote/updated/enhanced documentation, started README.ALT
- started test suite (more than 50 tests)
- downgraded perl requirements to 5.6.0

* Thu Jul 01 2004 Alexey Tourbin <at@altlinux.ru> 0.3-alt1.1
- perl.req: removed duplicating code
- macros.d/perl: fixed quoting

* Sun Jun 20 2004 Alexey Tourbin <at@altlinux.ru> 0.3-alt1
- macros.d/perl:
  + MDK compatibility: added %%perl_vendor{lib,arch} directories
  + build: fix sharpbang magic lines (with a weired sed expression)
  + MM_install: don't fake PREFIX, rather specify DESTDIR (for gimp-perl)
- perl.req:
  + adjust LD_LIBRARY_PATH for libraries inside buildroot (Yury Konovalov)
  + implemented tracker for dependencies like `use base qw(Foo Bar)'

* Sat May 08 2004 Alexey Tourbin <at@altlinux.ru> 0.2-alt5
- macros.d/perl: added build/install support for Module::Build

* Wed Apr 28 2004 Alexey Tourbin <at@altlinux.ru> 0.2-alt4
- perl.req:
  + s/use v5.8.0/use v5.8.1/ (to stop questions, it's all about B::Deparse)
  + don't simply require perl-base (don't bloat out, it's in basesystem)
- macros.d/perl
  + don't remove comments produced by autosplit (line numbering lost)
  + drop PRINT_PREREQ stuff for a while

* Thu Feb 26 2004 Alexey Tourbin <at@altlinux.ru> 0.2-alt3
- perl.req: try to recover with -M$superclass on failures
- perl.prov: enhanced version detection

* Mon Dec 22 2003 Alexey Tourbin <at@altlinux.ru> 0.2-alt2.2
- yet another hot fix

* Thu Dec 18 2003 Alexey Tourbin <at@altlinux.ru> 0.2-alt2.1
- yet another hot fix

* Thu Dec 18 2003 Alexey Tourbin <at@altlinux.ru> 0.2-alt2
- don't produce dependencies on fake.pm

* Wed Dec 17 2003 Alexey Tourbin <at@altlinux.ru> 0.2-alt1
- fake.pm introduced (@INC entries rearrangement)
- perl.prov manpage introduced
- various fixes

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
