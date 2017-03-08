/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf, result, max_size) \
    do { \
        if ((result = fread((char*)buf, sizeof(char), max_size, fin)) < 0) \
            YY_FATAL_ERROR("read() in flex scanner failed"); \
    } while (0)

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add your own definitions here
 */

#define RETURN_ERROR(msg) \
    do { \
        cool_yylval.error_msg = (msg); \
        return ERROR; \
    } while (0)

#define EXTEND_STR(c) \
    do { \
        if (string_buf_ptr + 1 > &string_buf[MAX_STR_CONST - 1]) { \
            BEGIN(INVALID_STRING); \
            RETURN_ERROR("String constant too long"); \
        } \
        *string_buf_ptr++ = (c); \
    } while (0)

int comment_level;
%}

    /*
     * Define names for regular expressions here.
     */

    /* tab, newline, vertical tab, formfeed, carriage return, and space */
WS          [\t\n\v\f\r ]

%x COMMENT STRING INVALID_STRING
%%
    /* Operators and other symbols */

"("         return '(';
")"         return ')';
"."         return '.';
"@"         return '@';
"~"         return '~';
"*"         return '*';
"/"         return '/';
"+"         return '+';
"-"         return '-';
"<="        return LE;
"<"         return '<';
"="         return '=';
"<-"        return ASSIGN;
"{"         return '{';
"}"         return '}';
":"         return ':';
","         return ',';
";"         return ';';
"=>"        return DARROW;

     /*
      * Keywords are case-insensitive except for the values true and false,
      * which must begin with a lower-case letter.
      */

[cC][lL][aA][sS][sS]                return CLASS;
[iI][fF]                            return IF;
[tT][hH][eE][nN]                    return THEN;
[eE][lL][sS][eE]                    return ELSE;
[fF][iI]                            return FI;
[iI][nN]                            return IN;
[iI][nN][hH][eE][rR][iI][tT][sS]    return INHERITS;
[iI][sS][vV][oO][iI][dD]            return ISVOID;
[lL][eE][tT]                        return LET;
[lL][oO][oO][pP]                    return LOOP;
[pP][oO][oO][lL]                    return POOL;
[wW][hH][iI][lL][eE]                return WHILE;
[cC][aA][sS][eE]                    return CASE;
[eE][sS][aA][cC]                    return ESAC;
[nN][eE][wW]                        return NEW;
[oO][fF]                            return OF;
[nN][oO][tT]                        return NOT;
t[rR][uU][eE]                       {
                                        cool_yylval.boolean = true;
                                        return BOOL_CONST;
                                    }
f[aA][lL][sS][eE]                   {
                                        cool_yylval.boolean = false;
                                        return BOOL_CONST;
                                    }

    /* Identifiers and integers */

[A-Z][a-zA-Z0-9_]*  {
                        cool_yylval.symbol = idtable.add_string(yytext);
                        return TYPEID;
                    }
[a-z][a-zA-Z0-9_]*  {
                        cool_yylval.symbol = idtable.add_string(yytext);
                        return OBJECTID;
                    }
[0-9]+              {
                        cool_yylval.symbol = inttable.add_string(yytext);
                        return INT_CONST;
                    }

     /*
      *  String constants (C syntax)
      *  Escape sequence \c is accepted for all characters c. Except for
      *  \n \t \b \f, the result is c.
      *
      */

\"                  {
                        string_buf_ptr = string_buf;
                        BEGIN(STRING);
                    }
<STRING>{
    \"              {
                        *string_buf_ptr = '\0';
                        BEGIN(INITIAL);
                        cool_yylval.symbol = stringtable.add_string(string_buf);
                        return STR_CONST;
                    }
    \\?\0           {
                        BEGIN(INVALID_STRING);
                        RETURN_ERROR("String contains null character");
                    }
    \n              {
                        ++curr_lineno;
                        BEGIN(INITIAL);
                        RETURN_ERROR("Unterminated string constant");
                    }
    <<EOF>>         {
                        BEGIN(INITIAL);     /* Prevent EOF loop */
                        RETURN_ERROR("EOF in string constant");
                    }
    \\b             EXTEND_STR('\b');       /* backspace */
    \\f             EXTEND_STR('\f');       /* formfeed */
    \\t             EXTEND_STR('\t');       /* tab */
    \\n             EXTEND_STR('\n');       /* newline */
    \\\n            {                       /* escaped newline */
                        ++curr_lineno;
                        EXTEND_STR('\n');
                    }
    \\.             EXTEND_STR(yytext[1]);
    [^\\\n\0\"]+    {
                        if (string_buf_ptr + yyleng >
                                &string_buf[MAX_STR_CONST - 1]) {
                            BEGIN(INVALID_STRING);
                            RETURN_ERROR("String constant too long");
                        }
                        strcpy(string_buf_ptr, yytext);
                        string_buf_ptr += yyleng;
                    }
}
<INVALID_STRING>{
    \"          BEGIN(INITIAL);
    \n          {
                    ++curr_lineno;
                    BEGIN(INITIAL);
                }
    \\\n        ++curr_lineno;
    \\.         ;
    [^\\\n\"]+  ;
}


    /* Comments */
"--".*                  ;
"*)"                    RETURN_ERROR("Unmatched *)");
<INITIAL,COMMENT>"(*"   {
                            BEGIN(COMMENT);
                            ++comment_level;
                        }
<COMMENT>{
    "*"+")"             {
                            if (--comment_level < 1)
                                BEGIN(INITIAL);
                        }
    <<EOF>>             {
                            BEGIN(INITIAL);         /* Prevent EOF loop */
                            RETURN_ERROR("EOF in comment");
                        }
    \\\n                ++curr_lineno;
    \\.                 ;
    [^(*\\\n]*          ;
    "("+[^(*\\\n]*      ; 
    "*"+[^)*\\\n]*      ;
    \n                  ++curr_lineno;
}
    /* Whitespace and leftovers */
[\t\v\f\r ]+    ;
\n+             curr_lineno += yyleng;
.               RETURN_ERROR(yytext);
%%