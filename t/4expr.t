use Perl;
my $p = Perl->new;
print "1..1\n";
my $r = $p->eval($Perl::Expr{[1, {2=>3}]});
print eval { $r->[1]{2} } == 3 ? "ok 1\n" : "not ok 1\n";
