#
# Perl - Perl within Perl
#

use 5.005;
package Perl;
require DynaLoader;
@ISA = qw( DynaLoader );

$VERSION = $VERSION = "0.02"; 

bootstrap Perl;

1;
