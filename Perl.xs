/*
 * Perl.xs
 *
 * Gurusamy Sarathy <gsar@umich.edu>
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef MULTIPLICITY
#error "Must build Perl with -DMULTIPLICITY"
#endif

extern void boot_DynaLoader(CV* cv);

static void
xs_init(void)
{
    newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, __FILE__);
}

struct Perl_t {
    PerlInterpreter *i;
    char **argv;
};

typedef struct Perl_t *Perl;

#ifndef SAVEGLOBALS

typedef struct perl_global_buffers_t {
    char ptokenbuf[sizeof(PL_tokenbuf)];
    YYSTYPE pnextval[sizeof(PL_nextval)];
    I32 pnexttype[sizeof(PL_nexttype)];
} perl_global_buffers;

static void save_globals(perl_global_buffers *pgb);
static void restore_globals(void *p);

#define dSAVEGLOBALS	\
	perl_global_buffers pgb;				\
	PerlInterpreter *prevperl = PL_curinterp

#define SAVEGLOBALS	save_globals(&pgb)

void
save_globals(perl_global_buffers *pgb)
{
    ENTER;
    /* XXX saving everything is probably excessive */
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

#define FREEGLOBALS	\
    STMT_START {						\
	PL_curinterp = prevperl;				\
	LEAVE;							\
    } STMT_END

#endif	/* !SAVEGLOBALS */

MODULE = Perl		PACKAGE = Perl

PROTOTYPES: DISABLE

Perl
new(pkg,...)
    char *pkg
CODE:
    {
	char **av;
	int ac;
	PerlInterpreter *prevperl = PL_curinterp;
	New(999, RETVAL, 1, struct Perl_t);
	RETVAL->i = perl_alloc();
	PL_curinterp = prevperl;
	if (!RETVAL->i) {
	    Safefree(RETVAL);
	    XSRETURN_NO;
	}

	if (items > 1) {
	    New(999, av, items+1, char*);
	    av[0] = "";
	    ac = 1;
	    while (ac < items) {
		av[ac] = SvPV(ST(ac), PL_na);
		++ac;
	    }
	    av[ac] = Nullch;
	}
	else {
	    ac = 2;
	    New(999, av, ac+1, char*);
	    av[0] = "";
	    av[1] = BIT_BUCKET;
	    av[2] = Nullch;
	}
	RETVAL->argv = av;

	perl_construct(RETVAL->i);
	if (perl_parse(RETVAL->i, xs_init, ac, av, environ)) {
	    Safefree(RETVAL->argv);
	    Safefree(RETVAL);
	    PL_curinterp = prevperl;
	    XSRETURN_NO;
	}
	PL_curinterp = prevperl;
	SPAGAIN;
    }
OUTPUT:
    RETVAL


int
run(interp)
    Perl	interp
CODE:
    {
	dSAVEGLOBALS;
	SAVEGLOBALS;
	PL_curinterp = interp->i;
	RETVAL = perl_run(interp->i);
	FREEGLOBALS;
	SPAGAIN;
    }
OUTPUT:
    RETVAL


bool
eval(interp, script)
    Perl	interp
    char *script
CODE:
    {
	dSAVEGLOBALS;
	RETVAL = 1;
	SAVEGLOBALS;
	PL_curinterp = interp->i;

	SAVETMPS;
	/* XXX need a way for SVs to navigate interpreters
	 * if this is to return values to the caller */
	perl_eval_pv(script, FALSE);
	FREETMPS;
	if (SvTRUE(ERRSV)) {
	    warn ("Perl->eval failed: %s\n", SvPV(ERRSV, na)) ;
	    RETVAL = 0;
	}

	FREEGLOBALS;
	SPAGAIN;
    }
OUTPUT:
    RETVAL


void
DESTROY(interp)
    Perl	interp
CODE:
    {
	dSAVEGLOBALS;
	SAVEGLOBALS;
	/* runs destructors, so context save required */
	perl_destruct(interp->i);
	perl_free(interp->i);
	Safefree(interp->argv);
	Safefree(interp);
	FREEGLOBALS;
    }
