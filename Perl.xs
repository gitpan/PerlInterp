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

#ifndef MULTIPLICITY
#error "Must build Perl with -DMULTIPLICITY"
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

#ifndef PERL_GET_CONTEXT

typedef struct perl_global_buffers_t {
    char ptokenbuf[sizeof(PL_tokenbuf)];
    YYSTYPE pnextval[sizeof(PL_nextval)];
    I32 pnexttype[sizeof(PL_nexttype)];
} perl_global_buffers;

static void save_globals(perl_global_buffers *pgb);
static void restore_globals(void *p);

#define dSUBPERL	                         \
	perl_global_buffers pgb;		 \
	bool saved_globals = 0;                  \
	PerlInterpreter *mainperl = PL_curinterp

#define SUBPERL(p)               \
    STMT_START {                 \
	save_globals(&pgb);      \
	saved_globals = 1;       \
	PL_curinterp = (p)->i;   \
    } STMT_END

void
save_globals(perl_global_buffers *pgb)
{
    ENTER;
    /* XXX saving everything is probably excessive */
    /* XXX this needs checking against all perls from 5.005
       until we have PERL_GET_CONTEXT */
    SAVEINT(PL_uid);
    SAVEINT(PL_euid);
    SAVEINT(PL_gid);
    SAVEINT(PL_egid);
    SAVEI16(PL_nomemok);
    SAVEI32(PL_an);
    SAVEI32(PL_cop_seqmax);
    SAVEI16(PL_op_seqmax);
    SAVEI32(PL_evalseq);
    SAVESPTR(PL_origenviron);
    SAVEI32(PL_origalen);
    SAVEINT(PL_maxo);
    PL_maxo = MAXO;
    SAVESPTR(PL_sighandlerp);
    SAVESPTR(PL_runops);
    PL_runops = RUNOPS_DEFAULT;
    SAVEIV(PL_na);
    SAVEI32(PL_lex_state);
    SAVEI32(PL_lex_defer);
    SAVEINT(PL_lex_expect);
    SAVEI32(PL_lex_brackets);
    SAVEI32(PL_lex_formbrack);
    SAVEI32(PL_lex_fakebrack);
    SAVEI32(PL_lex_casemods);
    SAVEI32(PL_lex_dojoin);
    SAVEI32(PL_lex_starts);
    /*if (PL_lex_stuff)
	save_item(PL_lex_stuff);
    if (PL_lex_repl)
	save_item(PL_lex_repl);*/
    SAVESPTR(PL_lex_op);
    SAVESPTR(PL_lex_inpat);
    SAVEI32(PL_lex_inwhat);
    SAVEPPTR(PL_lex_brackstack);
    SAVEPPTR(PL_lex_casestack);
    SAVEI32(PL_nexttoke);
    SAVESPTR(PL_linestr);
    SAVEPPTR(PL_bufptr);
    SAVEPPTR(PL_oldbufptr);
    SAVEPPTR(PL_oldoldbufptr);
    SAVEPPTR(PL_bufend);
    SAVEINT(PL_expect);
    SAVEI32(PL_multi_start);
    SAVEI32(PL_multi_end);
    SAVEI32(PL_multi_open);
    SAVEI32(PL_multi_close);
    SAVEI32(PL_error_count);
    SAVEI32(PL_subline);
    /*if (PL_subname)
	save_item(PL_subname);*/
    SAVEI32(PL_min_intro_pending);
    SAVEI32(PL_max_intro_pending);
    SAVEI32(PL_padix);
    SAVEI32(PL_padix_floor);
    SAVEI32(PL_pad_reset_pending);
    SAVEI32(PL_thisexpr);
    SAVEPPTR(PL_last_uni);
    SAVEPPTR(PL_last_lop);
    SAVEI16(PL_last_lop_op);
    SAVEI16(PL_in_my);
    SAVESPTR(PL_in_my_stash);
    SAVEHINTS();
    SAVEI16(PL_do_undump);
    SAVEI32(PL_debug);
    SAVEIV(PL_amagic_generation);
    Copy(PL_tokenbuf, pgb->ptokenbuf, sizeof(PL_tokenbuf),char);
    Copy(PL_nextval, pgb->pnextval, sizeof(PL_nextval)/sizeof(YYSTYPE),char);
    Copy(PL_nexttype, pgb->pnexttype, sizeof(PL_nexttype)/sizeof(I32), char);
    SAVEDESTRUCTOR(restore_globals, pgb);
}

static void restore_globals(void *p)
{
    perl_global_buffers *pgb = (perl_global_buffers*)p;
    Copy(pgb->ptokenbuf, PL_tokenbuf,sizeof(PL_tokenbuf), char);
    Copy(pgb->pnextval, PL_nextval, sizeof(PL_nextval)/sizeof(YYSTYPE),char);
    Copy(pgb->pnexttype, PL_nexttype, sizeof(PL_nexttype)/sizeof(I32), char);
}

#define MAINPERL                  \
    STMT_START {		  \
	PL_curinterp = mainperl;  \
	if(saved_globals) LEAVE;  \
	saved_globals = 0;        \
    } STMT_END

#else /* PERL_GET_CONTEXT */

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

#endif /* PERL_GET_CONTEXT */

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

	debug("starting DESTROY");
	
	SUBPERL(interp);
	perl_destruct(interp->i);
	
	MAINPERL;
	debug("done destruct");
	
	SUBPERL(interp);
	perl_free(interp->i);
	
	MAINPERL;
	debug("in DESTROY: ac=%d", interp->argc);
        for(i = 1; i < interp->argc; i++) {
	    debug("DESTROY: freeing av[%d]", i);
            Safefree(interp->argv[i]);
	}
	Safefree(interp->argv);
	Safefree(interp);
    }
