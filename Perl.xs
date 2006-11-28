/*
 * Perl.xs
 *
 * Gurusamy Sarathy <gsar@umich.edu>
 *
 * Modified 2004-01-08 by Ben Morrow <ben@morrow.me.uk>
 *
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "embed.h"

#define NEED_eval_pv
#include "ppport.h"

#ifndef MULTIPLICITY
#  error "You must build perl with -Dusemultiplicity"
#endif

EXTERN_C void xs_init(pTHX);

struct Perl_t {
        PerlInterpreter *i;
        char           **argv;
        int              argc;
        bool             done_parse;
};

typedef struct Perl_t *Perl;

static bool do_debug = 0;
#define debug if(do_debug) warn

#define dSUBPERL void *mainperl = PERL_GET_CONTEXT

#define SUBPERL(p)                      \
    STMT_START {                        \
	mainperl = PERL_GET_CONTEXT;    \
	debug("SUBPERL:  %#lx -> %#lx", \
          mainperl, (void *)(p->i));    \
	PERL_SET_CONTEXT(p->i);         \
    } STMT_END

#define MAINPERL                        \
    STMT_START {                        \
	void *tmp = PERL_GET_CONTEXT;   \
	PERL_SET_CONTEXT(mainperl);     \
	debug("MAINPERL: %#lx -> %#lx", \
          tmp, mainperl);               \
    } STMT_END

MODULE = Perl		PACKAGE = Perl

PROTOTYPES: DISABLE

void
_set_debug(to)
    bool to
CODE:
    do_debug = to;

Perl
_new(class)
    const char *class
CODE:
    {
	dSUBPERL;

        if(strNE(class, "Perl"))
            croak("Perl::_new can only construct Perl objects");

	New(999, RETVAL, 1, struct Perl_t);
	RETVAL->i          = perl_alloc();
        RETVAL->done_parse = 0;
        RETVAL->argc       = 0;
        RETVAL->argv       = NULL;
	MAINPERL;
	
	if (!RETVAL->i) {
	    Safefree(RETVAL);
	    XSRETURN_UNDEF;
	}

	SUBPERL(RETVAL);
 	perl_construct(RETVAL->i);

	MAINPERL;
	SPAGAIN;
    }
OUTPUT:
    RETVAL

Perl
_add_argv(interp, ...)
    Perl interp
CODE:
    {
        char **av, *arg_p;
        int ac;
        STRLEN arg_l;
	dSUBPERL;

        RETVAL = interp;

        if (interp->done_parse)
            croak("can't add to argv after parse has been called");
        if (items <= 1)
            goto out;
 
	if(!interp->argc)
	    interp->argc++;

        New(999, av, items + interp->argc, char*);
        av[0] = "perl";

        debug("_add_argv: i->ac=%d, items=%d", interp->argc, items);

        ac = 1;
	while (ac < interp->argc) {
            av[ac] = interp->argv[ac];
            debug("_add_argv: copy av[%d]=%s", ac, av[ac]);
            ++ac;
        }

	interp->argc--; /* should really be items-- */

        while (ac < interp->argc + items) {
            arg_p  = SvPV(ST(ac - interp->argc), arg_l);
	    
	    SUBPERL(interp);
            av[ac] = savepvn(arg_p, arg_l);
	    MAINPERL;
            
	    debug("_add_argv: new  av[%d]=%s", ac, av[ac]);
            ++ac;
        }

        av[ac] = Nullch;
        Safefree(interp->argv);
        interp->argv = av;
        interp->argc = ac;

    out:
        debug("_add_argv: now i->ac=%d", interp->argc);
    }

void
_argv(interp)
    Perl interp
PREINIT:
    int i;
PPCODE:
    if(interp->argc) {
        EXTEND(SP, interp->argc - 1);
        for (i = 1; i < interp->argc; i++) {
            PUSHs(sv_2mortal(newSVpv(interp->argv[i], 0)));
        }
    }

int
_parse(interp)
    Perl interp
CODE:
    {
        dSUBPERL;

        if(interp->done_parse)
            croak("parse has already been called on this interpreter");
        if(!interp->argc)
            croak("you must set some argvments before you call parse");

        SUBPERL(interp);
        RETVAL = perl_parse(interp->i, xs_init, interp->argc, interp->argv, environ);
        interp->done_parse = 1;

	MAINPERL;
	SPAGAIN;
    }
OUTPUT:
    RETVAL

int
run(interp)
    Perl	interp
CODE:
    {
    	dSUBPERL;

	SUBPERL(interp);
	RETVAL = perl_run(interp->i);
	MAINPERL;
	SPAGAIN;
    }
OUTPUT:
    RETVAL


SV *
_eval(interp, script)
    Perl	interp
    char *script
CODE:
    {
    	dSUBPERL;
	char *rv_p;
	STRLEN rv_l;
	SV *rv_s;

        debug("got [%s] to eval", script);
	SUBPERL(interp);
	SAVETMPS;
	rv_s = eval_pv(script, 1);
	rv_p = SvPV(rv_s, rv_l);
	
	MAINPERL;
	RETVAL = newSVpv(rv_p, rv_l);

	SUBPERL(interp);
	FREETMPS;
	
	MAINPERL;
	SPAGAIN;
    }
OUTPUT:
    RETVAL


void
DESTROY(interp)
    Perl	interp
CODE:
    {
	dSUBPERL;
        int i;

	debug("in DESTROY: ac=%d", interp->argc);
        for(i = 1; i < interp->argc; i++) {
	    debug("DESTROY: freeing av[%d]", i);

            /* Win32 requires frees to be in the correct interpreter,
               and before perl_destruct has been called */
            SUBPERL(interp);
            Safefree(interp->argv[i]);
            MAINPERL;
	}

	Safefree(interp->argv);
        debug("freed argv");

	SUBPERL(interp);
	perl_destruct(interp->i);
	
	MAINPERL;
	debug("done destruct");
	
	SUBPERL(interp);
	perl_free(interp->i);

        MAINPERL;
	Safefree(interp);
    }
