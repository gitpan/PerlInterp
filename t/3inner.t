use Perl;
BEGIN { $| = 1 }
my $p = Perl::->new('INC');
$p->eval(q[BEGIN { $| = 1 } do "t/2base.t";]);
$p->run;
