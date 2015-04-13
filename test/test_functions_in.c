#define E "asdf"

/* should cause errors */
/* #define */
/* #undef */

E()

#define DEF_NO_PARAM() ("RRR")

#define DEF_FUN_ST(a) (#a E DEF_NO_PARAM() DEF_NO_PARAM)

#define DEF_FUN_ST_2(DEF_NO_PARAM) (DEF_NO_PARAM() DEF_NO_PARAM)

/* arguments take precedence over defines */
#define DEF_FUN_ST_3(E) (E)

DEF_FUN_ST(x)

DEF_NO_PARAM()

DEF_FUN_ST_2(y)

DEF_FUN_ST_3(z)
