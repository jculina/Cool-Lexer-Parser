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
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

 /* the comment depth counter (only for nested comments) */
int comment_depth = 0; 

%}


/*
 * Define names for regular expressions here.
 */
DIGIT		[0-9]
LETTER		[a-zA-Z]
UPPER_LETTER	[A-Z]
LOWER_LETTER	[a-z]

DARROW		"=>"
ASSIGN		"<-"
LE		"<="		

%x	COMMENT
%x	SINGLE_COMMENT
%x	STR
%x	CONTINUE


%%

 /*
  *  Nested comments
  */
 /* 
  *-----------------
  * NESTED COMMENTS 
  *-----------------
  */
<INITIAL>{
	"(*" {
		comment_depth++;
		BEGIN(COMMENT);
	}
	"*)" {
		cool_yylval.error_msg = "Unmatched *)";
		return ERROR;
	}	
}
	
<COMMENT>{
	"(*" {
		comment_depth++;
	}
	"*)" {
		comment_depth--;
		if (comment_depth == 0) {
			BEGIN (INITIAL); 
		}
	}
	[^\n(*]* {  }
	[()*] {  }
	\n { 
		curr_lineno++;
	}
	<<EOF>> {
		BEGIN (INITIAL);
		cool_yylval.error_msg = "EOF in comment"; 
		return ERROR;
	}
}

 /* 
  *----------------
  * SINGLE COMMENTS 
  *----------------
  */
<INITIAL>"--" { 
 	BEGIN (SINGLE_COMMENT); 
}
 
<SINGLE_COMMENT>{
 	.* { }
 	\n {
		curr_lineno++;
		BEGIN (INITIAL);
	}
}


 /*
  *  The multiple-character operators.
  */
{DARROW}	{ return (DARROW); }
{ASSIGN}	{ return (ASSIGN); }
{LE}		{ return (LE); }


 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
 /* 
  *----------
  * KEYWORDS 
  *----------
  */
(?i:class)      { return CLASS;     }
(?i:else)       { return ELSE;      }
(?i:fi)         { return FI;        }
(?i:if)         { return IF;        }
(?i:in)         { return IN;        }
(?i:inherits)   { return INHERITS;  }
(?i:let)        { return LET;       }
(?i:loop)       { return LOOP;      }
(?i:pool)       { return POOL;      }
(?i:then)       { return THEN;      }
(?i:while)      { return WHILE;     }
(?i:case)       { return CASE;      } 
(?i:esac)       { return ESAC;      }
(?i:of)         { return OF;        }
(?i:new)        { return NEW;       }
(?i:isvoid)     { return ISVOID;    }
(?i:not)        { return NOT;       }

 /* KEYWORDS TRUE AND FALSE */
t(?i:rue) {
	cool_yylval.boolean = 1;
	return BOOL_CONST;
}

f(?i:alse) {
	cool_yylval.boolean = 0;
	return BOOL_CONST;
}


 /* 
  *----------
  * INTEGERS 
  *----------
  */
{DIGIT}+ { 
	cool_yylval.symbol = inttable.add_string (yytext); 
	return INT_CONST; 
}


 /* 
  *----------------------------
  * TYPE AND OBJECT IDENTIFIERS 
  *----------------------------
  */
{UPPER_LETTER}({LETTER}|{DIGIT}|_)* { 
	cool_yylval.symbol = idtable.add_string (yytext);
	return TYPEID;
}

{LOWER_LETTER}({LETTER}|{DIGIT}|_)* {
	cool_yylval.symbol = idtable.add_string (yytext);
	return OBJECTID;
}

 /* single character symbols */
[:;{}().+\-*/<,~@=]	{ return *yytext; }


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
 /* 
  *--------
  * STRINGS
  *--------
  */ 
<INITIAL>\" { 
	BEGIN(STR);
	yymore(); 
}

<STR>{
	\0 {
		cool_yylval.error_msg = "String contains null character";
		BEGIN(CONTINUE);
		return ERROR;
	}
	\\\0 {
		cool_yylval.error_msg = "String contains escaped null character";
                string_buf[0] = '\0';
                BEGIN(CONTINUE);
                return (ERROR);
	}
	\n {
		cool_yylval.error_msg = "Unterminated string constant";
		curr_lineno++;
		BEGIN (INITIAL);
		return ERROR;
	}
	<<EOF>> {
		cool_yylval.error_msg = "EOF in string constant";
		BEGIN (INITIAL);
		yyrestart(yyin);
		return ERROR;
	}
	[^\\\"\n\0]* { 
		yymore(); 
	}
	\\[^\n] { 
		yymore(); 
	}
	\\\n {
    		curr_lineno++;
    		yymore();
	}
	\" {
		char* ptr = yytext; 
		ptr++;
		string_buf_ptr = string_buf;
		int strlen = 0;

		while( *ptr != '"' && strlen < MAX_STR_CONST ) {
     			if( *ptr == '\\' ){
         			ptr++;
	                  	if( *ptr == 'b' ) { 
	                  		*string_buf_ptr++ = '\b'; 
                  		}
         			else if( *ptr == 't' ) { 
         				*string_buf_ptr++ = '\t'; 
         			}
         			else if( *ptr == 'f' ) { 
         				*string_buf_ptr++ = '\f'; 
         			}
         			else if( *ptr == 'n' ) { 
         				*string_buf_ptr++ = '\n'; 
         			}
         			else { 
         				*string_buf_ptr++ = *ptr; 
         			}
         			ptr++; 
         			strlen++;
         		} 
         		else { 
         			*string_buf_ptr++ = *ptr++;
         			 strlen++;
         		}
         	}
         		
 		if( strlen >= MAX_STR_CONST ) { 
			cool_yylval.error_msg = "String constant too long"; 
			BEGIN (INITIAL); 
			return ERROR; 
		}
			
		*string_buf_ptr++ = '\0';
		cool_yylval.symbol = stringtable.add_string(string_buf);
		BEGIN (INITIAL);
		return STR_CONST;
	}
}    
	
<CONTINUE>{
	\" { 
		BEGIN(INITIAL); 
	}
	\n {
		curr_lineno++; 
		BEGIN(INITIAL); 
	}
	\\\n { 
		curr_lineno++;
		BEGIN(INITIAL);
	}
	. { }			
}      


 /* 
  *------------
  * WHITE SPACE
  *------------
  */   
\n		{ curr_lineno++; }
[ \f\r\t\v]+	{ }

. {
	cool_yylval.error_msg = yytext;
	return ERROR;
}

%%
 