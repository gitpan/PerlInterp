use Perl;
my $p = Perl->new(INC => USE => [qw/Perl/]);
print "1..1\n";
$p->eval(q/$INC{"Perl.pm"}/) eq $INC{"Perl.pm"} or print "not ";
print "ok 1\n";
