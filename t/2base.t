use Perl;

BEGIN { $| = 1 }

print "1..8\n";

my $p = Perl::->new('INC');

my $script = <<'OUTEREND';
    BEGIN { $| = 1 }
    END { print "# Outer end\nok 5\n" }
    use Perl;
    print "# In outer run\nok 1\n";
    my $p = Perl::->new('INC');
    my $script = <<'INNEREND';
        BEGIN { $| = 1 }
        END { print "# Inner end\nok 4\n" }
	print "# In inner run\nok 2\n";
	package Foo;
	my $foo = bless {}, 'Foo';
	sub DESTROY { print "# Destroying " . ref($_[0]) . "\nok 3\n" }
INNEREND
    #print "About to do inner run [\n$script]\n";
    $p->eval($script);
    $p->run;		# needed to run END blocks
OUTEREND

#print "About to do outer run\n";
$p->eval($script);
$p->run;		# needed to run END blocks

{
  my $p = Perl::
    ->new(ARGV => 
        ["-le", q[print "# Hiya. I'm Pearl. Pearl Oneliner. Seeya.\nok 6"]])
    ->run;
}

print "# All done\nok 7\n";
END { print "# All end\nok 8\n" }
