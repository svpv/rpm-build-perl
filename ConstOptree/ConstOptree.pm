package B::ConstOptree;
our $VERSION = '0.01';

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

# Loadable via -MO=ConstOptree
sub compile { sub {} }

1;

