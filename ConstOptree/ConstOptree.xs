#include <assert.h>
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

static OP *convert_arg(pTHX_ OP *op)
{
    OP *op1 = op;
    if (op1->op_type != OP_RV2SV)
	return op;
    SVOP *op2 = (SVOP *) cUNOPx(op)->op_first;
    if (op2->op_type != OP_GV)
	return op;
    GV *gv = cGVOPx_gv(op2);
    STRLEN len = GvNAMELEN(gv);
    if (len != 1)
	return op;
    const char *name = GvNAME(gv);
    SVOP *newop = NULL;
    if (*name == '\017') /* $^O */
	newop = (SVOP *) newSVOP(OP_CONST, 0, newSVpvs(OSNAME));
    if (*name == '\026') /* $^V */
	newop = (SVOP *) newSVOP(OP_CONST, 0, new_version(PL_patchlevel));
    if (*name == ']')    /* $]  */
	newop = (SVOP *) newSVOP(OP_CONST, 0, vnumify(PL_patchlevel));
    if (newop) {
	newop->op_sibling = op1->op_sibling;
	newop->op_next = (OP *) newop;
	op_free(op);
	return (OP *) newop;
    }
    return op;
}

static OP *my_ck_op(pTHX_ OP *op, Perl_check_t ck_next)
{
    OP **argp = &cUNOPx(op)->op_first;
    while (*argp) {
	*argp = convert_arg(aTHX_ *argp);
	argp = &(*argp)->op_sibling;
    }
    return ck_next(aTHX_ op);
}

#define doOPs() \
    /* binops */ \
    doOP(LT)	/* numeric lt (<)  */ \
    doOP(GT)	/* numeric gt (>)  */ \
    doOP(LE)	/* numeric le (<=) */ \
    doOP(GE)	/* numeric ge (>=) */ \
    doOP(EQ)	/* numeric eq (==) */ \
    doOP(NE)	/* numeric ne (!=) */ \
    doOP(NCMP)	/* numeric comparison (<=>) */ \
    doOP(SLT)	/* string lt */ \
    doOP(SGT)	/* string gt */ \
    doOP(SLE)	/* string le */ \
    doOP(SGE)	/* string ge */ \
    doOP(SEQ)	/* string eq */ \
    doOP(SNE)	/* string ne */ \
    doOP(SCMP)	/* string comparison (cmp) */

/* make op handlers */
#define doOP(NAME) \
    static Perl_check_t orig_ck_ ## NAME; \
    static OP *my_ck_ ## NAME(pTHX_ OP *op) { \
	return my_ck_op(aTHX_ op, orig_ck_ ## NAME); \
    }
doOPs()
#undef doOP

/* install op handlers */
static void boot_ops()
{
#define doOP(NAME) \
    orig_ck_ ## NAME = PL_check[OP_ ## NAME]; \
    PL_check[OP_ ## NAME] = my_ck_ ## NAME;
    doOPs()
#undef doOP
}

MODULE = B::ConstOptree		PACKAGE = B::ConstOptree

BOOT:
    boot_ops();
    /* ex: set ts=8 sts=4 sw=4 noet: */
