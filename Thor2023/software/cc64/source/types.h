#ifndef _TYPES_H
#define _TYPES_H

// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2023 Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// CC64 - 'C' derived language compiler
//  - 64 bit CPU
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
class Operand;
class ENODE;
class Statement;
class BasicBlock;
class Instruction;
class Var;
class CSE;
class CSETable;
class Operand;
class Symbol;
class Function;
class OCODE;
class PeepList;
class Var;
class List;

typedef struct tagCase {
	bool first;
	bool done;
	int label;
	int64_t val;
	Statement* stmt;
} Case;

// 64 bytes
class Object
{
public:
	Object();
	int64_t magic;
	int size;
	//	__gc_skip skip1 {
	__int32 typenum;
	__int32 id;
	__int8 state;			// WHITE, GREY, or BLACK
	__int8 scavangeCount;
	__int8 owningMap;
	__int8 pad1;
	__int32 pad2;
	unsigned int usedInMap;
	//	};
	struct _tagObject* forwardingAddress;
	void (*finalizer)();
	int pad3;
};

class CompilerType
{
public:
	static CompilerType *alloc();
};

class MBlk
{
	static MBlk *first;
public:
	MBlk *next;
	static void ReleaseAll();
	static void *alloc(int sz);
};

struct slit {
    struct slit *next;
		struct slit *tail;
    int             label;
    char            *str;
		bool		isString;
		int8_t pass;
	char			*nmspace;
};

struct nlit {
	struct nlit* next;
	struct nlit* tail;
	int    label;
	int precision;
	Float128 f128;
	double f;
	Posit64 p;
	int typ;
	int8_t pass;
	char* nmspace;
};

struct scase {
	int label;
	int64_t val;
	int8_t pass;
};

struct clit {
  struct clit *next;
  int     label;
	int		num;
	int8_t pass;
  scase   *cases;
	char	*nmspace;
};

class C64PException
{
public:
	int errnum;
	int data;
	C64PException(int e, int d) { errnum = e; data = d; };
};


struct typ;
class Statement;

class TYP;
class TypeArray;

class Value : public CompilerType
{
public:
	Value* MakeNew();
	TYP* typ;
	union {
		int64_t i;
		uint64_t u;
		double f;
		uint16_t wa[8];
		char* s;
	} value;
	// The compiler does not support initialization of complex types in unions.
	Posit64 posit;
	Float128 f128;
	double f1, f2;
	std::string* sp;
	std::string* msp;
	std::string* udnm;			// undecorated name
};

class DerivedMethod
{
public:
  int typeno;
  DerivedMethod *next;
  std::string *name;
};

class MachineReg
{
public:
	int number;
	bool isConst;
	bool assigned;
	bool modified;
	bool sub;
	bool IsArg;
	bool IsColorable;
	bool isGP;
	bool isFP;
	bool isPosit;
	ENODE *offset;
	int val;
	Int128 val128;
public:
	static bool IsCalleeSave(int regno);
	bool IsArgReg();
	bool IsPositReg();
	bool IsFloatReg();
	bool ContainsPositConst();
	static void MarkColorable();
};

class Factory : public CompilerType
{
};

// Class for representing tables. Small footprint.

class TABLE {
public:
	int head, tail;
	int base;
	int owner;
	Symbol* headp, * tailp;
	Symbol* basep;
	Symbol* ownerp;
	static Symbol *match[100];
	static int matchno;
	TABLE();
	static void CopySymbolTable(TABLE *dst, TABLE *src);
	void insert(Symbol* sp);
	Symbol *Find(std::string na,bool opt);
	Symbol* Find(std::string na, bool opt, e_bt bt);
	int Find(std::string na);
	int Find(std::string na,__int16,TypeArray *typearray, bool exact);
	int FindRising(std::string na);
	Symbol** GetParameters();
	TABLE *GetPtr(int n);
	void SetOwner(int n) { owner = n; };
	int GetHead() { return head; };
	void SetHead(int p) { head = p; };
	void SetTail(int p) { tail = p; };
	void Clear() { head = tail = base = 0; headp = nullptr; tailp = nullptr; basep = nullptr; };
	void CopyTo(TABLE *dst) {
		dst->head = head;
		dst->tail = tail;
		dst->base = base;
		dst->headp = headp;
		dst->tailp = tailp;
		dst->basep = basep;
	};
	void AddTo(TABLE* dst);
	void MoveTo(TABLE *dst) {
		CopyTo(dst);
		Clear();
	};
	void SetBase(int b) { base = b; };
};

class PeepList
{
public:
	OCODE *head;
	OCODE *tail;
public:
	void Add(OCODE *cd);
	int Count(OCODE *pos);
	bool HasCall(OCODE *pos);
	static OCODE *FindLabel(int64_t i);
	void InsertBefore(OCODE *an, OCODE *cd);
	void InsertAfter(OCODE *an, OCODE *cd);
	void MarkAllKeep();
	void MarkAllKeep2();
	void RemoveCompilerHints();
	void RemoveCompilerHints2();
	void Remove(OCODE *ip);
	void Remove();
	void Remove2();
	void RemoveLinkUnlink();
	void RemoveGPLoad();
	void RemoveRegsave();
	void RemoveEnterLeave();
	void flush();
	void SetLabelReference();
	void EliminateUnreferencedLabels();
	OCODE* FindTarget(OCODE *ip, int reg, OCODE* eip = nullptr);
	bool UsesOnlyArgRegs() const;

	void Dump(char *msg);
	void Dump(const char* msg) {
		Dump((char*)msg);
	};
	BasicBlock *Blockize();
	int CountSPReferences();
	int CountBPReferences();
	int CountGPReferences();
	void RemoveStackAlloc();
	void RemoveStackCode();
	void RemoveReturnBlock();

	// Optimizations
	void OptInstructions();
	void OptBranchToNext();
	void OptDoubleTargetRemoval();
	void OptConstReg();
	void OptLoopInvariants(OCODE *loophead);
	void OptIf(OCODE* headif);

	// Color Graphing
	void SetAllUncolored();
	void RemoveMoves();

	void loadHex(txtiStream& ifs);
	void storeHex(txtoStream& ofs);
};

// Class holding information about functions or methods. These fields were part
// of the Symbol class at one point, but moved to their own class to conserve
// storage space. Many symbols are not functions.

class Function
{
public:
	unsigned short int number;
	bool valid;
	bool IsPrototype;
	bool IsTask;
	bool IsInterrupt;
	bool DoesContextSave;
	bool IsNocall;							// has no calling conventions
	bool IsPascal;
	bool IsLeaf;
	bool IsFar;
	bool DoesThrow;
	bool doesJAL;
	bool UsesNew;
	bool UsesPredicate;					// deprecated
	bool IsVirtual;
	bool IsInline;
	bool IsUnknown;
	bool UsesTemps;							// uses temporary registers
	bool UsesStackParms;
	bool hasSPReferences;
	bool hasBPReferences;				// frame pointer references
	bool hasGPReferences;				// global pointer references
	bool has_rodata;
	bool has_data;
	bool didRemoveReturnBlock;
	bool retGenerated;
	bool alloced;
	bool hasAutonew;
	bool alstk;									// stack space was allocated with link
	bool hasParameters;
	bool hasDefaultCatch;				// programmer coded a default catch
	bool IsCoroutine;
	bool UsesLoopCounter;
	uint16_t NumRegisterVars;
	__int8 NumParms;						// 256 max parameters
	__int8 NumFixedAutoParms;
	__int8 numa;								// number of stack parameters (autos)
	int64_t stkspace;						// stack space used by function
	int64_t sp_init;						// initial SP for interrupt functions
	int64_t argbot;
	int64_t tempbot;
	int64_t regvarbot;
	TABLE proto;								// Table holding protoype information
	TABLE params;
	Statement* prolog;					// Function prolog
	Statement* epilog;
	Statement* body;
	uint64_t stksize;
	CSETable *csetbl;
	Symbol *sym;								// Associated Symbol data
	Symbol *parms;					    // List of parameters associated with symbol
	Symbol *nextparm;
	DerivedMethod *derivitives;	
	CSet *mask, *rmask;					// Register saved/restored masks
	CSet *fpmask, *fprmask;
	CSet* pmask, * prmask;
	CSet *vmask, *vrmask;
	BasicBlock *RootBlock;
	BasicBlock *LastBlock;
	BasicBlock *ReturnBlock;
	Var *varlist;
	PeepList pl;							// under construction
	OCODE *spAdjust;					// place where sp adjustment takes place
	OCODE *rcode;
	int64_t defCatchLabel;
	int64_t tryCount;
	OCODE* defCatchLabelPatchPoint;
public:
	Function();
	void RemoveDuplicates();
	int64_t GetTempBot() { return (tempbot); };
	int64_t GetTempTop() { return (argbot); };
	void CheckParameterListMatch(Function *s1, Function *s2);
	bool CheckSignatureMatch(Function *a, Function *b) const;
	TypeArray *GetParameterTypes();
	TypeArray *GetProtoTypes();
	void PrintParameterTypes();
	std::string *BuildSignature(int opt = 0);
	Function *FindExactMatch(int mm);
	static Function *FindExactMatch(int mm, std::string name, int rettype, TypeArray *typearray);
	bool HasRegisterParameters();
	bool ProtoTypesMatch(Function *sym);
	bool ProtoTypesMatch(TypeArray *typearray);
	bool ParameterTypesMatch(Function *sym);
	bool ParameterTypesMatch(TypeArray *typearray);
	int BPLAssignReg(Symbol* sp1, int reg, bool* noParmOffset);
	void BuildParameterList(int *num, int*numa, int* ellipos);
	void AddParameters(Symbol *list);
	void AddProto(Symbol *list);
	void AddProto(TypeArray *);
	void AddDerived();
	void DoFuncptrAssign(Function *);

	void CheckForUndefinedLabels();
	void Summary(Statement *);
	Statement *ParseBody();
	void Init();
	int Parse();
	void InsertMethod();

	void SaveGPRegisterVars();
	void SaveFPRegisterVars();
	void SavePositRegisterVars();
	void SaveRegisterVars();
	void SaveRegisterArguments();
	int RestoreGPRegisterVars();
	int RestoreFPRegisterVars();
	int RestorePositRegisterVars();
	void RestoreRegisterVars();
	void RestoreRegisterArguments();
	void SaveTemporaries(int *sp, int *fsp, int* psp);
	void RestoreTemporaries(int sp, int fsp, int psp);

	void UnlinkStack(int64_t amt);

	// Optimization
	void PeepOpt();
	void FlushPeep() { pl.flush(); };

	// Code generation
	Operand *MakeDataLabel(int lab, int ndxreg);
	Operand *MakeCodeLabel(int lab);
	Operand *MakeStringAsNameConst(char *s, e_sg seg);
	Operand *MakeString(char *s);
	Operand *MakeImmediate(int64_t i);
	Operand *MakeIndirect(int i);
	Operand *MakeIndexed(int64_t o, int i);
	Operand *MakeDoubleIndexed(int i, int j, int scale);
	Operand *MakeDirect(ENODE *node);
	Operand *MakeIndexed(ENODE *node, int rg);

	void GenLoad(Operand *ap3, Operand *ap1, int ssize, int size);
	int64_t SizeofReturnBlock();
	void SetupReturnBlock();
	void GenerateReturn(Statement *stmt);
	void GenerateCoroutineData();
	void GenerateCoroutineEntry();
	void GenerateCoroutineExit();
	void Generate();
	void GenerateDefaultCatch();

	void CreateVars();
	void ComputeLiveVars();
	void DumpLiveVars();

	void storeHex(txtoStream& ofs);
private:
	void StackGPRs();
};

// Class representing compiler symbols.

class Symbol {
public:
	static int acnt;
public:
	int number;
	int id;
	int parent;
	Symbol* parentp;
	int next;
	Symbol* nextp;
	std::string *name;
	std::string *shortname;
	std::string *mangledName;
	char nameext[4];
	char *realname;
	char *stkname;
  e_sc storage_class;
	e_sg segment;
	unsigned int IsInline : 1;
	unsigned int pos : 4;			// position of the symbol (param, auto or return type)
	// Function attributes
	Function *fi;
	// Auto's are handled by compound statements
	TABLE lsyms;              // local symbols (goto labels)
	bool IsParameter;
	bool IsRegister;
	bool IsAuto;
	bool isConst;
	bool IsKernel;
	bool IsPrivate;
	bool IsUndefined;					// undefined function
	bool ctor;
	bool dtor;
	ENODE *initexp;
	__int16 reg;
	ENODE* defval;	// default value
	int16_t parmno;	// parameter number
	union {
        int64_t i;
        uint64_t u;
        double f;
        uint16_t wa[8];
        char *s;
    } value;
	ENODE* enode;
	Posit64 p;
	Float128 f128;
	TYP *tp;
  Statement *stmt;
	std::streampos storage_pos;
	std::streampos storage_endpos;

	Function* MakeFunction(int symnum, bool isPascal);
	bool IsTypedef();
	static Symbol *Copy(Symbol *src);
	Symbol *Find(std::string name);
	int FindNextExactMatch(int startpos, TypeArray *);
	Symbol *FindRisingMatch(bool ignore = false);
	Symbol* FindInUnion(std::string nme);
	std::string *GetNameHash();
	std::string *BuildSignature(int opt);
	static Symbol *GetPtr(int n);
	Symbol *GetParentPtr();
	void SetName(std::string nm) {
    name = new std::string(nm);
		if (mangledName == nullptr)
			mangledName = new std::string(nm);
	};
	void SetNext(int nxt) { next = nxt; };
	int GetNext() { return next; };
	Symbol *GetNextPtr();
	int GetIndex();
	void SetType(TYP *t) { 
		if (t == (TYP *)0x500000005) {
			printf("Press key\n");
			getchar();
	}
	else
		tp = t;
} ;
	void SetStorageOffset(TYP *head, int nbytes, int al, int ilc, int ztype);
	int AdjustNbytes(int nbytes, int al, int ztype);
	int64_t Initialize(ENODE* pnode, TYP* tp2, int opt);
	int64_t InitializeArray(ENODE*);
	int64_t InitializeStruct(ENODE*);
	int64_t InitializeUnion(ENODE*);
	int64_t GenerateT(ENODE* node, TYP* tp);
	void storeHex(txtoStream& ofs);
};

// Class representing compiler types.

class TYP {
public:
  int type;
	__int16 typeno;			// number of the type
	unsigned int val_flag : 1;       /* is it a value type */
	unsigned int isArray : 1;
	unsigned int isUnsigned : 1;
	unsigned int isShort : 1;
	unsigned int isVolatile : 1;
	unsigned int isIO : 1;
	unsigned int isResv : 1;
	unsigned int isBits : 1;
	__int16 precision;			// precision of the numeric in bits
	ENODE* bit_width;
	ENODE* bit_offset;
	int8_t		ven;			// vector element number
	int64_t   size;
	int64_t struct_offset;
	int8_t dimen;
	int numele;					// number of elements in array / vector length
	TABLE lst;
	int btp;
	TYP* btpp;

	TYP *GetBtp();
	static TYP *GetPtr(int n);
	int GetIndex();
	int GetHash();
	static int64_t GetSize(int num);
	int64_t GetElementSize();
	static int GetBasicType(int num);
	std::string *sname;
	unsigned int alignment;
	static TYP *Make(int bt, int64_t siz);
	static TYP *Copy(TYP *src);
	bool IsScalar();
	static bool IsScalar(e_sym kw);
	bool IsFloatType() const { 
		if (this == nullptr)
			return (false);
		return (type==bt_quad || type==bt_float || type==bt_double); };
	bool IsPositType() const {
		if (this == nullptr)
			return (false);
		return (type == bt_posit); };
	bool IsFunc() const { if (this == nullptr) return (false); return (type == bt_func || type == bt_ifunc); };
	bool IsVectorType() const { if (this == nullptr) return (false);  return (type == bt_vector); };
	bool IsUnion() const { if (this == nullptr) return (false); return (type == bt_union); };
	bool IsStructType() const { if (this == nullptr) return false; return (type == bt_struct || type == bt_class || type == bt_union); };
	bool IsArrayType() const { return (type == bt_array); };
	bool IsAggregateType() const { if (this == nullptr) return (false);  return (IsStructType() | isArray | IsArrayType()); };
	static bool IsSameType(TYP *a, TYP *b, bool exact);
	static bool IsSameStructType(TYP* a, TYP* b);
	static bool IsSameUnionType(TYP* a, TYP* b);
	void put_ty();

	int Alignment();
	int walignment();
	int roundAlignment();
	int64_t roundSize();

	ENODE *BuildEnodeTree();

	// Initialization
	int64_t GenerateT(ENODE *node);
	int64_t InitializeArray(int64_t sz, Symbol* symi);
	int64_t InitializeStruct(ENODE*, Symbol* symi);
	int64_t InitializeUnion(Symbol* symi, ENODE* node);
	int64_t Initialize(int64_t val, Symbol* symi);
	int64_t Initialize(ENODE* node, TYP *, int opt, Symbol* symi);

	// Serialization
	void storeHex(txtoStream& ofs);

	// GC support
	bool FindPointer();
	bool FindPointerInStruct();
	bool IsSkippable();
};

class TypeArray
{
public:
	int types[40];
	__int16 preg[40];
	int length;
	TypeArray();
	void Add(int tp, __int16 regno);
	void Add(TYP *tp, __int16 regno);
	bool IsEmpty();
	bool IsEqual(TypeArray *);
	bool IsLong(int);
	bool IsShort(int);
	bool IsInt(int);
	bool IsChar(int);
	bool IsByte(int);
	bool IsIntType(int);
	void Clear();
	TypeArray *Alloc();
	void Print(txtoStream *);
	void Print();
	std::string *BuildSignature();
};

class ENODE {
public:
	static int segcount[16];
	static CSet initializedSet;
public:
	int number;										// number of this node for reference
	int order;										// list ordering for initializers
	enum e_node nodetype;
	enum e_node new_nodetype;			// nodetype replaced by optimization

	int etype;
	TYP* etypep;
	int64_t esize;
	TYP* tp;
	Symbol* sym;									// pointer to symbol referenced by node
	bool constflag;								// the node contains a constant value
	unsigned int segment : 4;
	unsigned int predreg : 6;
	bool isVolatile;
	bool isIO;
	bool isUnsigned;
	bool isCheckExpr;
	bool isPascal;
	bool isAutonew;
	bool isNeg;
	bool argref;									// argument reference
	ENODE* vmask;
	ENODE* bit_width;
	ENODE* bit_offset;
	__int8 scale;
	short int rg;
	// The following could be in a value union
	// Under construction: use value class
//	Value val;
	// The value information is represented directly in the class for several
	// classes for convenience in referencing.
	int64_t i;
	double f;
	double f1, f2;
	Int128 i128;
	Float128 f128;
	Posit64 posit;
	std::string* sp;
	std::string* msp;
	std::string* udnm;			// undecorated name
	void* ctor;
	void* dtor;
	ENODE* p[4];
	ENODE* pfl;			// postfix list

	ENODE* Clone();

	void SetType(TYP* t) { 
		if (t == (TYP*)1)
			printf("hello");
		if (this) { tp = t; if (t) etype = t->type; } };
	bool IsPtr() { return (etype == bt_pointer || etype == bt_struct || etype == bt_union || etype == bt_class || nodetype == en_addrof); };
	bool IsFloatType() { return (nodetype == en_addrof || nodetype == en_autofcon) ? false : (etype == bt_double || etype == bt_quad || etype == bt_float); };
	bool IsPositType() {
		return (nodetype == en_addrof || nodetype == en_autopcon) ? false : (etype == bt_posit);
	};
	bool IsVectorType() { return (etype == bt_vector); };
	bool IsAutocon() { return (nodetype == en_autocon || nodetype == en_autofcon || nodetype == en_autopcon || nodetype == en_autovcon || nodetype == en_classcon); };
	bool IsUnsignedType() { return (etype == bt_ubyte || etype == bt_uchar || etype == bt_ushort || etype == bt_ulong || etype == bt_pointer || nodetype==en_addrof || nodetype==en_autofcon || nodetype==en_autocon); };
	// ??? Use of this method is dubious
	bool IsRefType() {
		if (this) {
			// This hack to get exit() to work, which uses an array of function pointers.
			if (nodetype == en_ref) {
				if (tp)
					return (tp->type != bt_void && p[0]->nodetype != en_regvar);
				else
					return (true);
			}
			return (nodetype == en_ref || etype == bt_struct || etype == bt_union || etype == bt_class);
		}
		else return (false);
	};
	bool IsBitfield();
	static bool IsEqualOperand(Operand *a, Operand *b);
	char fsize();
	int64_t GetReferenceSize();
	int GetNaturalSize();

	static bool IsSameType(ENODE *ep1, ENODE *ep2);
	static bool IsEqual(ENODE *a, ENODE *b, bool lit = false);
	bool HasAssignop();
	bool HasCall();

	// Parsing
	void AddToList(ENODE* ele);
	bool AssignTypeToList(TYP *);

	// Optimization
	CSE *OptInsertAutocon(int duse);
	CSE *OptInsertRef(int duse);
	void scanexpr(int duse);
	void repexpr();
	void update();

	// Code generation
	List* ReverseList(ENODE*);
	bool FindLoopVar(int64_t);

	Operand *MakeDataLabel(int lab, int ndxreg);
	Operand *MakeCodeLabel(int lab);
	Operand *MakeStringAsNameConst(char *s, e_sg seg);
	Operand *MakeString(char *s);
	Operand *MakeImmediate(int64_t i);
	Operand *MakeIndirect(int i);
	Operand *MakeIndexed(int64_t o, int i);
	Operand *MakeDoubleIndexed(int i, int j, int scale);
	Operand *MakeDirect(ENODE *node);
	Operand *MakeIndexed(ENODE *node, int rg);

	void GenerateHint(int num);
	void GenMemop(int op, Operand *ap1, Operand *ap2, int ssize, int typ);
	void GenerateLoad(Operand *ap3, Operand *ap1, int ssize, int size);
	void GenStore(Operand *ap1, Operand *ap3, int size);
	static void GenRedor(Operand *ap1, Operand *ap2);
	Operand *GenIndex(bool neg);
	Operand *GenSafeHook(int flags, int size);
	Operand *GenerateShift(int flags, int size, int op);
	Operand *GenMultiply(int flags, int size, int op);
	Operand *GenDivMod(int flags, int size, int op);
	Operand *GenerateUnary(int flags, int size, int op);
	Operand *GenerateBinary(int flags, int size, int op);
	Operand *GenerateAssignShift(int flags, int size, int op);
	Operand *GenerateAssignAdd(int flags, int size, int op);
	Operand *GenerateAssignLogic(int flags, int size, int op);
	Operand *GenLand(int flags, int op, bool safe);
	Operand* GenerateBitfieldDereference(int flags, int size, int opt);
	void GenerateBitfieldInsert(Operand* ap1, Operand* ap2, int offset, int width);
	void GenerateBitfieldInsert(Operand* ap1, Operand* ap2, Operand* offset, Operand* width);
	void GenerateBitfieldInsert(Operand* ap1, Operand* ap2, ENODE* offset, ENODE* width);
	Operand* GenerateBitfieldAssign(int flags, int size);
	Operand* GenerateBitfieldAssignAdd(int flags, int size, int op);
	Operand* GenerateBitfieldAssignLogic(int flags, int size, int op);
	Operand* GenerateScaledIndexing(int flags, int size, int rhs);

	// Serialization
	void store(txtoStream& ofs);
	void load(txtiStream& ifs);
	int load(char* bufptr);
	void storeHex(txtoStream& ofs);
	void loadHex(txtiStream& ifs);

	int PutStructConst(txtoStream& ofs);
	void PutConstant(txtoStream& ofs, unsigned int lowhigh, unsigned int rshift, bool opt = false, int display_opt = 0);
	void PutConstantHex(txtoStream& ofs, unsigned int lowhigh, unsigned int rshift);
	static ENODE *GetConstantHex(std::ifstream& ifs);

	// Utility
	void ResetSegmentCount() { ZeroMemory(&segcount, sizeof(segcount)); };
	void CountSegments();

	// Debugging
	std::string nodetypeStr();
	void Dump(int pn = 0);
	void DumpAggregate();
};

// Class to allow representing a set of expression nodes as a linear list
// rather than as a tree. Useful for initializations.

class List
{
public:
	List() {
		nxt = nullptr;
		node = nullptr;
	};
	List(ENODE *nd) {
		nxt = nullptr;
		node = nd;
	};
	List* nxt;
	ENODE* node;
};

// Under construction
class INODE : public CompilerType
{
public:
	INODE* next;
	INODE* prev;
	INODE* inner;
	INODE* outer;
	int type;
	int64_t size;
	// value
	void* arry;
	int64_t i;
	double f;
	Float128 f128;
	Posit64 posit;
	std::string* str;
};

class ExpressionFactory : public Factory
{
public:
	ENODE* Makenode(int nt, ENODE* v1, ENODE* v2, ENODE* v3, ENODE* v4);
	ENODE* Makenode(int nt, ENODE* v1, ENODE* v2, ENODE* v3);
	ENODE* Makenode(int nt, ENODE* v1, ENODE* v2);
	ENODE* Makefqnode(int nt, Float128 v1);
	ENODE* Makefnode(int nt, double v1);
	ENODE* Makepnode(int nt, Posit64 v1);
	ENODE* Makenode();
	ENODE* MakePositNode(int nt, Posit64 v1);
};

class Expression : public CompilerType
{
private:
	int cnt;				// number of []
	ENODE* pep1;
	int numdimen;
	int64_t sa[10];	// size array - 10 dimensions max
	int64_t totsz;
public:
	bool isMember;
	TYP* head;
	TYP* tail;
	TYP* LHSType;
	int sizeof_flag;
	bool got_pa;
	int parsingAggregate;
private:
	void SetRefType(ENODE** node);
	ENODE* SetIntConstSize(TYP* tptr, int64_t val);
	ENODE *ParseArgumentList(ENODE *hidden, TypeArray *typearray, Symbol* symi);
	TYP* ParseCharConst(ENODE** node, int sz);
	TYP* ParseStringConst(ENODE** node);
	ENODE* ParseStringConstWithSizePrefix(ENODE** node);
	ENODE* ParseInlineStringConst(ENODE** node);
	TYP* ParseRealConst(ENODE** node);
	TYP* ParsePositConst(ENODE** node);
	ENODE* ParseAggregateConst(ENODE** node);
	TYP* ParseFloatMax(ENODE** node);
	ENODE* ParseThis(ENODE** node);
	TYP* ParseAggregate(ENODE** node, Symbol* typi);
	ENODE* ParseTypenum();
	ENODE* ParseNew(bool autonew, Symbol* symi);
	ENODE* ParseDelete(Symbol* symi);
	ENODE* ParseAddressOf(Symbol* symi);
	ENODE* ParseMulf(Symbol* symi);
	ENODE* ParseBytndx(Symbol* symi);
	ENODE* ParseWydndx(Symbol* symi);
	// Unary Expression Parsing
	TYP* ParseMinus(ENODE** node, Symbol* symi);
	ENODE* ParseNot(Symbol* symi);
	ENODE* ParseCom(Symbol* symi);
	TYP* ParseStar(ENODE** node, Symbol* symi);
	ENODE* ParseSizeof(Symbol* symi);

	ENODE* ParseDotOperator(TYP* tp1, ENODE* ep1, Symbol* symi, ENODE* parent);
	ENODE* ParsePointsTo(TYP* tp1, ENODE* ep1);
	ENODE* ParseOpenpa(TYP* tp1, ENODE* ep1, Symbol* symi);
	ENODE* ParseOpenbr(TYP*tp1, ENODE* ep1);
	ENODE* AdjustForBitArray(int pop, TYP* tp1, ENODE* ep1);

	void ApplyVMask(ENODE* node, ENODE* mask);

	TYP* deref(ENODE** node, TYP* tp);

	TYP *ParsePrimaryExpression(ENODE **node, int got_pa, Symbol* symi);
	TYP *ParseCastExpression(ENODE **node, Symbol* symi);
	TYP *ParseMultOps(ENODE **node, Symbol* symi);
	TYP *ParseAddOps(ENODE **node, Symbol* symi);
	TYP *ParseShiftOps(ENODE **node, Symbol* symi);
	TYP *ParseRelationalOps(ENODE **node, Symbol* symi);
	TYP *ParseEqualOps(ENODE **node, Symbol* symi);
	TYP *ParseBitwiseAndOps(ENODE **node, Symbol* symi);
	TYP *ParseBitwiseXorOps(ENODE **node, Symbol* symi);
	TYP *ParseBitwiseOrOps(ENODE **node, Symbol* symi);
	TYP *ParseAndOps(ENODE **node, Symbol* symi);
	TYP *ParseSafeAndOps(ENODE **node, Symbol* symi);
	TYP *ParseOrOps(ENODE **node, Symbol* symi);
	TYP *ParseSafeOrOps(ENODE **node, Symbol* symi);
	TYP *ParseConditionalOps(ENODE **node, Symbol* symi);
	TYP *ParseCommaOp(ENODE **node, Symbol* symi);
	ENODE* MakeNameNode(Symbol* sym);
	ENODE* MakeStaticNameNode(Symbol* sym);
	ENODE* MakeThreadNameNode(Symbol* sp);
	ENODE* MakeGlobalNameNode(Symbol* sp);
	ENODE* MakeExternNameNode(Symbol* sp);
	ENODE* MakeConstNameNode(Symbol* sp);
	ENODE* MakeMemberNameNode(Symbol* sp);
	ENODE* MakeUnknownFunctionNameNode(std::string nm, TYP** tp, TypeArray* typearray, ENODE* args);
	void DerefBit(ENODE** node, TYP* tp, Symbol* sp);
	void DerefByte(ENODE** node, TYP* tp, Symbol* sp);
	void DerefUnsignedByte(ENODE** node, TYP* tp, Symbol* sp);
	void DerefFloat(ENODE** node, TYP* tp, Symbol* sp);
	void DerefDouble(ENODE** node, TYP* tp, Symbol* sp);
	void DerefPosit(ENODE** node, TYP* tp, Symbol* sp);
	void DerefBitfield(ENODE** node, TYP* tp, Symbol* sp);
	ENODE* FindLastMulu(ENODE*, ENODE*);
public:
	Expression();
	TYP* ParseNameRef(ENODE** node, Symbol* symi);
	TYP* ParseUnaryExpression(ENODE** node, int got_pa, Symbol* symi);
	TYP* CondDeref(ENODE** node, TYP* tp);
	ENODE* MakeAutoNameNode(Symbol* sp);
	TYP* nameref(ENODE** node, int nt, Symbol* symi);
	TYP* nameref2(std::string name, ENODE** node, int nt, bool alloc, TypeArray* typearray, TABLE* tbl, Symbol* symi);
	// The following is called from declaration processing, so is made public
	TYP *ParseAssignOps(ENODE **node, Symbol* symi);
	TYP* ParsePostfixExpression(ENODE** node, int got_pa, Symbol* symi);
	TYP *ParseNonCommaExpression(ENODE **node, Symbol* symi);
	TYP* ParseNonAssignExpression(ENODE** node, Symbol* symi);
	//static TYP *ParseBinaryOps(ENODE **node, TYP *(*xfunc)(ENODE **), int nt, int sy);
	TYP *ParseExpression(ENODE **node, Symbol* symi);
	Function* MakeFunction(int symnum, Symbol* sp, bool isPascal);
	Symbol* FindMember(TYP* tp1, char* name);
	Symbol* FindMember(TABLE* tbl, char* name);
};


class Operand : public CompilerType
{
public:
	int num;					// number of the operand
	unsigned int mode;
	unsigned int preg : 12;		// primary virtual register number
	unsigned int sreg : 12;		// secondary virtual register number (indexed addressing modes)
	bool pcolored;
	bool scolored;
	unsigned short int pregs;	// subscripted register number
	unsigned short int sregs;
	unsigned int segment : 4;
	unsigned int defseg : 1;
	bool tempflag;
	bool memref;
	bool argref;							// refers to a function argument
	bool preserveNextReg;
	unsigned int type : 16;
	TYP* typep;
	TYP* tp;
	char FloatSize;
	bool isUnsigned;
	unsigned int lowhigh : 2;
	bool isVolatile;
	bool isPascal;
	unsigned int rshift : 8;
	bool isPtr;
	bool isConst;
	bool isBool;
	bool rhs;
	short int pdeep;		// previous stack depth on allocation
	short int deep;           /* stack depth on allocation */
	short int deep2;
	ENODE *offset;
	ENODE *offset2;
	ENODE* bit_offset;
	ENODE* bit_width;
	int8_t scale;
	Operand *next;			// For extended sizes (long)
	Operand* memop;
	Operand* toRelease;
	int display_opt;
public:
	Operand *Clone();
	static bool IsSameType(Operand *ap1, Operand *ap2);
	static bool IsEqual(Operand *ap1, Operand *ap2);
	char fpsize();

	void GenZeroExtend(int isize, int osize);
	Operand *GenerateSignExtend(int isize, int osize, int flags);
	void MakeLegal(int flags, int size);
	int OptRegConst(int regclass, bool tally=false);

	// Storage
	void PutAddressMode(txtoStream& ofs);
	void store(txtoStream& fp);
	void storeHex(txtoStream& fp);
	static Operand *loadHex(txtiStream& fp);
	void load(txtiStream& fp);
};

// Output code structure

class OCODE : public CompilerType
{
public:
	OCODE *fwd, *back, *comment;
	BasicBlock *bb;
	Instruction *insn;
	Instruction* insn2;
	short opcode;
	short length;
	unsigned int segment : 4;
	unsigned int isVolatile : 1;
	unsigned int isReferenced : 1;	// label is referenced by code
	unsigned int remove : 1;
	unsigned int remove2 : 1;
	unsigned int leader : 1;
	unsigned int str : 1;
	short pregreg;
	short predop;
	int loop_depth;
	Operand *oper1, *oper2, *oper3, *oper4;
	__int16 phiops[100];
public:
	static OCODE *MakeNew();
	static OCODE *Clone(OCODE *p);
	static bool IsEqualOperand(Operand *a, Operand *b) { return (Operand::IsEqual(a, b)); };
	static void Swap(OCODE *ip1, OCODE *ip2);
	void MarkRemove() { 
		remove = true;
	};
	void MarkRemove2() { remove2 = true; };
	void Remove();
	bool HasTargetReg() const;
	bool HasTargetReg(int regno) const;
	int GetTargetReg(int *rg1, int *rg2) const;
	bool HasSourceReg(int) const;
	//Edge *MakeEdge(OCODE *ip1, OCODE *ip2);
	// Optimizations
	bool IsSubiSP();
	void OptCom();
	void OptMul();
	void OptMulu();
	void OptDiv();
	void OptAnd();
	void OptMove();
	void OptRedor();
	void OptAdd();
	void OptSubtract();
	void OptLoad();
	void OptLoadByte();
	void OptLoadChar();
	void OptLoadHalf();
	void OptStoreHalf();
	void OptLoadWord();
	void OptStore();
	void OptSxb();
	void OptBra();
	void OptJAL();
	void OptUctran();
	void OptDoubleTargetRemoval();
	void OptHint();
	void OptLabel();
	void OptIndexScale();
	void OptLdi();
	void OptLea();
	void OptPush();
	void OptBne();
	void OptBeq();
	void OptScc();
	void OptSll();
	void OptSxw();
	void OptSxo() {};
	void OptZxb();
	void OptZxw();
	int TargetDistance(int64_t i);

	static OCODE *loadHex(txtiStream& ifs);
	void store(txtoStream& ofs);
	void storeHex(txtoStream& ofs);
};

class OperandFactory : public Factory
{
public:
	Operand *MakeDataLabel(int labno, int ndxreg);
	Operand *MakeCodeLabel(int lab);
	Operand *MakeStrlab(std::string s, e_sg seg);
	Operand *MakeString(char *s);
	Operand *MakeStringAsNameConst(char *s, e_sg seg);
	Operand *makereg(int r);
	Operand *makecreg(int r);
	Operand *makevreg(int r);
	Operand *makevmreg(int r);
	Operand *makefpreg(int r);
	Operand* makepreg(int r);
	Operand *MakeMask(int mask);
	Operand *MakeImmediate(int64_t i, int display_opt=0);
	Operand* MakeImmediate(Int128 i, int display_opt = 0);
	Operand* MakeMemoryIndirect(int disp, int regno);
	Operand *MakeIndirect(short int regno);
	Operand *MakeIndexedCodeLabel(int lab, int i);
	Operand *MakeIndexed(int64_t offset, int regno);
	Operand *MakeIndexed(ENODE *node, int regno);
	Operand *MakeNegIndexed(ENODE *node, int regno);
	Operand *MakeDoubleIndexed(int regi, int regj, int scale);
	Operand *MakeDirect(ENODE *node);
	Operand* MakeIndexedName(std::string nme, int i);
};

class FunctionFactory : public Factory
{
public:
	Function* MakeFunction(int symnum, Symbol* sp, bool isPascal);
};

class CodeGenerator
{
public:
	bool IsPascal(ENODE* ep);
	Operand *MakeDataLabel(int lab, int ndxreg);
	Operand *MakeCodeLabel(int lab);
	Operand *MakeStringAsNameConst(char *s, e_sg seg);
	Operand *MakeString(char *s);
	Operand *MakeImmediate(int64_t i, int display_opt=0);
	Operand* MakeImmediate(Int128 i, int display_opt = 0);
	Operand *MakeIndirect(int i);
	Operand *MakeIndexed(int64_t o, int i);
	Operand* MakeIndexedName(std::string nme, int i);
	Operand *MakeDoubleIndexed(int i, int j, int scale);
	Operand *MakeDirect(ENODE *node);
	Operand *MakeIndexed(ENODE *node, int rg);

	virtual Operand* MakeBoolean(Operand* oper);
	void GenerateHint(int num);
	void GenerateComment(char *cm);
	void GenMemop(int op, Operand *ap1, Operand *ap2, int ssize, int typ);
	void GenerateLoad(Operand *ap3, Operand *ap1, int ssize, int size);
	void GenerateLoadAddress(Operand* ap3, Operand* ap1);
	void GenerateStore(Operand *ap1, Operand *ap3, int size);
	Operand* GenerateHook(ENODE*, int flags, int size);
	virtual Operand* GenerateSafeLand(ENODE *, int flags, int op);
	virtual void GenerateBranchTrue(Operand* ap, int label);
	virtual void GenerateBranchFalse(Operand* ap, int label);
	virtual bool GenerateBranch(ENODE *node, int op, int label, int predreg, unsigned int prediction, bool limit) { return (false); };
	virtual void GenerateLea(Operand* ap1, Operand* ap2);
	virtual void SignExtendBitfield(Operand* ap3, uint64_t mask);
	Operand *GenerateBitfieldAssign(ENODE *node, int flags, int size);
	Operand* GenerateBitfieldAssignAdd(ENODE* node, int flags, int size, int op);
	virtual void GenerateBitfieldInsert(Operand *ap1, Operand *ap2, int offset, int width);
	virtual void GenerateBitfieldInsert(Operand* ap1, Operand* ap2, Operand* offset, Operand* width);
	virtual void GenerateBitfieldInsert(Operand* ap1, Operand* ap2, ENODE* offset, ENODE* width);
	virtual Operand* GenerateBitfieldExtract(Operand* ap1, ENODE* offset, ENODE* width);
	Operand* GenerateAsaddDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su, bool neg);
	Operand* GenerateAddDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su);
	Operand* GenerateAutoconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su);
	Operand* GenerateClassconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su);
	Operand* GenerateAutofconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size);
	Operand* GenerateAutopconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size);
	Operand* GenerateNaconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su);
	Operand* GenerateAutovconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size);
	Operand* GenerateAutovmconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size);
	Operand* GenerateLabconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su);
	Operand *GenerateBitfieldDereference(ENODE *node, int flags, int size, int opt);
	Operand* GenerateBitoffsetDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int opt);
	Operand* GenerateFieldrefDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size);
	Operand* GenerateRegvarDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size);
	Operand* GenerateFPRegvarDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size);
	Operand* GeneratePositRegvarDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size);
	Operand *GenerateDereference(ENODE *node, int flags, int size, int su, int opt, int rhs);
	Operand* GenerateDereference2(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su, int opt);
	Operand* GenerateAssignAdd(ENODE* node, int flags, int size, int op);
	Operand* GenerateAssignMultiply(ENODE *node, int flags, int size, int op);
	Operand *GenerateAssignModiv(ENODE *node, int flags, int size, int op);
	void GenerateStructAssign(TYP *tp, int64_t offset, ENODE *ep, Operand *base);
	void GenerateArrayAssign(TYP *tp, ENODE *node1, ENODE *node2, Operand *base);
	Operand *GenerateAggregateAssign(ENODE *node1, ENODE *node2);
	Operand *GenAutocon(ENODE *node, int flags, int64_t size, TYP* type);
	Operand* GenFloatcon(ENODE* node, int flags, int64_t size);
	Operand* GenPositcon(ENODE* node, int flags, int64_t size);
	Operand* GenLabelcon(ENODE* node, int flags, int64_t size);
	Operand *GenerateAssign(ENODE *node, int flags, int64_t size);
	Operand* GenerateBigAssign(Operand* ap1, Operand* ap2, int size, int ssize);
	Operand* GenerateImmToMemAssign(Operand* ap1, Operand* ap2, int ssize);
	Operand* GenerateRegToMemAssign(Operand* ap1, Operand* ap2, int ssize);
	Operand* GenerateRegToRegAssign(ENODE* node, Operand* ap1, Operand* ap2, int ssize);
	Operand* GenerateImmToRegAssign(Operand* ap1, Operand* ap2, int ssize);
	Operand* GenerateMemToRegAssign(Operand* ap1, Operand* ap2, int size, int ssize);
	Operand *GenerateExpression(ENODE *node, int flags, int64_t size, int rhs);
	void GenerateTrueJump(ENODE *node, int label, unsigned int prediction);
	void GenerateFalseJump(ENODE *node, int label, unsigned int prediction);
	virtual Operand *GenExpr(ENODE *node) { return (nullptr); };
	void GenerateLoadConst(Operand *ap1, Operand *ap2);
	void SaveTemporaries(Function *sym, int *sp, int *fsp, int* psp);
	void RestoreTemporaries(Function *sym, int sp, int fsp, int psp);
	int GenerateInlineArgumentList(Function *func, ENODE *plist);
	virtual int PushArgument(ENODE *ep, int regno, int stkoffs, bool *isFloat) { return(0); };
	virtual int PushArguments(Function *func, ENODE *plist) { return (0); };
	virtual void PopArguments(Function *func, int howMany, bool isPascal = true) {};
	virtual void GenerateIndirectJump(ENODE* node, Operand* oper, Function* func, int flags, int lab = 0) {};
	virtual void GenerateDirectJump(ENODE* node, Operand* oper, Function* func, int flags, int lab = 0) {};
	virtual void GenerateInlineCall(ENODE* node, Function* func);
	virtual Operand *GenerateFunctionCall(ENODE *node, int flags, int lab=0);
	virtual int GeneratePrepareFunctionCall(ENODE* node, Function* sym, int* sp, int* fsp, int* psp);
	void GenerateFunction(Function *fn) { fn->Generate(); };
	Operand* GenerateTrinary(ENODE* node, int flags, int size, int op);
	virtual void GenerateUnlink(int64_t amt);
	virtual void RestoreRegisterVars() {};
};

class ThorCodeGenerator : public CodeGenerator
{
public:
	Operand* MakeBoolean(Operand* oper);
	void GenerateLea(Operand* ap1, Operand* ap2);
	void GenerateBranchTrue(Operand* ap, int label);
	void GenerateBranchFalse(Operand* ap, int label);
	bool GenerateBranch(ENODE *node, int op, int label, int predreg, unsigned int prediction, bool limit);
	void GenerateBeq(Operand*, Operand*, int);
	void GenerateBne(Operand*, Operand*, int);
	void GenerateBlt(Operand*, Operand*, int);
	void GenerateBle(Operand*, Operand*, int);
	void GenerateBgt(Operand*, Operand*, int);
	void GenerateBge(Operand*, Operand*, int);
	void GenerateBltu(Operand*, Operand*, int);
	void GenerateBleu(Operand*, Operand*, int);
	void GenerateBgtu(Operand*, Operand*, int);
	void GenerateBgeu(Operand*, Operand*, int);
	void GenerateBand(Operand*, Operand*, int);
	void GenerateBor(Operand*, Operand*, int);
	void GenerateBnand(Operand*, Operand*, int);
	void GenerateBnor(Operand*, Operand*, int);
	Operand* GenerateEq(ENODE* node);
	Operand* GenerateNe(ENODE* node);
	Operand* GenerateLt(ENODE* node);
	Operand* GenerateLe(ENODE* node);
	Operand* GenerateGt(ENODE* node);
	Operand* GenerateGe(ENODE* node);
	Operand* GenerateLtu(ENODE* node);
	Operand* GenerateLeu(ENODE* node);
	Operand* GenerateGtu(ENODE* node);
	Operand* GenerateGeu(ENODE* node);
	Operand* GenerateFeq(ENODE* node);
	Operand* GenerateFne(ENODE* node);
	Operand* GenerateFlt(ENODE* node);
	Operand* GenerateFle(ENODE* node);
	Operand* GenerateFgt(ENODE* node);
	Operand* GenerateFge(ENODE* node);
	Operand *GenExpr(ENODE *node);
	void LinkAutonew(ENODE *node);
	int PushArgument(ENODE *ep, int regno, int stkoffs, bool *isFloat, int* push_count, bool large_argcount=true);
	int PushArguments(Function *func, ENODE *plist);
	void PopArguments(Function *func, int howMany, bool isPascal = true);
	Operand* GenerateSafeLand(ENODE *, int flags, int op);
	void GenerateIndirectJump(ENODE* node, Operand* oper, Function* func, int flags, int lab = 0);
	void GenerateDirectJump(ENODE* node, Operand* oper, Function* func, int flags, int lab = 0);
	void SignExtendBitfield(Operand* ap3, uint64_t mask);
	void GenerateBitfieldInsert(Operand* dst, Operand* src, int offset, int width);
	void GenerateBitfieldInsert(Operand* dst, Operand* src, Operand* offset, Operand* width);
	void GenerateBitfieldInsert(Operand* ap1, Operand* ap2, ENODE* offset, ENODE* width);
	Operand* GenerateBitfieldExtract(Operand* src, Operand* offset, Operand* width);
	Operand* GenerateBitfieldExtract(Operand* ap1, ENODE* offset, ENODE* width);
	void GenerateUnlink(int64_t amt);
};

// Control Flow Graph
// For now everything in this class is static and there are no member variables
// to it.
class CFG
{
public:
	static void Create();
	static void CalcDominatorTree();
	static void CalcDominanceFrontiers();
	static void InsertPhiInsns();
	static OCODE *FindLabel(int64_t i) { return (PeepList::FindLabel(i)); };
	static void Rename();
	static void Search(BasicBlock *);
	static void Subscript(Operand *oper);
	static int WhichPred(BasicBlock *x, int y);
};


/*      output code structure   */
/*
OCODE {
	OCODE *fwd, *back, *comment;
	short opcode;
	short length;
	unsigned int isVolatile : 1;
	unsigned int isReferenced : 1;	// label is referenced by code
	unsigned int remove : 1;
	short pregreg;
	short predop;
	Operand *oper1, *oper2, *oper3, *oper4;
};
typedef OCODE OCODE;
*/

class IntStack
{
public:
	int *stk;
	int sp;
	int size;
public:
	static IntStack *MakeNew(int sz) {
		IntStack *s;
		s = (IntStack *)allocx(sizeof(IntStack));
		s->stk = (int *)allocx(sz * sizeof(int));
		s->sp = sz;
		s->size = sz;
		return (s);
	}
	static IntStack *MakeNew() {
		return (MakeNew(1000));
	}
	void push(int v) {
		if (sp > 0) {
			sp--;
			stk[sp] = v;
		}
		else
			throw new C64PException(ERR_STACKFULL, 0);
	};
	int pop() {
		int v = 0;
		if (sp < size) {
			v = stk[sp];
			sp++;
			return (v);
		}
		throw new C64PException(ERR_STACKEMPTY, 0);
	};
	int tos() {
		return (stk[sp]);
	};
	bool IsEmpty() { return (sp == size); };
};

class Edge : public CompilerType
{
public:
	bool backedge;
	Edge *next;
	Edge *prev;
	BasicBlock *src;
	BasicBlock *dst;
};

class BasicBlock : public CompilerType
{
public:
	int num;
	Edge *ohead;
	Edge *otail;
	Edge *ihead;
	Edge *itail;
	Edge *dhead;
	Edge *dtail;
public:
	int length;		// number of instructions
	unsigned int changed : 1;
	unsigned int isColored : 1;
	unsigned int isRetBlock : 1;
	int depth;
	CSet *gen;		// use
	CSet *kill;		// def
	CSet *LiveIn;
	CSet *LiveOut;
	CSet *live;
	CSet *MustSpill;
	CSet *NeedLoad;
	CSet *DF;		// dominance frontier
	CSet *trees;
	int HasAlready;
	int Work;
	static CSet *livo;
	BasicBlock *next;
	BasicBlock *prev;
	OCODE *code;
	OCODE *lcode;
	static BasicBlock *RootBlock;
	static int nBasicBlocks;
	CSet *color;
public:
	static bool AllCodeHasBasicBlock(OCODE* start);
	static BasicBlock *MakeNew();
	static BasicBlock *Blockize(OCODE *start);
	Edge *MakeOutputEdge(BasicBlock *dst);
	Edge *MakeInputEdge(BasicBlock *src);
	Edge *MakeDomEdge(BasicBlock *dst);
	static void Unite(int father, int son);
	void ComputeLiveVars();
	void AddLiveOut(BasicBlock *ip);
	bool IsIdom(BasicBlock *b);
	void ExpandReturnBlocks();

	void UpdateLive(int);
	void CheckForDeaths(int r);
	static void ComputeSpillCosts();
	static void InsertMove(int reg, int rreg, int blk);
	void BuildLivesetFromLiveout();
	static void DepthSort();
	static bool Coalesce();
	void InsertSpillCode(int reg, int64_t offs);
	void InsertFillCode(int reg, int64_t offs);
	static void SetAllUncolored();
	void Color();
	static void ColorAll();
};

class Map
{
public:
	int newnums[3072];
};

// A "range" in Briggs terminology
class Range : public CompilerType
{
public:
	int var;
	int num;
	CSet *blocks;
	int degree;
	int lattice;
	bool spill;
	__int16 color;
	int regclass;		// 1 = integer, 2 = floating point, 4 = vector
	// Cost accounting
	float loads;
	float stores;
	float copies;
	float others;
	bool infinite;
	float cost;
	static int treeno;
public:
	Range() { };
	static Range *MakeNew();
	void ClearCosts();
	float SelectRatio() { return (cost / (float)degree); };
};

class Forest
{
public:
	short int treecount;
	Range *trees[1032];
	Function *func;
	CSet low, high;
	IntStack *stk;
	static int k;
	short int map[3072];
	short int pass;
	// Cost accounting
	float loads;
	float stores;
	float copies;
	float others;
	bool infinite;
	float cost;
	Var *var;
public:
	Forest();
	Range *MakeNewTree();
	Range *PlantTree(Range *t);
	void ClearCosts() {
		int r;
		for (r = 0; r < treecount; r++)
			trees[r]->ClearCosts();
	}
	void ClearCut() {
		int r;
		for (r = 0; r < treecount; r++) {
			delete trees[r];
			trees[r] = nullptr;
		}
	};
	void CalcRegclass();
	void SummarizeCost();
	void Renumber();
	void push(int n) { stk->push(n); };
	int pop() { return (stk->pop()); };
	void Simplify();
	void PreColor();
	void Color();
	void Select() { Color(); };
	int SelectSpillCandidate();
	int GetSpillCount();
	int GetRegisterToSpill(int tree);
	bool SpillCode();
	void ColorBlocks();
	bool IsAllTreesColored();
	unsigned int ColorUncolorable(unsigned int);
};


class Var : public CompilerType
{
public:
	Var *next;
	int num;
	int cnum;
	Forest trees;
	CSet *forest;
	CSet *visited;
	IntStack *istk;
	int subscript;
	int64_t spillOffset;	// offset in stack where spilled
	e_rc regclass;
	static int nvar;
public:
	static Var *MakeNew();
	void GrowTree(Range *, BasicBlock *);
	// Create a forest for a specific Var
	void CreateForest();
	// Create a forest for each Var object
	static void CreateForests();
	static void Renumber(int old, int nw);
	static void RenumberNeg();
	static Var *Find(int);
	static Var *Find2(int);
	static Var *FindByCnum(int);
	static Var *FindByMac(int reg);
	static Var *FindByTreeno(int tn);
	static CSet *Find3(int reg, int blocknum);
	static int FindTreeno(int reg, int blocknum);
	static int PathCompress(int reg, int blocknum, int *);
	static void DumpForests(int);
	void Transplant(Var *);
	static bool Coalesce2();
	Var *GetVarToSpill(CSet *exc);
};

class IGraph
{
public:
	int *bitmatrix;
	__int16 *degrees;
	__int16 **vecs;
	int size;
	int K;
	Forest *frst;
	int pass;
	enum e_am workingRegclass;
	enum e_op workingMoveop;
public:
	~IGraph();
	void Destroy();
	void MakeNew(int n);
	void ClearBitmatrix();
	void Clear();
	int BitIndex(int x, int y, int *intndx, int *bitndx);
	void Add(int x, int y);
	void Add2(int x, int y);
	void AddToLive(BasicBlock *b, Operand *ap, OCODE *ip);
	void AddToVec(int x, int y);
	void InsertArgumentMoves();
	bool Remove(int n);
	static int FindTreeno(int reg, int blocknum) { return (Var::FindTreeno(reg, blocknum)); };
	bool DoesInterfere(int x, int y);
	int Degree(int n) { return ((int)degrees[n]); };
	__int16 *GetNeighbours(int n, int *count) { if (count) *count = degrees[n]; return (vecs[n]); };
	void Unite(int father, int son);
	void Fill();
	void AllocVecs();
	void BuildAndCoalesce();
	void Print(int);
};


class Instruction
{
public:
	const char *mnem;		// mnemonic
	short opcode;	// matches OCODE opcode
	short extime;	// execution time, divide may take hundreds of cycles
	unsigned int targetCount : 2;	// number of target operands
	bool memacc;	// instruction accesses memory
	unsigned int amclass1;	// address mode class, one for each possible operand
	unsigned int amclass2;
	unsigned int amclass3;
	unsigned int amclass4;
public:
	static void SetMap();
	static Instruction *GetMapping(int op);
	bool IsFlowControl();
	bool IsLoad();
	bool IsIntegerLoad();
	bool IsStore();
	bool IsExt();
	bool IsSetInsn() {
		return (opcode == op_seq || opcode == op_sne
			|| opcode == op_slt || opcode == op_sle || opcode == op_sgt || opcode == op_sge
			|| opcode == op_sltu || opcode == op_sleu || opcode == op_sgtu || opcode == op_sgeu
			);
	};
	short InvertSet();
	static Instruction *FindByMnem(std::string& mn);
	static Instruction *Get(int op);
	inline bool HasTarget() { return (targetCount != 0); };
	int store(txtoStream& ofs);
	int storeHex(txtoStream& ofs);	// hex intermediate representation
	int storeHRR(txtoStream& ofs);	// human readable representation
	static Instruction *loadHex(std::ifstream& fp);
	int load(std::ifstream& ifs, Instruction **p);
};

class CSE {
public:
	short int nxt;
  ENODE *exp;           /* optimizable expression */
  short int       uses;           /* number of uses */
  short int       duses;          /* number of dereferenced uses */
  short int       reg;            /* AllocateRegisterVarsd register */
  unsigned int    voidf : 1;      /* cannot optimize flag */
  unsigned int    isfp : 1;
	unsigned int	isPosit : 1;
public:
	void AccUses(int val);					// accumulate uses
	void AccDuses(int val);					// accumulate duses
	int OptimizationDesireability();
};

class CSETable
{
public:
	CSE table[500];
	short int csendx;
	short int cseiter;
	short int searchpos;
public:
	CSETable();
	~CSETable();
	CSE *First() { cseiter = 0; return &table[0]; };
	CSE *Next() { cseiter++; return (cseiter < csendx ? &table[cseiter] : nullptr); };
	void Clear() { ZeroMemory(table, sizeof(table)); csendx = 0; };
	void Sort(int (*)(const void *a, const void *b));
	void Assign(CSETable *);
	int voidauto2(ENODE *node);
	CSE *InsertNode(ENODE *node, int duse, bool *first);
	CSE *Search(ENODE *node);
	CSE *SearchNext(ENODE *node);
	CSE *SearchByNumber(ENODE *node);

	void GenerateRegMask(CSE *csp, CSet *mask, CSet *rmask);
	int AllocateGPRegisters();
	int AllocateFPRegisters();
	int AllocatePositRegisters();
	int AllocateVectorRegisters();
	int AllocateRegisterVars();
	void InitializeTempRegs();

	int Optimize(Statement *);

	// Debugging
	void Dump();
};

class Statement {
public:
	int number;
	e_stmt stype;
	Statement *outer;
	Statement *next;
	Statement *prolog;
	Statement *epilog;
	bool nkd;
	int predreg;		// assigned predicate register
	ENODE *exp;         // condition or expression
	ENODE *initExpr;    // initialization expression - for loops
	ENODE *incrExpr;    // increment expression - for loops
	ENODE* iexp;
	Statement *s1, *s2; // internal statements
	int num;			// resulting expression type (hash code for throw)
	int64_t *label;     // label number for goto
	int64_t *casevals;	// case values
	TABLE ssyms;		// local symbols associated with statement
	char *fcname;       // firstcall block var name
	char *lptr;			// pointer to source code
	char *lptr2;			// pointer to source code
	unsigned int prediction : 2;	// static prediction for if statements
	int depth;
	e_sym kw;				// statement's keyword
	static int throwlab;
	static int oldthrow;
	static int olderthrow;
	static bool lc_in_use;
	
	Statement* MakeStatement(int typ, int gt);

	// Parsing
	int64_t* GetCasevals();
	Statement* ParseDefault();
	Statement* ParseCheckStatement();
	Statement *ParseStop();
	Statement *ParseCompound();
	Statement *ParseDo();
	Statement *ParseFor();
	Statement *ParseForever();
	Statement *ParseFirstcall();
	Statement *ParseIf();
	Statement *ParseCatch();
	Statement *ParseCase();
	int CheckForDuplicateCases();
	Statement *ParseThrow();
	Statement *ParseContinue();
	Statement *ParseAsm();
	Statement *ParseTry();
	Statement *ParseExpression();
	Statement *ParseLabel(bool pt=true);
	Statement *ParseWhile();
	Statement *ParseUntil();
	Statement *ParseGoto();
	Statement *ParseReturn();
	Statement *ParseBreak();
	Statement *ParseSwitch();
	Statement* ParseYield();
	Statement *Parse();

	// Optimization
	void scan();
	void scan_compound();
	void repcse();
	void repcse_compound();
	void update();
	void update_compound();

	// Code generation
	Operand *MakeDataLabel(int lab, int ndxreg);
	Operand *MakeCodeLabel(int lab);
	Operand *MakeStringAsNameConst(char *s, e_sg seg);
	Operand *MakeString(char *s);
	Operand *MakeImmediate(int64_t i);
	Operand *MakeIndirect(int i);
	Operand *MakeIndexed(int64_t o, int i);
	Operand* MakeIndexedName(std::string nme, int i);
	Operand *MakeDoubleIndexed(int i, int j, int scale);
	Operand *MakeDirect(ENODE *node);
	Operand *MakeIndexed(ENODE *node, int rg);
	void GenStore(Operand *ap1, Operand *ap3, int size);

	void GenMixedSource();
	void GenMixedSource2();
	void GenerateStop();
	void GenerateAsm();
	void GenerateFirstcall();
	void GenerateWhile();
	void GenerateUntil();
	bool IsDecByOne();
	bool IsNEZeroTest();
	bool IsInitNonZero();
	bool FindLoopVar(int64_t);
	void GenerateCountedLoop();
	void GenerateFor();
	void GenerateForever();
	void GenerateIf();
	void GenerateDoWhile();
	void GenerateDoUntil();
	void GenerateDoLoop();
	void GenerateDoOnce();
	void GenerateCompound();
	void GenerateCase();
	void GenerateDefault();
	int CountSwitchCasevals();
	int CountSwitchCases();
	bool IsTabularSwitch(int64_t numcases, int64_t min, int64_t max, bool nkd);
	bool IsOneHotSwitch();
	void GetMinMaxSwitchValue(int64_t* min, int64_t* max);
	void GenerateSwitchSearch(Case* cases, Operand*, Operand*, int, int, int, int, int, bool, bool);
	void GenerateSwitchLo(Case* cases, Operand*, Operand*, int, int, int, bool, bool, bool last_case);
	void GenerateSwitchLop2(Case* cases, Operand*, Operand*, int, int, int, bool, bool);
	void GenerateNakedTabularSwitch(int64_t, Operand*, int);
	void GenerateTry();
	void GenerateThrow();
	void GenerateCatch(int opt, int oldthrowlab, int olderthrow);
	void GenerateCheck();
	void GenerateFuncBody();
	void GenerateSwitch();
	void GenerateLinearSwitch();
	void GenerateTabularSwitch(int64_t, int64_t, Operand*, bool, int, int);
	void GenerateYield();
	void Generate(int opt = 0);
	void CheckReferences(int* sp, int* bp, int* gp, int* gp1);
	void CheckCompoundReferences(int* sp, int* bp, int* gp, int* gp1);
	// Debugging
	void Dump();
	void DumpCompound();
	void ListCompoundVars();
	// Serialization
	void store(txtoStream& fs);
	void storeIf(txtoStream& ofs);
	void storeWhile(txtoStream& fs);
	void storeCompound(txtoStream& ofs);

	void storeHex(txtoStream& ofs);
	void storeHexIf(txtoStream& ofs);
	void storeHexDo(txtoStream& ofs, e_stmt st);
	void storeHexWhile(txtoStream& fs, e_stmt st);
	void storeHexFor(txtoStream& fs);
	void storeHexForever(txtoStream& fs);
	void storeHexSwitch(txtoStream& fs);
	void storeHexCompound(txtoStream& ofs);
};

class StatementFactory : public Factory
{
public:
	Statement* MakeStatement(int typ, int gt);
};


class Stringx
{
public:
  std::string str;
};

class Declaration
{
private:
	void SetType(Symbol* sp);
	int decl_level; 
	int pa_level;
	Symbol* CreateNonameVar();
	bool isTypedefs[100];
public:
	bool isTypedef;
	bool isFar;
	TYP* head;
	TYP* tail;
	int16_t bit_offset;
	int16_t bit_width;
	int16_t bit_next;
	int16_t bit_max;
	int8_t funcdecl;
	e_sc istorage_class;
	TABLE* itable;
public:
	Declaration();
	Declaration *next;
	void AssignParameterName();
	int declare(Symbol *parent,TABLE *table,e_sc al,int ilc,int ztype, Symbol** symo);
	int declare(Symbol* parent, int ilc, int ztype, Symbol** symo);
	void ParseEnumerationList(TABLE *table, int amt, Symbol *parent, bool power);
	void ParseEnum(TABLE *table);
	void ParseVoid();
	void ParseInterrupt();
	void ParseConst();
	void ParseTypedef();
	void ParseNaked();
	void ParseShort();
	void ParseLong();
	void ParseBool();
	void ParseBit();
	void ParseInt(bool nt = true);
	void ParseInt64();
	void ParseInt32();
	void ParseChar();
	void ParseInt8();
	void ParseByte();
	void ParseFloat();
	void ParseDouble();
	void ParseTriple();
	void ParseFloat128();
	void ParsePosit();
	void ParseClass();
	int ParseStruct(TABLE* table, e_bt typ, Symbol** sym);
	void ParseVector();
	void ParseVectorMask();
	Symbol *ParseId();
	void ParseDoubleColon(Symbol *sp);
	void ParseBitfieldSpec(bool isUnion);
	int ParseSpecifier(TABLE* table, Symbol** sym, e_sc sc);
	Symbol *ParsePrefixId(Symbol*);
	Symbol *ParsePrefixOpenpa(bool isUnion, Symbol*);
	Symbol *ParsePrefix(bool isUnion,Symbol*);
	void ParseSuffixOpenbr();
	Function* ParseSuffixOpenpa(Function *);
	Symbol *ParseSuffix(Symbol *sp);
	static void ParseFunctionAttribute(Function *sym);
	int ParseFunction(TABLE* table, Symbol* sp, e_sc al);
	Function* ParseFunctionJ2(Function* fn);
	void ParseCoroutine();
	void ParseAssign(Symbol *sp);
	void DoDeclarationEnd(Symbol *sp, Symbol *sp1);
	void DoInsert(Symbol *sp, TABLE *table);
	Symbol *FindSymbol(Symbol *sp, TABLE *table);

	int GenerateStorage(int nbytes, int al, int ilc);
	static Function* MakeFunction(int symnum, Symbol* sym, bool isPascal, bool isInline);
	static void MakeFunction(Symbol* sp, Symbol* sp1);
	void FigureStructOffsets(int64_t bgn, Symbol* sp);
};

class StructDeclaration : public Declaration
{
private:
	Symbol* isym;
private:
	int ParseTag(TABLE* table, e_bt ztype, Symbol** sym);
	Symbol* CreateSymbol(char* nmbuf, TABLE* table, e_bt ztype, int* ret);
public:
	StructDeclaration() { Declaration(); };
	void GetType(TYP** hd, TYP** tl) {
		*hd = head; *tl = tail;
	};
	void ParseAttribute(Symbol* sym);
	void ParseAttributes(Symbol* sym);
	void ParseMembers(Symbol* sym, int ztype);
	int Parse(TABLE* table, int ztype, Symbol** sym);
};

class ClassDeclaration : public Declaration
{
public:
	void GetType(TYP** hd, TYP** tl) {
		*hd = head; *tl = tail;
	};
	void ParseMembers(Symbol * sym, int ztype);
	int Parse(int ztype);
};

class AutoDeclaration : public Declaration
{
public:
	ENODE* Parse(Symbol *parent, TABLE *ssyms);
};

class ParameterDeclaration : public Declaration
{
public:
	int number;
	int ellip;	// parameter number of the ellipsis if present
public:
	int Parse(int, bool throw_away);
};

class GlobalDeclaration : public Declaration
{
public:
	void Parse();
	static GlobalDeclaration *Make();
};

class Compiler
{
public:
	int typenum;
	int symnum;
	short int funcnum;
	Symbol symbolTable[32768];
	Symbol* symTables[10];
	Function functionTable[3000];
	TYP typeTable[32768];
	OperandFactory of;
	FunctionFactory ff;
	ExpressionFactory ef;
	StatementFactory sf;
	short int pass;
	bool ipoll;
	bool nogcskips;
	bool os_code;
	int pollCount;
public:
	Compiler() { 
		int i;

		for (i = 0; i < 10; i++)
			symTables[i] = nullptr;
		symTables[0] = &symbolTable[0];
		typenum = 0; ipoll = false; pollCount = 33;
	};
	GlobalDeclaration *decls;
	void compile();
	int PreprocessFile(char *nm);
	void CloseFiles();
	void AddStandardTypes();
	void AddBuiltinFunctions();
	static int GetReturnBlockSize();
	int main2(int c, char **argv);
	void storeHex(txtoStream& ofs);
	void loadHex(txtiStream& ifs);
	void storeTables();
};

class CPU
{
public:
	std::string fileExt;
	int nregs;
	int NumArgRegs;
	int NumTmpRegs;
	int NumSavedRegs;
	int argregs[64];
	int tmpregs[64];
	int saved_regs[64];
	bool SupportsBand;
	bool SupportsBor;
	bool SupportsBBS;
	bool SupportsBBC;
	bool SupportsPush;
	bool SupportsPop;
	bool SupportsLink;
	bool SupportsUnlink;
	bool SupportsBitfield;
	bool SupportsLDM;
	bool SupportsSTM;
	bool SupportsPtrdif;
	bool SupportsEnter;
	bool SupportsLeave;
	bool SupportsIndexed;
	void SetRealRegisters();
	void SetVirtualRegisters();
	bool Addsi;
	int ext_op;
	int extu_op;
	int mov_op;
	int lea_op;
	int ldi_op;
	int ldo_op;
	int ldt_op;
	int ldw_op;
	int ldb_op;
	int ldd_op;
	int ldbu_op;
	int ldwu_op;
	int ldtu_op;
	int sto_op;
	int stt_op;
	int stw_op;
	int stb_op;
	int std_op;
	void InitRegs();
};

//#define SYM     struct sym
//#define TYP     struct typ
//#define TABLE   struct stab

 
#endif
