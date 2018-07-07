//
// GAME Language interpreter ,32bit Takeoka ver. by Shozo TAKEOKA (http://www.takeoka.org/~take/ )
// VTL_on_FPGA用に改造 By HI631
//
#include "stdafx.h"
#pragma warning(disable:4996)
#include "windows.h"
#include <stdio.h>
#include <string.h>

#include <stdio.h>
#include <conio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <setjmp.h>


#define u_char unsigned char
#define u_int unsigned int
#define u_short unsigned short
#define xputs(xx) printf("%s",xx)
#define xputc putchar
#define xgetkey getch
#define xgetc getch
#define xgets(buf) scanf_s("%s",buf,256);
#define bcopy(ss,dd,ll) memcpy(dd,ss,ll)


#define Ctrl(x) ((x)& 0x1F)
#define CR      '\r'
#define DEL     0x7F
#define BS      Ctrl('H')
#define CTRLC   Ctrl('C')
#define CTRLZ   Ctrl('Z')
#define CAN		Ctrl('X')
#define CAN2	Ctrl('U')
#define SUSP	Ctrl('Q')
#define UP      Ctrl('E')
#define DOWN	Ctrl('X')
#define RIGHT   Ctrl('D')
#define LEFT    Ctrl('S')
#define KILL    Ctrl('K')
#define DELC    Ctrl('G')


#define MODULO_OP
#define	MAX_STK	200

/*****/
#define iSnum(c) ('0'<=(c) && (c)<='9')
#define iShex(c) (('0'<=(c) && (c)<='9')||('A'<=(c) && (c)<='F')||('a'<=(c) && (c)<='f'))

#define VARA(v) var[(v)-0x20]

#define	TOPP	VARA('=')
#define	BTMP	VARA('&')
#define	RAND	VARA('\'')
#define	MOD	VARA('%')

static char old_buf[256]; /* gets */
char linbf[256];
char *linpc;
int  sp, stack[MAX_STK];

jmp_buf toplvl;
unsigned int lno, traceflg=0;
unsigned int ppoint = 0,texttop;
unsigned int ppbuf[2][2];
/*	Var	*/
int var[256 - 32];
char text_buf[131072];
FILE *fpwrite;

int expr(int c);
int term(int c);
//void do_line(char *lin);
void do_optcmd();

int getNum(int *f)
{
	int c;
	int n = 0;
	*f = 0;
	for (; c = (unsigned char)*linpc;){
		if (!iSnum(c)) break;
		n = n * 10 + (c - '0');
		linpc++;
		*f = 1;
	}
	return n;
}


int getHex(int *f){
	int c;
	int n = 0;
	*f = 0;
	for (; c = (unsigned char)*linpc;){
		if (!iShex(c)) break;
		n = n * 16 + ((c<'A') ? (c - '0') : ((c<'a') ? (c - 'A') : (c - 'a')) + 10);
		linpc++;
		*f = 1;
	}
	return n;
}


void newText1() {
	BTMP = TOPP;
	*((u_char*)BTMP) = 0xFF;
}

void newText() {
	if (*((u_char*)BTMP) != 0xFF){
		xputs("\ntext is locked");
		longjmp(toplvl, 1);
	}
	newText1();
}

void mach_init() {
//	setup_tty(1);
//	signal(SIGTERM, terminate);
//	signal(SIGHUP, terminate);
}
char* skipLine(char *p) {
	for (; *p;)
		p++;
	return p + 1;
}

char* searchLine(int n, int *f) {
	char* p;
	int l;

	for (p = (char*)TOPP; !(*p & 0x80);){
		l = ((u_char)*p << 8) | (u_char)*(p + 1);
		if (n == l){ *f = 1; return p; }
		if (n< l){ *f = 0; return p; }
		p = skipLine(p + 2);
	}
	*f = 0;
	return p;
}

/** listing display routine **/
char * makeLine(char *p) {
	int l;
	static char buf[256];

	l = ((u_char)*p << 8) | (u_char)*(p + 1); p += 2;
	sprintf(buf, "%d", l);
	strcat(buf, p);
	return buf;
}

void crlf() {
	xputs("\n");
}

void zbs(u_char c)
{
	if (c == 0){ xputc('\b'); return; }
	if (c<' ') xputc('\b');
	xputc('\b');
}

void zputs(char *x)
{
	char ss[256], *s;

	for (s = ss;;){
		if (*x == 0){ *s = 0; break; }
		if (*x <' '){ *s++ = '^'; *s++ = *x | 0x40; }
		else	   { *s++ = *x; }
		x++;
	}
	xputs(ss);
}

void zputc(u_char c)
{
	if (c< ' '){ xputc('^'); xputc(c | 0x40); }
	else		{ xputc(c); }
}

#define Kill() \
{\
	eraEol_(b,cx); \
	b[cx]=0; \
	len=strlen(b); \
}

void eraEol_(char *b, int cx)
{
	char *s;
	int c;
	s = b + cx;
	for (c = 0; *s; s++){
		if (*s<' '){ xputc(' '); c++; }
		xputc(' '); c++;
	}
	for (; c; c--) xputc('\b');
}

void del_(char *b, int x) {
	char *p;
	p = b + x;
	for (; *p;){
		*p = *(p + 1);
		p++;
	}
}

void cback_(char *s) {
	for (; *s; s++){
		zbs(*s);
	}
}
void ins_(char *b, int x) {
	char *p, *q;
	int save, a;

	p = b + x;
	if (*p == 0){ *(p + 1) = 0; return; }

	for (; *p; p++)
		;
	save = b[x];
	b[x] = 0;

	q = p + 1;
	a = *p;
	for (;;){
		*q = a;
		p--; q--;
		if ((a = *p) == 0) break;
	}
	*q = save;
}

void linTop(char *s, int x)
{
	int save;
	save = s[x];
	s[x] = 0;
	cback_(s);
	s[x] = save;
}

int skipBlank() {
	int x;
	for (;;){
		if ((x = *linpc) != ' ') return x;
		linpc++;
	}
}

///////////////////////////////////////////////
void dmp(char * p, int n) {
	int i;
	for (i = 0; i<n; i++)
		printf("%2x ", *p++);
}

int skipAlpha() {
	int x;
	for (;;){
		x = *linpc;
		if ((x<'A') || ('z'<x) || ('Z'<x && x<'a')) return x;
		linpc++;
	}
}
void errMsg(char *s) {
	char b[10];
	xputs(s);
	if (lno != 0){
		xputs(" in ");
		sprintf(b, "%d", lno);
		xputs(b);
	}
	crlf();
}


int pop() {
	if (sp<0){
		xputs("Stack UnderFlow\n");
		longjmp(toplvl, 1);
	}
	return stack[sp--];
}

int push(int x)
{
	if (sp >= (MAX_STK - 1)){
		xputs("Stack OverFlow\n");
		longjmp(toplvl, 1);
	}
	return stack[++sp] = x;
}

void topOfLine() {
	unsigned int x; // , c;
more:
	x = *linpc++;
	if (x & 0x80) longjmp(toplvl, 1);
	lno = (x << 8) | (unsigned char)*linpc++;
	if (traceflg==1) printf("[%d]", lno); // Tron
	if (traceflg == 2) longjmp(toplvl, (int)linpc);
	
	if (*linpc != ' '){ /* Comment */
		linpc = skipLine(linpc);	goto more;
	}
}
void do_until(int e, int val)
{
	/*printf("until:val=%02x,e=%d,ev=%d,pc=%x\n",val, e, stack[sp],stack[sp-1]);/**/
	VARA(val) = e;
	if (e>stack[sp]){
		sp -= 2; /*pop pc,value*/
		return;
	}
	/* repeat */
	linpc = (char*)stack[sp - 1]; /*pc*/
	return;
}

void do_do() {
	push((int)linpc);
	push(0);
}

void do_if(int e) {
	if (e == 0){
		linpc = skipLine(linpc);
		topOfLine();
	}
}
int gmrun;
void do_goto(int n)
{
	int f;
	char *p;
	if (n == -1) { gmrun = 0;  longjmp(toplvl, 1); }/* Prog Stop */
	p = searchLine(n, &f);
	linpc = p; gmrun = 1;
	topOfLine();
}

void do_gosub(int n) {
	int f;
	char *p;
	p = searchLine(n, &f);
	push((int)linpc);
	linpc = p;
	topOfLine();
}

void do_prSpc(int e) {
	int i;
	for (i = 0; i<e; i++)
		xputc(' ');
}

void do_prChar(int e) {
	xputc(e);
}

int term(int c) {
	int e, f = 0, vmode;
	/*printf("termC=%02x\n",c); /**/
	switch (c){
	case '$':
		e = getHex(&f);
		if (f == 0){ /* get Char */
			return xgetc();
		}
		/*	printf("hexTerm=%x",e); /**/
		return e;
	case '(': /*EXPR */
		e = expr(*linpc++);
		if (*(linpc - 1) != ')'){
			errMsg("')' mismatch");
			longjmp(toplvl, 1);
		}
		return e;
	case '+': /*ABS */
		e = term(*linpc++);
		return e<0 ? -e : e;
	case '-': /* MINUS */
		return -(term(*linpc++));
	case '#': /* NOT */
		return !(term(*linpc++));
	case '\'': /*RAND */
		return rand() % term(*linpc++);
#ifdef MODULO_FUNC
	case '%': /* MOD not yet*/
		return 0;
#endif /*MODULO_FUNC*/
	case '?': /*input */
	{char *ppp, b[256];
	xgets(b);
	ppp = linpc;
	linpc = b;
	e = expr(*linpc++);
	linpc = ppp;
	return e;
	}
	case '"': /*Char const */
		e = *linpc++;
		if (*linpc++ != '"'){
			errMsg("\" mismatch");
			longjmp(toplvl, 1);
		}
		return e;
	}
	if (iSnum(c)){
		linpc--; e = getNum(&f);
		/*	printf("term=%d",e); /**/
		return e;
	}
	/*printf("valiable=%c\n",c); /**/
	/* vmode= *pc;*/
	vmode = skipAlpha();
	if (vmode == ':' || vmode == '(' || vmode == '['){
		linpc++;
		e = expr(*linpc++);
		if (*(linpc - 1) != ')'){
			errMsg("var ')' mismatch");
			longjmp(toplvl, 1);
		}
		u_int vv_c, vv_s, vv_i;
		switch (vmode){
		case ':': vv_c = (u_int)((u_char*)VARA(c) + e) + texttop; return *((u_char *)vv_c) & 0xff;
		case '(': vv_s = (u_int)((u_short*)VARA(c) + e) + texttop; return *((short *)vv_s) & 0xffff;
		case '[': vv_i = (u_int)((u_int*)VARA(c) + e) + texttop; return *((int *)vv_i);
		}
	}
	return VARA(c);
}

int expr(int c) {
	int o, o1, op2; // op1
	int e;

	e = term(c);

	for (;;){
		o = *linpc++; /*printf("exprC=%02x\n",o); /**/
		switch (o){
		case '\0': linpc--;
		case ' ':
		case ')':
		case ',': return e;
		case '<': o1 = *linpc++;
			switch (o1){
				case '>': op2 = term(*linpc++); e = (e != op2); continue;
				case '=': op2 = term(*linpc++); e = (e <= op2); continue;
				default:  op2 = term(o1); e = (e<op2); continue;
			}
		case '>':
			o1 = *linpc++;
			switch (o1){
			case '=': op2 = term(*linpc++); e = (e >= op2); continue;
			default:  op2 = term(o1); e = (e>op2); continue;
			}
		case '+': op2 = term(*linpc++); e = e + op2; break;
		case '-': op2 = term(*linpc++); e = e - op2; break;
		case '*': op2 = term(*linpc++); e = e*op2; break;
		case '/': op2 = term(*linpc++); MOD = e%op2; e = e / op2; break;
#ifdef MODULO_OP
		case '%': op2 = term(*linpc++); MOD = e%op2; e = e%op2; break;
#endif /*MODULO_OP*/
		case '=': op2 = term(*linpc++); e = (e == op2); break;
		case '&': op2 = term(*linpc++); e = e&op2; break;
		case '|': op2 = term(*linpc++); e = e | op2; break;
		case '^': op2 = term(*linpc++); e = e^op2; break;
		default:
			xputc(o); errMsg(" unknown operator");
			longjmp(toplvl, 1);
		}
	}
}

void do_pr() {
	int x;
	for (;;){
		if ('"' == (x = *linpc++)) break;
		if (x == '\0'){ linpc--; break; }
		xputc(x);
	}
}

int operand() {
	int x, e;
	for (;;){
		x = *linpc++;
		/*printf("operandC=%02x\n",x); /**/
		if (x == '=') break;
		if (!(x & 0xDF)){
			errMsg("\nNo operand expression");
			longjmp(toplvl, 1);
		}
	}
	x = *linpc++;
	e = expr(x);
	/*printf("operandExpr=%d\n",e); /**/
	return e;
}
void do_prNum(int c1)
{
	char buf[256];
	int e, digit;

	if (c1 == '('){
		char form[256];
		linpc++;
		digit = term(c1); /*printf("prDigi=%c\n", *pc);/**/
		e = operand();
		sprintf(form, "%%%dd", digit); /*printf("form=%s",form);/**/
		sprintf(buf, form, e);
		xputs(buf);
		return;
	}

	e = operand();
	switch (c1){
		case '!': sprintf(buf, "%08X", e); break;
		case '?': sprintf(buf, "%04X", e & 0xFFFF); break;
		case '$': sprintf(buf, "%02X", e & 0xFF); break;
		case '=': sprintf(buf, "%d", e); break;
		default: xputs("unknown cmd\n"); longjmp(toplvl, 1);
	}
	xputs(buf);
}
int xkeychk() {
	long n=1;
	//	ioctl(0, FIONREAD, &n);
	return n;
}
void breakCheck() {
	char c;
	//if (xkeychk()){
	if (kbhit()){
		c = xgetkey();
		if (c == 0x1b) longjmp(toplvl, (int)linpc);
		if (c == 0x13) xgetkey(); /*pause*/
	}
}

void mach_fin() {
	xputs("Bye bye.\n");
//	setdown_tty(1);
	exit(0);
}

int do_cmd() {
	int c, c1, c2, e, vmode, off;
	breakCheck();
	c = *linpc++;
	c1 = *linpc;
	/* printf("%02x ",c); /**/
	switch (c){
	case '\0': topOfLine();	return 1;
	case ']': linpc = (char*)pop(); return 0;
	case '"': do_pr(); return 0;
	case '/': crlf(); return 0;
	case '@': if (c1 == '='){ break; }
			  do_do(); return 0;
	case '?': do_prNum(c1); return 0;
	case '\\':	mach_fin(); /**/
	case '*': while (*linpc != 0) linpc++; return 0;
	case '[': do_optcmd(); return 0;
	}

	if (c1 == '='){
		switch (c){
		case '#': e = operand(); do_goto(e); return 0;
		case '!': e = operand(); do_gosub(e); return 0;
		case '$': e = operand(); do_prChar(e); return 0;
		case '.': e = operand(); do_prSpc(e); return 0;
		case ';': e = operand(); do_if(e); return 0;
		case '\'': e = operand(); srand(e); return 0; /*RAND seed */
		case '@': c2 = *(linpc + 1); e = operand(); do_until(e, c2); return 0;
		case '&': e = operand();
			if (e == 0){ newText();	}
			return 0;
		default: break; /* Variable */
		}
	}
	else
		if (c == '!'){
			if (*(linpc) == '!')
				if(traceflg==3){ longjmp(toplvl, (int)linpc); }
				else linpc++;
			if (traceflg == 3) printf("[%d]", lno);
			return 0;
		}
	vmode = skipAlpha();
	/* printf("exp:%02x ",vmode); /**/
	if (vmode == ':' || vmode == '(' || vmode == '['){
		linpc++;
		off = expr(*linpc++);
		if (*(linpc - 1) != ')'){
			errMsg("var ')' mismatch");
			longjmp(toplvl, 1);
		}
		e = operand();
		u_int vv_c, vv_s, vv_i;
		switch (vmode){
		case ':': vv_c = (u_int)((u_char*)VARA(c) + off) + texttop; *((u_char*)vv_c) = e & 0xff; return 0;
		case '(': vv_s = (u_int)((u_short*)VARA(c) + off) + texttop; *((u_short*)vv_s) = e & 0xffff; return 0;
		case '[': vv_i = (u_int)((u_int*)VARA(c) + off) + texttop; *((u_int*)vv_i) = e; return 0;
		}
		return 0;
	}
	e = operand();
	VARA(c) = e;
	/* printf("exp:%02x ",*(pc-1)); /**/
	if (*(linpc - 1) == ','){ /* For */
		c = *linpc++;
		e = expr(c);
		/*printf("operandExpr=%d\n",e); /**/
		push((int)linpc);
		push(e);
	}
	return 0;
}
void exqt() {
	int c;
	for (;;){
		c = skipBlank();
		do_cmd();
	}
}

char * dispLine(char *p, FILE *fp) {
	int l;
	char b[256];
	l = ((u_char)*p << 8) | (u_char)*(p + 1); p += 2;
	sprintf(b, "%d%s\n", l, p);
	if(fp==NULL) xputs(b);
	else fputs(b, fp);
	for (; *p;) p++;
	//for (; *p;){ xputc(*p++);}
	//crlf();
	return p + 1;
}

void dispList(char *p, FILE *fp) {
	for (; !(*p & 0x80);){
		//breakCheck();
		p = dispLine(p,fp);
	}
}
void addLine(int n, char * p, char * newl) {
	int l;
	l = 2 + strlen(newl) + 1;
	bcopy(p, p + l, (((u_char*)BTMP) - (u_char*)p) + 1);
	*p = n >> 8;
	*(p + 1) = n;
	strcpy(p + 2, newl);
	BTMP += l;
	*((u_char*)BTMP) = 0xFF; ////
}

void deleteLine(char *p) {
	int l;
	l = 2 + strlen(p + 2) + 1;
	bcopy(p + l, p, (((u_char*)BTMP) - (u_char*)p) - l + 1);
	BTMP -= l;
	*((u_char*)BTMP) = 0xFF; ////
}

/* line edit routines */
int edit(int n) {
	char *p;
	int f;
	if (n == 0){ dispList((char *)TOPP, NULL); return 0; }

	p = searchLine(n, &f);
	if (*linpc == '/'){ /* list */
		dispList(p,NULL);
	}
	else{ /*edit */
		/*		printf("edit:(%d)%d=%s",f,n,pc); */
		if (*((u_char*)BTMP) != 0xFF){
			xputs("Text is locked\n");
			return 0;
		}
		if (f) deleteLine(p);
		if (*linpc == '\0') return 0; /* delete line */
		addLine(n, p, linpc);
	}
	return 0;
}

void do_line(char *lin){
	int n, x;
	*(lin + strlen(lin) + 1) = (char)0x80; /* EOF on endOfLinebuf*/
	linpc = lin;
	skipBlank();
	n = getNum(&x);
	if (x == 0) {
		exqt(); 
		*lin = '\0';
	}
	else{
		if (*linpc == '\\'){ /* edit the line */
			int f;
			char *p;
			p = searchLine(n, &f);
			if (f == 0) *lin = '\0';  //continue;
			else { p = makeLine(p);	strcpy(lin, p); }
			//goto reenter;
		}
		else {
			edit(n);
			*lin = '\0';
		}
	}
}
char rwbuf[256];
void getfn(){
	int fp;
	skipBlank();
	fp = 0;
	while (!(*linpc == ' ' || *linpc == 0)) rwbuf[fp++] = *linpc++;
	rwbuf[fp] = 0;
	//printf("%s", fnbuf);
}

void set_page(int selpage) {
	ppbuf[ppoint][0] = TOPP; TOPP = ppbuf[selpage][0];
	ppbuf[ppoint][1] = BTMP; BTMP = ppbuf[selpage][1];
	ppoint = selpage;
}

void brkcheck(int lno, int badr) {
	push((int)badr);
	printf("Break.%d\n", lno);
}
void loadprg(int pno){
	FILE *fp;
	char *pcw;
	int spline = 0;
	pcw = linpc;
	if(pno == -1) newText(); else set_page(pno);
	fp = fopen(rwbuf, "r");
	if (fp == NULL){ printf("%sファイルが開けません", linbf);	return; }
	while (fgets(rwbuf, 255, fp) != NULL){
		//printf("%s", rwbuf);
		*(rwbuf + strlen(rwbuf) - 1) = 0;
		if (rwbuf[0] != 0) { do_line(rwbuf); spline = 0;}
		else spline++;
		if (spline > 3) 
			break; // 3行以上の空白有れば打ち切り
	}
	*((u_char*)BTMP) = 0xFF;
	fclose(fp);
	linpc = pcw;
}
void saveprg(){
	FILE *fp;
	char *pcw;
	pcw = linpc;
	fp = fopen(rwbuf, "w");
	if (fp == NULL){ printf("%sファイルが開けません", linbf);	return; }
	dispList((char *)TOPP, fp);
	fclose(fp);
	linpc = pcw;
}
void makerom(){
	FILE *fp;
	int lc,pps, ppe;
	unsigned char *pp;
	//char *pcw;
	//pcw = pc;
	fp = fopen(rwbuf, "w");
	if (fp == NULL){ printf("%sファイルが開けません", linbf);	return; }
	pps = VARA('S'); ppe = VARA('A');
	fprintf(fp, "module rom\n");
	fprintf(fp, "	(\n");
	fprintf(fp, "		input             clk,\n");
	fprintf(fp, "		input[7:0]       addr,\n");
	fprintf(fp, "		output reg[31:0] data_out\n");
	fprintf(fp, "		);\n");
	fprintf(fp, "	always @(posedge clk)\n");
	fprintf(fp, "		begin\n");
	fprintf(fp, "		case (addr)\n");
	for (lc = 0; lc < 0x4000; lc++){
		pp = (unsigned char *)(texttop + pps + lc * 4);
		fprintf(fp,"        8'h%02X: data_out <= 32'h%02X%02X%02X%02X;\n",lc, *pp,*(pp+1),*(pp+2),*(pp+3));
		if (*pp == 0 && *(pp + 1) == 0xff && *(pp + 2) == 0xff && *(pp + 3) == 0xff) break; // HALT
	}
	fprintf(fp, "      endcase\n");
	fprintf(fp, "    end\n");
	fprintf(fp, "endmodule\n");
	fclose(fp);
	//pc = pcw;
}
void makemif(){
	FILE *fp;
	int lc, pps, ppe, ppl;
	unsigned char *pp;
	//char *pcw;
	//pcw = pc;
	fp = fopen(rwbuf, "w");
	if (fp == NULL){ printf("%sファイルが開けません", linbf);	return; }
	pps = VARA('S'); ppe = VARA('A'); ppl = (ppe - pps) / 4;
	fprintf(fp, "WIDTH=32;\n");
	fprintf(fp, "DEPTH=256;\n\n");
	fprintf(fp, "ADDRESS_RADIX=UNS;\n");
	fprintf(fp, "DATA_RADIX=HEX;\n\n");
	fprintf(fp, "CONTENT BEGIN\n");
	for (lc = 0; lc <ppl; lc++){
		pp = (unsigned char *)(texttop + pps + lc * 4);
		fprintf(fp, "	%d    :    %02X%02X%02X%02X;\n", lc, *pp, *(pp + 1), *(pp + 2), *(pp + 3));
		if (*pp == 0 && *(pp + 1) == 0xff && *(pp + 2) == 0xff && *(pp + 3) == 0xff) break; // HALT
	}
	fprintf(fp, "    [%d..255]    :    00000000;\n", lc+1);
	fprintf(fp, "END;\n");
	fclose(fp);
	//pc = pcw;
}
void makehex4(){
	FILE *fp;
	int lc, pps, ppe, ppl;
	unsigned char *pp;
	fp = fopen(rwbuf, "w");
	if (fp == NULL){ printf("%sファイルが開けません", linbf);	return; }
	pps = VARA('S'); ppe = VARA('A'); ppl = (ppe - pps) / 4;
	for (lc = 0; lc < ppl; lc++){
		pp = (unsigned char *)(texttop + pps + lc * 4);
		fprintf(fp, "%02X%02X%02X%02X\n", *pp, *(pp + 1), *(pp + 2), *(pp + 3));
	}
	fclose(fp);
}
void makehex() {
	FILE *fp;
	int lc, pps, ppe, ppl,ppl00;
	unsigned char *pp, ppd;
	fp = fopen(rwbuf, "w");
	if (fp == NULL) { printf("%sファイルが開けません", linbf);	return; }
	pps = VARA('S'); ppe = VARA('A'); ppl = (ppe - pps) ;
	ppl00 = (ppl | 0xff) + 1; // 0x100単位にしておく
	for (lc = 0; lc < ppl00; lc++) {
		pp = (unsigned char *)(texttop + pps + lc); ppd = *pp;
		if (lc>=ppl) ppd = 0;
		fprintf(fp, "%02X\n", ppd );
	}
	fclose(fp);
}
void set_page_init(int selpage){
	TOPP = (int)text_buf + selpage*0x8000; newText1(); ppbuf[selpage][0] = TOPP; ppbuf[selpage][1] = BTMP;
}
void makecoe(){
	FILE *fp;
	int lc, pps, ppe, ppl;
	unsigned char *pp;
	fp = fopen(rwbuf, "w");
	if (fp == NULL){ printf("%sファイルが開けません", linbf);	return; }
	pps = VARA('S'); ppe = VARA('A'); ppl = (ppe - pps) / 4;
	fprintf(fp, "MEMORY_INITIALIZATION_RADIX=16;\n");
	fprintf(fp, "MEMORY_INITIALIZATION_VECTOR=\n");
	for (lc = 0; lc <ppl; lc++){
		pp = (unsigned char *)(texttop + pps + lc * 4);
		fprintf(fp, "%02X%02X%02X%02X,", *pp, *(pp + 1), *(pp + 2), *(pp + 3));
		if ((lc % 4) == 3) fprintf(fp, "\n");
	}
	fprintf(fp, "\n");
	fclose(fp);
}
BOOL SetClipboardText(const char *Str)
{
	int    BufSize;
	char  *Buf;
	HANDLE hMem;
	BufSize = strlen(Str) + 1;                               // 確保するメモリのサイズを計算する
	hMem = GlobalAlloc(GMEM_SHARE | GMEM_MOVEABLE, BufSize); // 移動可能な共有メモリを確保する
	if (!hMem) return FALSE;
	Buf = (char *)GlobalLock(hMem); // 確保したメモリをロックし，アクセス可能にする
	if (Buf)
	{
		strcpy(Buf, Str);   // 文字列を複写する
		GlobalUnlock(hMem); // メモリのロックを解除する
		if (OpenClipboard(NULL))
		{
			EmptyClipboard();                  // クリップボード内の古いデータを解放する
			SetClipboardData(CF_TEXT, hMem); // クリップボードに新しいデータを入力する
			CloseClipboard();
			return TRUE;
		}
	}
	return FALSE;
}
void makeclip(){
	//FILE *fp;
	int lc, pps, ppe, ppl;
	unsigned char *pp;
	char cbuf[100000] = "";
	char lbuf[256];
	pps = VARA('S'); ppe = VARA('A'); ppl = (ppe - pps);
	strcat(cbuf, "HH");
	for (lc = 0; lc <ppl; lc++){
		pp = (unsigned char *)(texttop + pps + lc);
		sprintf(lbuf, "%02X\n", *pp);
		strcat(cbuf,lbuf);
	}
	strcat(cbuf, "G");
	SetClipboardText(cbuf);
}

void do_optcmd(){
	u_short ocmd;
	int wpage;
	if(*linpc >= 'a' && *linpc <= 'z')  *linpc = *linpc - 0x20;
	if(*(linpc+1) >= 'a' && *(linpc+1) <= 'z') *(linpc+1) = *(linpc + 1) - 0x20;
	ocmd = (*linpc << 8) + *(linpc + 1); linpc = linpc + 2;
	switch (ocmd){
	case 'LO': getfn(); loadprg(-1); break;
	case 'L0': wpage = ppoint; getfn(); loadprg(0); set_page(wpage);  break; // [P0に格納
	case 'L1': wpage = ppoint; getfn(); loadprg(1); set_page(wpage);  break; // [P1に格納
	case 'SA': getfn(); saveprg(); break;
	case 'MR': getfn(); makerom(); break;
	case 'MM': getfn(); makemif(); break;
	case 'MH': getfn(); makehex(); break;
	case 'MC': getfn(); makecoe(); break;
	case 'CW': makeclip(); break;
	case 'P0': set_page(0); break;
	case 'P1': set_page(1); break;
	case 'T0': traceflg = 0; break;
	case 'T1': traceflg = 1; break; // TrON
	case 'T2': traceflg = 2; break; // ステップ実行
	case 'T3': traceflg = 3; break; // ブレーク有効
	case '11': strcpy(linbf, "[p0 [p0 [l0 test.gm"); printf("%s\n", linbf);  break;
	case '22': strcpy(linbf, "[p1 [p1 [l1 gm80.gm #=1"); printf("%s\n", linbf);  break;
	case '[[': strcpy(linbf, "[p0 [LO gm80\\test.gm [p1 [LO gm80\\gm80.gm #=1"); printf("%s\n", linbf);  linpc = linbf;  break;
	case '\\\\': strcpy(linbf, "[P0 [LO gm80\\gm80.gm [L0 gm80\\moni.gm [L0 gm80\\bios.gm [L0 gm80\\gm80ovf.gm [P1 [LO gm80\\gm80.gm [L1 gm80\\gm80ovp.gm #=1"); printf("%s\n", linbf);  linpc = linbf;  break;
	case '@@': strcpy(linbf, "[P0 [LO gm80\\moni.gm  [P1 [LO gm80\\gm80.gm #=1"); printf("%s\n", linbf);  linpc = linbf;  break;
	default:xputs("command not.found\n"); break;
	}
}

void main() {
	int rcd,lwk;
	mach_init();
	set_page_init(1); set_page_init(0); texttop = (int)text_buf;
	//VARA('A') = TOPP;

	crlf(); xputs("--- VTL_on_FPGA Interpreter ---\n");
	sp = -1;
	
	for (;;){
		if (*linbf == '\0') { rcd = setjmp(toplvl); lwk = lno;  lno = 0; *linbf = '\0'; }
		//if (rcd==0) strcpy(lin, "[p0 [lo t.gm [p1 [lo gm80.gm #=1");
		if (rcd > 1) brkcheck(lwk,rcd);
		crlf(); xputs("G>>"); 
		//xxgets(linbf);
		gets_s(linbf);
		//crlf();
		do_line(linbf);
	}
}


