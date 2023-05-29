#ifndef _PROTO_H
#define _PROTO_H

TYP *forcefit(ENODE **srcnode, TYP *srctp, ENODE **dstnode, TYP *dsttp, bool promote, bool typecast);

// Register.cpp
int IsArgReg(int regno);
bool IsCalleeSave(int regno);
int IsTempReg(int rg);

extern TYP* expression(ENODE** node, Symbol* symi);
extern ENODE* makefqnode(int nt, Float128* f128);
extern Operand* makevmreg(int reg);

// Intexpr.c
extern Int128 GetIntegerExpression(ENODE** p, Symbol* symi, int opt);
extern Float128* GetFloatExpression(ENODE** pnode, Symbol* symi);
Int128 GetConstExpression(ENODE **pnode, Symbol* symi);

void GenMemop(int op, Operand *ap1, Operand *ap2, int ssize);
void GenerateHint(int num);

void SaveRegisterVars(CSet *rmask);
void SaveFPRegisterVars(CSet *fprmask);
void SavePositRegisterVars(CSet *prmask);
void funcbottom(Statement *stmt);
Symbol *makeint2(std::string na);
int64_t round10(int64_t n);
int pwrof2(int64_t);
void ListCompound(Statement *stmt);
std::string TraceName(Symbol *sp);
void MarkRemove(OCODE *ip);
void IRemove();
int roundSize(TYP *tp);
extern char *rtrim(char *);
extern int caselit(scase *casetab, int64_t);
extern int litlist(ENODE *, char*);

// MemoryManagement.cpp
void FreeFunction(Function *fn);

// Outcode.cpp
extern std::streampos genstorage(txtoStream& tfs, int64_t nbytes);
extern void GenerateByte(txtoStream&, int64_t val);
extern void GenerateChar(txtoStream&, int64_t val);
extern void GenerateHalf(txtoStream&, int64_t val);
extern void GenerateWord(txtoStream&, int64_t val);
extern void GenerateInt(txtoStream&, int64_t val);
extern void GenerateLong(txtoStream&, Int128 val);
extern void GenerateFloat(txtoStream&, Float128 *val);
extern void GenerateQuad(txtoStream&, Float128 *);
extern void GenerateReference(txtoStream&, Symbol *sp, int64_t offset);
extern void GenerateLabelReference(txtoStream&, int n, int64_t, char*);
// Outcode.c
extern void gen_strlab(txtoStream& tfs, char* s);
extern void dumplits(txtoStream& tfs);
extern int  stringlit(char* s);
extern int quadlit(Float128* f128);
extern void nl(txtoStream&);
extern void seg(txtoStream&, int sg, int algn);
extern void cseg(txtoStream&);
extern void dseg(txtoStream&);
extern void tseg(txtoStream&);
//extern void put_code(int op, int len,Operand *aps, Operand *apd, Operand *);
extern void put_code(txtoStream&, OCODE*);
extern char* put_label(txtoStream&, int lab, char*, char*, char, int);
extern char* put_label(txtoStream&, int lab, const char*, const char*, char, int);
extern char* gen_label(int lab, char*, char*, char, int);
extern char* put_labels(txtoStream&, char*);
extern char* opstr(int op);

extern char *RegMoniker(int regno);
extern void push_token();
extern void pop_token();
extern char *GetStrConst();

extern void push_typ(TYP *tp);
extern TYP *pop_typ();

extern void opt_const_unchecked(ENODE **node);
extern Operand *MakeString(char *s);
extern Operand *MakeDoubleIndexed(int i, int j, int scale);
extern Operand *makecreg(int);

// Register.c
extern Operand* GetTempReg(int);
extern Operand* GetTempRegister();
extern Operand* GetTempTgtRegister();
extern Operand* GetTempBrRegister();
extern Operand* GetTempFPRegister();
extern Operand* GetTempPositRegister();
extern Operand* GetTempVectorRegister();
extern Operand* GetTempVectorMaskRegister();
extern void ReleaseTempRegister(Operand* ap);
extern void ReleaseTempReg(Operand* ap);
extern int TempInvalidate(int*, int*, int*);
extern void TempRevalidate(int sp, int fsp, int psp, int vsp);
extern int GetTempMemSpace();
extern bool IsArgumentReg(int);
extern int IsArgReg(int);
extern int IsSavedReg(int);
extern int IsFargReg(int);
extern int IsFsavedReg(int);
extern int IsFtmpReg(int);
extern void initRegStack();
extern Operand* GenerateFunctionCall(ENODE* node, int flags);

// Utility
extern int64_t roundWord(int64_t);
extern int64_t roundQuadWord(int64_t);
extern int countLeadingBits(int64_t val);
extern int countLeadingZeros(int64_t val);

// Symbol.cpp
extern Symbol* gsearch2(std::string na, __int16 rettype, TypeArray* typearray, bool exact);

extern Posit64 GetPositExpression(ENODE** pnode, Symbol* symi);
extern void GeneratePosit(txtoStream& tfs, Posit64 val);

extern int64_t initbyte(Symbol* symi, int opt);
extern int64_t initchar(Symbol* symi, int opt);
extern int64_t initshort(Symbol* symi, int64_t i, int opt);
extern int64_t initint(Symbol* symi, int64_t i, int opt);
extern int64_t initlong(Symbol* symi, int opt);
extern int64_t initquad(Symbol* symi, int opt);
extern int64_t initfloat(Symbol* symi, int opt);
extern int64_t inittriple(Symbol* symi, int opt);
extern int64_t initPosit(Symbol* symi, int opt);
extern int64_t InitializePointer(TYP*, int opt, Symbol* symi);

extern std::string MakeConame(std::string nme, std::string suffix);

// Peepgen.c
extern void GenerateStrLabel(char* str);

void fatal(char*);
void fatal(const char*);

List* sortedList(List* head, ENODE* root);
int IdentifyPrecision();

extern void GenerateTriadic(int op, int len, Operand* ap1, Operand* ap2, Operand* ap3);
extern void GenerateTriadicEx(int op, std::string* ext, Operand* ap1, Operand* ap2, Operand* ap3);
void AppendFiles();
char* GetPrivateNamespace();

extern int64_t tmpVarSpace();
extern void tmpFreeAll();
extern void tmpReset();
extern int64_t tmpAlloc(int64_t);
extern void tmpFree(int64_t);
extern void GenerateLabel(int64_t);

#endif
