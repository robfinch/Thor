// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2023  Robert Finch, Waterloo
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
#include "stdafx.h"
//#define LOCAL_LABELS 1

void put_mask(txtoStream& tfs, int mask);
void align(txtoStream& tfs, int n);
void roseg(txtoStream& tfs);
bool renamed = false; 
int64_t genst_cumulative;
bool first_dataseg = true;

/*      variable initialization         */


//enum e_sg { noseg, codeseg, dataseg, bssseg, idataseg };

int	       gentype = nogen;
int	       curseg = noseg;
int        outcol = 0;
static ENODE *agr;
struct nlit *numeric_tab = nullptr;

// Please keep table in alphabetical order.
// Instruction.cpp has the number of table elements hard-coded in it.
//
Instruction opl[354] =
{   
{ "#", op_remark },
{ "#asm",op_asm,300 },
{ "#empty",op_empty },
{ "#fname", op_fnname },
{ "#string", op_string },
{ "abs", op_abs,2,1,false,am_reg,am_reg,0,0 },
{ "add",op_add,1,1,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "addu", op_addu,1,1 },
{ "and",op_and,1,1,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "andcm",op_andcm,1,1,false,am_reg,am_reg,am_reg,0 },
{ "asl", op_asl,2,1,false,am_reg,am_reg,am_reg|am_ui6,0 },
{ "aslx", op_aslx,2,1,false,am_reg,am_reg,am_reg | am_ui6,0 },
{ "asr",op_asr,2,1,false,am_reg,am_reg,am_reg|am_ui6,0 },
{ "bal", op_bal,4,2,false,am_reg,0,0,0 },
{ "band", op_band,2,0,false,am_reg,am_reg,0,0 },
{ "base", op_base,1,0,false,am_reg,am_reg,am_reg|am_ui6,0 },
{ "bbc", op_bbc,3,0,false,am_reg,am_ui6,0,0 },
{ "bbs", op_bbs,3,0,false,am_reg,am_ui6,0,0 },
{ "bchk", op_bchk,3,0 },
{ "beq", op_beq,3,0,false,am_reg,am_reg,am_direct,0 },
{ "beqi", op_beqi,3,0,false,am_reg,am_imm,am_direct,0 },
{ "beqz", op_beqz,3,0,false,am_reg,am_direct,0,0 },
{ "bex", op_bex,0,0,false,0,0,0,0 },
{ "bf", op_bf,3,0,false,am_reg,am_direct,0,0 },
{ "bfclr", op_bfclr,2,1,false,am_reg,am_reg|am_ui6,am_reg|am_ui6,0 },
{ "bfext", op_bfext,2,1,false,am_reg },
{ "bfextu", op_bfextu,2,1,false,am_reg, },
{ "bfins", op_bfins,2,1,false,am_reg },
{ "bfset", op_bfset,2,1,false,am_reg,am_reg | am_ui6,am_reg | am_ui6,0 },
{ "bge", op_bge,3,0,false,am_reg,am_reg,am_direct,0 },
{ "bgeu", op_bgeu,3,0,false,am_reg,am_reg,am_direct,0 },
{ "bgt", op_bgt,3,0,false,am_reg,am_reg,am_direct,0 },
{ "bgtu", op_bgtu,3,0,false,am_reg,am_reg,am_direct,0 },
{ "bhi",op_bhi,2,0, false, am_reg, am_reg|am_imm, am_direct,0 },
{ "bhs",op_bhs,2,0, false, am_reg, am_reg|am_imm, am_direct,0 },
{ "bit",op_bit,1,1,false,am_creg,am_reg,am_reg | am_imm,0 },
{ "ble", op_ble, 3,0,false,am_reg,am_reg,am_direct,0 },
{ "bleu", op_bleu,3,0,false,am_reg,am_reg,am_direct,0 },
{ "blo",op_blo,2,0,false,am_reg,am_direct,0,0 },
{ "bls",op_bls,2,0,false,am_reg,am_direct,0,0 },
{ "blt", op_blt,3,0,false,am_reg,am_direct,0,0 },
{ "bltu", op_bltu,3,0,false,am_reg,am_direct,0,0 },
{ "bmap", op_bmap,1,0,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "bmi", op_bmi,2,0,false,am_reg,am_direct,0,0 },
{ "bnand", op_bnand,2,0,false,am_reg,am_reg,0,0 },
{ "bne", op_bne,3,0,false,am_reg,am_reg,am_direct,0 },
{ "bnei", op_bnei,3,0,false,am_reg,am_imm,am_direct,0 },
{ "bnez", op_bnez,3,0,false,am_reg,am_direct,0,0 },
{ "bnor", op_bnor,2,0,false,am_reg,am_reg,0,0 },
{ "bor", op_bor,3,0 },
{ "br",op_br,3,0,false,0,0,0,0 },
{ "bra",op_bra,3,0,false,am_direct,0,0,0 },
{ "brk", op_brk,1,0 },
{ "bsr", op_bsr,3,0,false,am_direct,0,0,0 },
{ "bt", op_bt,3,0,false,am_reg,am_direct,0,0 },
{ "bun", op_bun,2,0 },
{ "bytndx", op_bytendx,1,1,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "cache",op_cache,1,0 },
{ "call", op_call,4,1,false,0,0,0,0 },
{ "chk", op_chk,1,0 },
{ "clr",op_clr,1,1,false,am_reg,am_reg,am_reg | am_imm, am_imm },
{ "cmovenz", op_cmovenz,1,1,false,am_reg,am_reg,am_reg,am_reg },
{ "cmp",op_cmp,1,1,false,am_reg,am_reg|am_imm,am_reg|am_imm,0 },
{ "cmpu",op_cmpu,1,1,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "com", op_com,2,1,false,am_reg,am_reg,0,0 },
{ "csrrd", op_csrrd,1,1,false,am_reg,am_reg,am_imm },
{ "csrrw", op_csrrw,1,1,false,am_reg,am_reg,am_imm },
{ "dbra",op_dbra,3,0,false,am_direct,0,0,0 },
{ "dc",op_dc },
{ "dec", op_dec,4,0,true,am_i5 },
{ "defcat", op_defcat,12,1,false,am_reg,am_reg,0 ,0 },
{ "dep",op_dep,1,1,false,am_reg,am_reg,am_reg | am_imm,am_reg | am_imm },
{ "di", op_di,1,1,false,am_reg | am_ui6,0,0,0 },
{ "div", op_div,68,1,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "divu",op_divu,68,1,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "dw", op_dw },
{ "enter",op_enter,10,1,true,am_imm,0,0,0 },
{ "enter_far",op_enter_far,12,1,true,am_imm,0,0,0 },
{ "eor",op_eor,1,1,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "eq",op_eq, 1, 1, false, am_reg, am_reg, am_reg | am_imm,0 },
{ "exi56", op_exi56,1,0,false,am_imm,0,0,0 },
{ "exim", op_exim,1,0,false,am_imm,0,0,0 },
{ "ext", op_ext,1,1,false,am_reg,am_reg,am_reg | am_imm | am_imm0, am_reg | am_imm | am_imm0 },
{ "extr", op_extr,1,1,false,am_reg,am_reg,am_reg | am_imm | am_imm0, am_reg|am_imm | am_imm0 },
{ "extu", op_extu,1,1,false,am_reg,am_reg,am_reg | am_imm | am_imm0, am_reg | am_imm | am_imm0 },
{ "fadd", op_fadd, 6, 1, false, am_reg, am_reg, am_reg, 0 },
{ "fadd.d", op_fdadd,6,1,false,am_reg,am_reg,am_reg,0 },
{ "fadd.s", op_fsadd,6,1,false,am_reg,am_reg,am_reg,0 },
{ "fbeq", op_fbeq,3,0,false,am_reg,am_reg,0,0 },
{ "fbge", op_fbge,3,0,false,am_reg,am_reg,0,0 },
{ "fbgt", op_fbgt,3,0,false,am_reg,am_reg,0,0 },
{ "fble", op_fble,3,0,false,am_reg,am_reg,0,0 },
{ "fblt", op_fblt,3,0,false,am_reg,am_reg,0,0 },
{ "fbne", op_fbne,3,0,false,am_reg,am_reg,0,0 },
{ "fbor", op_fbor,3,0,false,am_reg,am_reg,0,0 },
{ "fbun", op_fbun,3,0,false,am_reg,am_reg,0,0 },
{ "fcmp", op_fcmp, 1,1,false,am_reg,am_reg|am_imm,am_reg|am_imm,0 },
{ "fcvt.q.d", op_fcvtqdd,2,1,false,am_reg,am_reg,0,0 },
{ "fcvtdq", op_fcvtdq,2,1,false,am_reg,am_reg,0,0 },
{ "fcvtsq", op_fcvtsq,2,1,false,am_reg,am_reg,0,0 },
{ "fcvttq", op_fcvttq,2,1,false,am_reg,am_reg,0,0 },
{ "fdiv", op_fdiv, 160, 1, false, am_reg, am_reg|am_imm,am_reg|am_imm, 0 },
{ "fdiv.s", op_fsdiv,80,1,false },
{ "fi2d", op_i2d,2,1,false },
{ "fix2flt", op_fix2flt },
{ "fld", op_fld, 4, 1, true, am_reg, am_mem, 0, 0 },
{ "fload", op_fload, 4, 1, true, am_reg, am_mem, 0, 0 },
{ "flq", op_flq, 4, 1, true, am_reg, am_mem, 0, 0 },
{ "flt2fix",op_flt2fix },
{ "flw", op_flw, 4, 1, true, am_reg, am_mem, 0, 0 },
{ "fmov", op_fmov,1,1 },
{ "fmov.d", op_fdmov,1,1 },
{ "fmul", op_fdmul,10,1,false,am_reg,am_reg,am_reg,0 },
{ "fmul", op_fmul, 10, 1, false, am_reg|am_vreg, am_reg|am_vreg, am_reg|am_vreg, 0 },
{ "fmul.s", op_fsmul,10,1,false },
{ "fneg", op_fneg,2,1,false,am_reg,am_reg,0,0 },
{ "fs2d", op_fs2d,2,1,false,am_reg,am_reg,0,0 },
{ "fseq", op_fseq, 1, 1, false, am_creg, am_reg, am_reg, 0 },
{ "fsle", op_fsle, 1, 1, false, am_creg, am_reg, am_reg, 0 },
{ "fslt", op_fslt, 1, 1, false, am_creg, am_reg, am_reg, 0 },
{ "fsne", op_fsne, 1, 1, false, am_creg, am_reg, am_reg, 0 },
{ "fstore", op_fsto, 4, 0, true, am_reg, am_mem, 0, 0 },
{ "fsub", op_fdsub,6,1,false,am_reg,am_reg,am_reg,0 },
{ "fsub", op_fsub, 6, 1, false, am_reg, am_reg, am_reg, 0 },
{ "fsub.s", op_fssub,6,1,false },
{ "ftadd", op_ftadd },
{ "ftdiv", op_ftdiv },
{ "ftmul", op_ftmul },
{ "ftoi", op_ftoi, 2, 1, false, am_reg, am_reg, 0, 0 },
{ "ftsub", op_ftsub },
{ "gcsub",op_gcsub,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "ge",op_ge, 1, 1, false, am_reg,am_reg, am_reg|am_imm,0 },
{ "geu", op_geu, 1, 1, false, am_reg, am_reg,am_reg | am_imm,0 },
{ "gt",op_gt, 1, 1, false, am_reg, am_reg, am_reg | am_imm,0 },
{ "gtu",op_gtu, 1, 1, false, am_reg, am_reg, am_reg | am_imm,0 },
{ "hint", op_hint,0 },
{ "hint2",op_hint2,0 },
{ "hret", op_hret,1,0,0,0,0,0 },
{ "ibne", op_ibne,3,1 ,false,am_reg,am_reg,0,0 },
{ "inc", op_inc,4,0,true,am_i5,am_mem,0,0 },
{ "iret", op_iret,2,0,false,0,0,0,0 },
{ "isnull", op_isnullptr,1,1,false,am_reg,am_reg,0,0 },
{ "itof", op_itof, 2, 1, false, am_reg, am_reg, 0, 0 },
{ "itop", op_itop, 2, 1, false, am_reg, am_reg, 0, 0 },
{ "jal", op_jal,1,1,false },
{ "jmp",op_jmp,1,0,false,am_mem,0,0,0 },
{ "jsr", op_jsr,1,1,false },
{ "l",op_l,1,1,false,am_reg,am_imm,0,0 },
{ "la",op_la,1,1,false,am_reg,am_mem,0,0 },
{ "lb", op_lb,4,1,true,am_reg,am_mem,0,0 },
{ "lbu", op_lbu,4,1,true,am_reg,am_mem,0,0 },
{ "ld", op_ld,4,1,true,am_reg,am_mem,0,0 },
{ "ldb", op_ldb,4,1,true,am_reg,am_mem,0,0 },
{ "ldbu", op_ldbu,4,1,true,am_reg,am_mem,0,0 },
{ "ldd", op_ldd,4,1,true,am_reg,am_mem,0,0 },
{ "lddr", op_lddr,4,1,true,am_reg,am_mem,0,0 },
{ "ldfd", op_ldfd,4,1,true, am_reg, am_mem,0,0 },
{ "ldft", op_ldft,4,1,true, am_reg, am_mem,0,0 },
{ "ldh", op_ldh,4,1,true,am_reg,am_mem,0,0 },
{ "ldhs", op_ldhs,4,1,true,am_reg,am_mem,0,0 },
{ "ldm", op_ldm,20,1,true,am_mem,0,0,0 },
{ "ldo", op_ldo,4,1,true,am_reg,am_mem,0,0 },
{ "ldos", op_ldos,4,1,true,am_reg,am_mem,0,0 },
{ "ldou", op_ldou,4,1,true,am_reg,am_mem,0,0 },
{ "ldp", op_ldp,4,1,true,am_reg,am_mem,0,0 },
{ "ldpu", op_ldpu,4,1,true,am_reg,am_mem,0,0 },
{ "ldt", op_ldt,4,1,true,am_reg,am_mem,0,0 },
{ "ldtu", op_ldtu,4,1,true,am_reg,am_mem,0,0 },
{ "ldw", op_ldw,4,1,true,am_reg,am_mem,0,0 },
{ "ldwu", op_ldwu,4,1,true,am_reg,am_mem,0,0 },
{ "le",op_le, 1, 1, false, am_reg, am_reg, am_reg | am_imm,0 },
{ "lea",op_lea,1,1,false,am_reg,am_mem,0,0 },
{ "leave",op_leave,10,2,true, 0, 0, 0, 0 },
{ "leave_far",op_leave_far,12,2,true, 0, 0, 0, 0 },
{ "leu",op_leu, 1, 1, false, am_reg, am_reg, am_reg | am_imm,0 },
{ "lh", op_lh,4,1,true,am_reg,am_mem,0,0 },
{ "lhu", op_lhu,4,1,true,am_reg,am_mem,0,0 },
{ "link",op_link,4,1,true,am_imm,0,0,0 },
{ "lm", op_lm },
{ "load", op_load,4,1,true,am_reg,am_mem,0,0 },
{ "loadg", op_loadg,4,1,true,am_reg,am_mem,0,0 },
{ "loadi",op_ldi,1,1,false,am_reg,am_imm,0,0 },
{ "loadv", op_loadv,4,1, true, am_vreg, am_mem,0,0 },
{ "loadz", op_loadz,4,1,true,am_reg,am_mem,0,0 },
{ "loop", op_loop,1,0 },
{ "lslor", op_lslor,2,1,false,am_reg,am_reg,am_reg | am_ui6,am_reg|am_ui6 },
{ "lsr", op_lsr,2,1,false,am_reg,am_reg,am_reg|am_ui6,0 },
{ "lt",op_lt, 1, 1, false, am_reg, am_reg, am_reg | am_imm,0 },
{ "ltu", op_ltu, 1, 1, false, am_reg, am_reg, am_reg | am_imm,0 },
{ "lui",op_lui,1,1,false,am_reg,am_imm,0,0 },
{ "lvbu", op_lvbu,4,1,true ,am_reg,am_mem,0,0 },
{ "lvcu", op_lvcu,4,1,true ,am_reg,am_mem,0,0 },
{ "lvhu", op_lvhu,4,1,true ,am_reg,am_mem,0,0 },
{ "lw", op_lw,4,1,true,am_reg,am_mem,0,0 },
{ "lwu", op_lwu,4,1,true,am_reg,am_mem,0,0 },
{ "lws", op_ldds,4,1,true },
{ "mfbase", op_mfbase,1,0,false,am_reg,am_reg | am_ui6,0,0 },
{ "mffp",op_mffp },
{ "mflk", op_mflk,1,0,false,am_reg,am_reg,0,0 },
{ "mod", op_mod,68,1, false,am_reg,am_reg,am_reg|am_imm,0 },
{ "modu", op_modu,68,1,false,am_reg,am_reg,am_reg,0 },
{ "mov", op_mov,1,1,false,am_reg,am_reg,0,0 },
{ "move",op_move,1,1,false,am_reg,am_reg,0,0 },
{ "movs", op_movs },
{ "mret", op_mret,1,0,0,0,0,0 },
{ "mtbase", op_mtbase,1,0,false,am_reg,am_reg | am_ui6,0,0 },
{ "mtfp", op_mtfp },
{ "mtlc", op_mtlc,1,0,false,am_reg,0,0,0 },
{ "mtlk", op_mtlk,1,0,false,am_reg,am_reg,0,0 },
{ "mul",op_mul,18,1,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "mulf",op_mulf,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "mulu", op_mulu, 10, 1, false, am_reg, am_reg, am_reg | am_imm, 0 },
{ "mv", op_mv,1,1,false,am_reg,am_reg,0,0 },
{ "nand",op_nand,1,1,false,am_reg,am_reg,am_reg,0 },
{ "ne",op_ne,1,1,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "neg",op_neg, 1, 1, false,am_reg,am_reg,0,0 },
{ "nop", op_nop,0,0,false },
{ "nor",op_nor,1,1,false,am_reg,am_reg,am_reg,0 },
{ "not", op_not,2,1,false,am_reg,am_reg,0,0 },
{ "not",op_not,2,1, false,am_reg, am_reg,0,0 },
{ "nr", op_nr },
{ "or",op_or,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "orcm",op_orcm,1,1,false,am_reg,am_reg,am_reg,0 },
{ "orf",op_orf,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "padd", op_padd, 6, 1, false, am_reg, am_reg, am_reg, 0 },
{ "pdiv", op_pdiv, 10, 1, false, am_reg, am_reg, am_reg, 0 },
{ "pea", op_pea },
{ "pea",op_pea },
{ "pfi", op_pfi, 1, 1, false, 0, 0, 0, 0 },
{ "pfx0", op_pfx0, 1, 0, false, am_imm, 0, 0, 0 },
{ "pfx1", op_pfx1, 1, 0, false, am_imm, 0, 0, 0 },
{ "pfx2", op_pfx2, 1, 0, false, am_imm, 0, 0, 0 },
{ "pfx3", op_pfx3, 1, 0, false, am_imm, 0, 0, 0 },
{ "phi", op_phi },
{ "pldo", op_pldo,4,1,true,am_reg,am_mem,0,0 },
{ "pldt", op_pldt,4,1,true,am_reg,am_mem,0,0 },
{ "pldw", op_pldw,4,1,true,am_reg,am_mem,0,0 },
{ "pmul", op_pmul, 8, 1, false, am_reg, am_reg, am_reg, 0 },
{ "pop", op_pop,4,2,true,am_reg,am_reg,0,0 },
{ "popf", op_popf,4,2,true,am_reg,am_reg,0,0 },
{ "psto", op_psto,4,1,true,am_reg,am_mem,0,0 },
{ "pstt", op_pstt,4,1,true,am_reg,am_mem,0,0 },
{ "pstw", op_pstw,4,1,true,am_reg,am_mem,0,0 },
{ "psub", op_psub, 6, 1, false, am_reg, am_reg, am_reg, 0 },
{ "ptrdif",op_ptrdif,1,1,false,am_reg,am_reg,am_reg,am_imm },
{ "push",op_push,4,1,true,am_reg | am_imm,am_reg,0,0 },
{ "pushf",op_pushf,4,0,true,am_reg,0,0,0 },
{ "redor", op_redor,2,1,false,am_reg,am_reg,am_reg,0 },
{ "regs", op_reglist,1,1,false,am_imm,0,0,0 },
{ "rem", op_rem,68,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "remu",op_remu,68,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "ret", op_ret,1,0,am_imm,0,0,0 },
{ "rol", op_rol,2,1,false,am_reg,am_reg,am_reg | am_ui6,0 },
{ "ror", op_ror,2,1,false,am_reg,am_reg,am_reg | am_ui6,0 },
{ "rtd", op_rtd,1,0,false,am_reg,am_reg,am_reg,am_reg|am_imm },
{ "rte", op_rte,2,0 },
{ "rti", op_rti,2,0 },
{ "rtl", op_rtl,1,0,am_imm,0,0,0 },
{ "rts", op_rts,1,0,am_imm,0,0,0 },
{ "rtx", op_rtx,1,0,0,0,0,0 },
{ "sand",op_sand,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "sb",op_sb,4,0,true,am_reg,am_mem,0,0 },
{ "sbx",op_sbx,1,1,false,am_reg,am_reg,am_imm,am_imm },
{ "sd",op_sd,4,0,true,am_reg,am_mem,0,0 },
{ "sei", op_sei,1,0,false,am_reg|am_ui6,0,0,0 },
{ "seq", op_seq,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "setwb", op_setwb, 1, 0 },
{ "sge",op_sge,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "sgeu",op_sgeu,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "sgt",op_sgt,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "sgtu",op_sgtu,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "sh",op_sh,4,0,true,am_reg,am_mem,0,0 },
{ "shl", op_stpl,2,1,false,am_reg,am_reg,am_reg | am_ui6,0 },
{ "shlu", op_stplu,2,1,false,am_reg,am_reg,am_reg | am_ui6,0 },
{ "shr", op_stpr,2,1,false,am_reg,am_reg,am_reg | am_ui6,0 },
{ "shru", op_stpru,2,1,false,am_reg,am_reg,am_reg | am_ui6,0 },
{ "sle",op_sle,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "sleu",op_sleu,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "sll", op_sll,2,1,false,am_reg,am_reg,am_reg,0 },
{ "sllh", op_sllh,2,1,false,am_reg,am_reg,am_reg,0 },
{ "sllp", op_sllp,2,1,false,am_reg,am_reg,am_reg,am_reg|am_ui6 },
{ "slt", op_slt,1,1,false,am_reg,am_reg,am_reg,0 },
{ "sltu", op_sltu,1,1,false,am_reg,am_reg,am_reg,0 },
{ "sm",op_sm },
{ "sne",op_sne,1,1,false,am_reg,am_reg,am_reg | am_i26,0 },
{ "sor",op_sor,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "spt", op_spt,4,0,true ,am_reg,am_mem,0,0 },
{ "sptr", op_sptr,4,0,true,am_reg,am_mem,0,0 },
{ "sra", op_sra,2,1,false,am_reg,am_reg,am_reg | am_ui6,0 },
{ "sret", op_sret,1,0,0,0,0,0 },
{ "srl", op_srl,2,1,false,am_reg,am_reg,am_reg | am_ui6,0 },
{ "stb",op_stb,4,0,true,am_reg,am_mem,0,0 },
{ "std", op_std,4,0,true,am_reg,am_mem,0,0 },
{ "stdcr", op_stdc,4,0,true, am_reg, am_mem,0,0 },
{ "stfd", op_stfd,4,0,true, am_reg, am_mem,0,0 },
{ "stft", op_stft,4,0,true, am_reg, am_mem,0,0 },
{ "sth", op_sth,4,0,true,am_reg,am_mem,0,0 },
{ "sths",op_sths,4,0,true,am_reg,am_mem,0,0 },
{ "sti", op_sti,1,0 },
{ "stm", op_stm,20,1,true,am_mem,0,0,0 },
{ "sto",op_sto,4,0,true,am_reg,am_mem,0,0 },
{ "stop", op_stop },
{ "store",op_store,4,0,true,am_reg,am_mem,0,0 },
{ "storeg",op_storeg,4,0,true,am_reg,am_mem,0,0 },
{ "stos",op_stos,4,0,true,am_reg,am_mem,0,0 },
{ "stp",op_stp,4,0,true,am_reg,am_mem,0,0 },
{ "stt",op_stt,4,0,true,am_reg,am_mem,0,0 },
{ "stw",op_stw,4,0,true,am_reg,am_mem,0,0 },
{ "sub",op_sub,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "subu", op_subu,1,1 },
{ "sv", op_sv,256,0 },
{ "sw",op_sw,4,0,true,am_reg,am_mem,0,0 },
{ "swap",op_stdap,1,1,false },
{ "swp", op_stdp, 8, false },
{ "sws", op_stds,4,0 },
{ "sxb",op_sxb,1,1,false,am_reg,am_reg,0,0 },
{ "sxc",op_sxc,1,1,false,am_reg,am_reg,0,0 },
{ "sxh",op_sxh,1,1,false,am_reg,am_reg,0,0 },
{ "sxo",op_sxo,1,1,false,am_reg,am_reg,0,0 },
{ "sxp",op_sxp,1,1,false,am_reg,am_reg,0,0 },
{ "sxt",op_sxt,1,1,false,am_reg,am_reg,0,0 },
{ "sxw",op_sxw,1,1,false,am_reg,am_reg,0,0 },
{ "tgt", op_calltgt,1 },
{ "tst",op_tst,1,1 },
{ "unlink",op_unlk,4,2,true },
{ "uret", op_uret,1,0,0,0,0,0 },
{ "vadd", op_vadd,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vadds", op_vadds,1,1,false,am_vreg,am_vreg | am_reg,am_reg,am_vmreg },
{ "vdiv", op_vdiv,100,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vdivs", op_vdivs,100 },
{ "veins",op_veins,10 },
{ "ver", op_verbatium,0,1,false, 0,0,0,0 },
{ "vex", op_vex,10 },
{ "vfadd", op_vfadd,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vfadds", op_vfadds,10,1,false, am_vreg, am_vreg, am_reg,0 },
{ "vfmul", op_vfmul,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vfmuls", op_vfmuls,10,1,false, am_vreg, am_vreg, am_reg,0 },
{ "vmask", op_vmask,1,1,false, am_reg,am_reg,am_reg,am_reg },
{ "vmul", op_vmul,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vmuls", op_vmuls,10 },
{ "vseq", op_vseq,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vsge", op_vsge,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vsgt", op_vsgt,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vsle", op_vsle,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vslt", op_vslt,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vsne", op_vsne,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vsub", op_vsub,10,1,false, am_vreg,am_vreg,am_vreg,0 },
{ "vsubs", op_vsubs,10 },
{ "wydendx", op_wydendx,1,1,false,am_reg,am_reg,am_reg | am_imm,0 },
{ "xnor",op_xnor,1,1,false,am_reg,am_reg,am_reg,0 },
{ "xor",op_xor,1,1,false,am_reg,am_reg,am_reg|am_imm,0 },
{ "zxb",op_zxb,1,1,false,am_reg,am_reg,0,0 },
{ "zxt",op_zxt,1,1,false,am_reg,am_reg,0,0 },
{ "zxw",op_zxw,1,1,false,am_reg,am_reg,0,0 }
};

Instruction *GetInsn(int op)
{
	return (Instruction::Get(op));
}

/*
static char *segstr(int op)
{
	static char buf[20];

	switch(op & 0xff00) {
	case op_cs:
		return "cs";
	case op_ss:
		return "ss";
	case op_ds:
		return "ds";
	case op_bs:
		return "bs";
	case op_ts:
		return "ts";
	default:
		sprintf(buf, "seg%d", op >> 8);
		return buf;
	}
}
*/

// Output a friendly register moniker

char *RegMoniker(int regno)
{
	static char buf[4][20];
	static int n;
	int rg;
	bool invert = false;
	bool vector = false;
	bool group = false;
	bool is_float = false;

	if (regno & rt_group) {
		group = true;
		regno &= 0xff;
	}
	if (regno & rt_invert) {
		invert = true;
		regno &= 0xbf;
	}
	if (regno & rt_vector) {
		vector = true;
		regno &= 0x3f;
	}
	if (regno & rt_float) {
		is_float = true;
		regno &= 0x3f;
	}
	n = (n + 1) & 3;
	if (vector) {
		if (invert)
			sprintf_s(&buf[n][0], 20, "~v%d", regno);
		else
			sprintf_s(&buf[n][0], 20, "v%d", regno);
		return (&buf[n][0]);
	}
	if (group) {
		if (invert)
			sprintf_s(&buf[n][0], 20, "~g%d", regno);
		else
			sprintf_s(&buf[n][0], 20, "g%d", regno);
		return (&buf[n][0]);
	}
	if (is_float) {
		if (rg = IsFtmpReg(regno))
			sprintf_s(&buf[n][0], 20, "~ft%d", rg - 1);
		else if (rg = IsFargReg(regno))
			sprintf_s(&buf[n][0], 20, "~ft%d", rg - 1);
		else if (rg = IsFsavedReg(regno))
			sprintf_s(&buf[n][0], 20, "~fs%d", rg-1);
		return (invert ? &buf[n][0] : &buf[n][1]);
	}

	if (rg = IsTempReg(regno)) {
		if (invert)
			sprintf_s(&buf[n][0], 20, "~t%d", rg - 1);// tmpregs[rg - 1]);
		else
			sprintf_s(&buf[n][0], 20, "t%d", rg-1);// tmpregs[rg - 1]);
	}
	else if (rg = IsArgReg(regno)) {
		if (invert)
			sprintf_s(&buf[n][0], 20, "~a%d", rg - 1);// tmpregs[rg - 1]);
		else
			sprintf_s(&buf[n][0], 20, "a%d", rg - 1);// tmpregs[rg - 1]);
	}
	else if (rg = IsSavedReg(regno)) {
		if (invert)
			sprintf_s(&buf[n][0], 20, "~s%d", rg - 1);
		else
			sprintf_s(&buf[n][0], 20, "s%d", rg - 1);
	}
	else
		if (regno==regFP)
			sprintf_s(&buf[n][0], 20, "fp");
//		else if (regno == regAFP)
//			sprintf_s(&buf[n][0], 20, "$afp");
		else if (regno==regGP)
			sprintf_s(&buf[n][0], 20, "gp");
		else if (regno == regGP1)
			sprintf_s(&buf[n][0], 20, "gp1");
//	else if (regno==regPC)
//		sprintf_s(&buf[n][0], 20, "$pc");
	else if (regno==regSP)
		sprintf_s(&buf[n][0], 20, "sp");
	else if (regno==regLR)
		sprintf_s(&buf[n][0], 20, "lr1");
	else if (regno == regLR+1)
		sprintf_s(&buf[n][0], 20, "lr2");
	else if (regno == 0) {
			if (invert)
				sprintf_s(&buf[n][0], 20, "~r%d", regno);
			else
				sprintf_s(&buf[n][0], 20, "r%d", regno);
		}
	else if (regno == 2)
			sprintf_s(&buf[n][0], 20, "r%d", regno);
	else {
		if ((regno & 0x70) == 0x040)
			sprintf_s(&buf[n][0], 20, "$p%d", regno & 0x1f);
		else if ((regno & 0x70) == 0x070)
			sprintf_s(&buf[n][0], 20, "$cr%d", regno & 0x3);
		else
			sprintf_s(&buf[n][0], 20, "r%d", regno);
	}
	return &buf[n][0];
}


/*
 *      generate a register mask for restore and save.
 */
void put_mask(txtoStream& tfs, int mask)
{
	int nn;
	int first = 1;

	for (nn = 0; nn < 32; nn++) {
		if (mask & (1<<nn)) {
			if (!first)
				tfs.printf("/");
			tfs.printf("r%d",nn);
			first = 0;
		}
	}
//	fprintf(output,"#0x%04x",mask);

}

/*
 *      generate a register name from a tempref number.
 */
void putreg(txtoStream& tfs, int r)
{
	tfs.printf("x%d", r);
}

/*
 *      generate a named label.
 */
void gen_strlab(txtoStream& tfs, char *s)
{
	tfs.printf("%s:\n",s);
}

/*
 *      output a compiler generated label.
 */
char *gen_label(int lab, char *nm, char *ns, char d, int sz)
{
	static char buf[500];

	if (nm == NULL)
		sprintf_s(buf, sizeof(buf), "%.400s_%d[%d]:\n", ns, lab, sz);
	else if (strlen(nm) == 0)
		sprintf_s(buf, sizeof(buf), "%.400s_%d[%d]:\n", ns, lab, sz);
	else
		sprintf_s(buf, sizeof(buf), "%.400s_%d[%d]: ; %s\n", ns, lab, sz, nm);
	return (buf);
}
char *put_labels(txtoStream& tfs, char *buf)
{
	tfs.printf("%s", buf);
	return (buf);
}

char *put_label(txtoStream& tfs, int lab, char *nm, char *ns, char d, int sz)
{
  static char buf[500];

	if (ns == nullptr)
		ns = (char *)"";
	if (lab < 0) {
		buf[0] = '\0';
		return buf;
	}
	if (d == 'C') {
//		sprintf_s(buf, sizeof(buf), "%s.%05d", ns, lab);
		sprintf_s(buf, sizeof(buf), ".%05d", lab);
		if (nm == NULL)
			tfs.printf("%s:\n", buf);
		else if (strlen(nm) == 0) {
			tfs.printf("%s:\n", buf);
		}
		else {
			//sprintf_s(buf, sizeof(buf), "%s_%s:\n", nm, ns);
			switch (syntax) {
			case MOT:
				tfs.printf((char*)"%s:	; %s\n", (char*)buf, (char*)nm);
				break;
			default:
				tfs.printf((char*)"%s:	# %s\n", (char*)buf, (char*)nm);
			}
		}
	}
	else {
		if (DataLabelMap[lab] != nullptr)
			ns = (char*)DataLabelMap[lab]->c_str();
		else
			DataLabelMap[lab] = new std::string(ns);
		sprintf_s(buf, sizeof(buf), "%.400s.%05d", ns, lab);
		if (syntax == STD) {
			tfs.printf((char*)"\t.type\t%.400s.%05d,@object\n", (char*)ns, lab);
			tfs.printf((char*)"\t.size\t%.400s.%05d,", (char*)ns, lab);
			tfs.printf("%d\n", sz);
		}
		if (nm == NULL)
			tfs.printf("%s:\n", buf);
		else if (strlen(nm) == 0) {
			tfs.printf("%s:\n", buf);
		}
		else {
			//sprintf_s(buf, sizeof(buf), "%s_%s:\n", nm, ns);
			tfs.printf("%s: ", buf);
			switch (syntax) {
			case MOT:
				tfs.printf((char*)"; %s\n", (char*)nm);
				break;
			default:
				tfs.printf((char*)"# %s\n", (char*)nm);
			}
		}
		if (syntax == MOT) {
			tfs.printf("\tdcb.b\t%d,0\n", sz);
		}
	}
	return (buf);
}

char* put_label(txtoStream& tfs, int lab, const char* nm, const char* ns, char d, int sz) {
	return (put_label(tfs, lab, (char*)nm, (char*)ns, d, sz));
}


void GenerateByte(txtoStream& tfs, int64_t val)
{
	if( gentype == bytegen && outcol < 60) {
        tfs.printf(",%d",(int)val & 0x00ff);
        outcol += 4;
    }
    else {
        nl(tfs);
				if (syntax == MOT)
					tfs.printf("\tdc.b\t%d", (int)val & 0x00ff);
				else
	        tfs.printf("\t.byte\t%d",(int)val & 0x00ff);
        gentype = bytegen;
        outcol = 19;
    }
	genst_cumulative += 1;
}

void GenerateChar(txtoStream& tfs, int64_t val)
{
	if( gentype == chargen && outcol < 60) {
        tfs.printf(",%d",(int)val & 0xffff);
        outcol += 6;
    }
    else {
        nl(tfs);
				if (syntax == MOT)
					tfs.printf("\tdc.w\t%d", (int)val & 0xffff);
				else
					tfs.printf("\t.2byte\t%d",(int)val & 0xffff);
        gentype = chargen;
        outcol = 21;
    }
	genst_cumulative += 2;
}

void GenerateHalf(txtoStream& tfs, int64_t val)
{
	if( gentype == halfgen && outcol < 60) {
        tfs.printf(",%ld",(long)(val & 0xffffffffLL));
        outcol += 10;
    }
    else {
        nl(tfs);
				if (syntax == MOT)
					tfs.printf("\tdc.l\t%ld", (long)(val & 0xffffffffLL));
				else
	        tfs.printf("\t.4byte\t%ld",(long)(val & 0xffffffffLL));
        gentype = halfgen;
        outcol = 25;
    }
	genst_cumulative += 4;
}

void GenerateWord(txtoStream& tfs, int64_t val)
{
	if( gentype == wordgen && outcol < 58) {
        tfs.printf(",%I64d",val);
        outcol += 18;
    }
    else {
        nl(tfs);
				if (syntax == MOT)
					tfs.printf("\tdc.q\t%I64d", val);
				else
	        tfs.printf("\t.8byte\t%I64d",val);
        gentype = wordgen;
        outcol = 33;
    }
	genst_cumulative += 8;
}

void GenerateLong(txtoStream& tfs, Int128 val)
{ 
	if( gentype == longgen && outcol < 56) {
                tfs.printf((char *)",%I64d,%I64d",val.low,val.high);
                outcol += 10;
                }
        else    {
                nl(tfs);
								if (syntax == MOT)
									tfs.printf((char*)"\tdc.q\t%I64d,%I64d", val.low, val.high);
								else
	                tfs.printf((char *)"\t.8byte\t%I64d,%I64d",val.low,val.high);
                gentype = longgen;
                outcol = 25;
                }
		genst_cumulative += 16;
}

void GenerateInt(txtoStream& tfs, int64_t val)
{
	if (gentype == longgen && outcol < 56) {
		tfs.printf(",%I64d", val);
		outcol += 10;
	}
	else {
		nl(tfs);
		if (syntax == MOT)
			tfs.printf("\tdc.q\t%I64d", val);
		else
			tfs.printf("\t.8byte\t%I64d", val);
		gentype = longgen;
		outcol = 25;
	}
	genst_cumulative += 8;
}

void GenerateFloat(txtoStream& tfs, Float128 *val)
{ 
	if (val==nullptr)
		return;
	if (gentype == floatgen && outcol < 60) {
		tfs.printf(",%s", val->ToString(64));
		outcol += 22;
	}
	else {
		nl(tfs);
		if (syntax == MOT) {
			//ofs.printf("\r\n\talign 2\r\n");
			tfs.printf("\tdc.l\t%s", val->ToString(64));
		}
		else {
			//ofs.printf("\r\n\t.align 2\r\n");
			tfs.printf("\t.4byte\t%s", val->ToString(64));
		}
		gentype = floatgen;
		outcol = 25;
	}
	genst_cumulative += 8;
}

void GenerateQuad(txtoStream& tfs, Float128 *val)
{ 
	if (val==nullptr)
		return;
	if (syntax == MOT) {
		//ofs.printf("\r\n\t.align 2\r\n");
		tfs.printf("\tdc.l\t%s", val->ToString(128));
	}
	else {
		//ofs.printf("\r\n\t.align 2\r\n");
		tfs.printf("\t.4byte\t%s", val->ToString(128));
	}
  gentype = longgen;
  outcol = 65;
	genst_cumulative += 16;
}

void GeneratePosit(txtoStream& tfs, Posit64 val)
{
	if (syntax == MOT) {
		//ofs.printf("\r\n\talign 3\r\n");
		tfs.printf("\t.dc.q\t%s", val.ToString());
	}
	else {
		//ofs.printf("\r\n\t.align 3\r\n");
		tfs.printf("\t.8byte\t%s", val.ToString());
	}
	gentype = longgen;
	outcol = 65;
	genst_cumulative += 8;
}

void GenerateReference(txtoStream& tfs, Symbol *sp,int64_t offset)
{
	char sign;
  if( offset < 0) {
    sign = '-';
    offset = -offset;
  }
  else
    sign = '+';
  if( gentype == longgen && outcol < 55 - (int)sp->name->length()) {
        if( sp->storage_class == sc_static) {
			tfs.printf(",");
			tfs.printf(GetNamespace());
			tfs.printf(".%05lld", sp->value.i);
			tfs.putch(sign);
			tfs.printf("%lld", offset);
//                fprintf(output,",%s_%ld%c%d",GetNamespace(),sp->value.i,sign,offset);
		}
        else if( sp->storage_class == sc_thread) {
			tfs.printf(",");
			tfs.printf(GetNamespace());
			tfs.printf(".%05lld", sp->value.i);
			tfs.putch(sign);
			tfs.printf("%lld", offset);
//                fprintf(output,",%s_%ld%c%d",GetNamespace(),sp->value.i,sign,offset);
		}
		else {
			if (offset==0) {
                tfs.printf(",%s",(char *)sp->name->c_str());
			}
			else {
                tfs.printf(",%s",(char *)sp->name->c_str());
				tfs.putch(sign);
				tfs.printf("%lld",offset);
			}
		}
        outcol += (11 + sp->name->length());
    }
    else {
        nl(tfs);
        if(sp->storage_class == sc_static) {
			/*
			if (syntax == MOT)
				ofs.printf("\tdc.q\t%s", GetNamespace());
			else
				ofs.printf("\t.8byte\t%s",GetNamespace());
			*/
			if (syntax == MOT)
				tfs.printf("\tdc.q\t%s", (char *)currentFn->sym->name->c_str());
			else
				tfs.printf("\t.8byte\t%s", (char*)currentFn->sym->name->c_str());
			tfs.printf("_%lld",sp->value.i);
			tfs.putch(sign);
			tfs.printf("%lld",offset);
//            fprintf(output,"\tdw\t%s_%ld%c%d",GetNamespace(),sp->value.i,sign,offset);
		}
        else if(sp->storage_class == sc_thread) {
//            fprintf(output,"\tdw\t%s_%ld%c%d",GetNamespace(),sp->value.i,sign,offset);
			/*
			if (syntax == MOT)
				ofs.printf("\tdc.q\t%s", GetNamespace());
			else
				ofs.printf("\t.8byte\t%s",GetNamespace());
			*/
			if (syntax == MOT)
				tfs.printf("\tdc.q\t%s", (char*)currentFn->sym->name->c_str());
			else
				tfs.printf("\t.8byte\t%s", (char*)currentFn->sym->name->c_str());
			tfs.printf("_%lld",sp->value.i);
			tfs.putch(sign);
			tfs.printf("%lld",offset);
		}
		else {
			if (offset==0) {
				if (syntax == MOT)
					tfs.printf("\tdc.q\t%s", (char*)sp->name->c_str());
				else
					tfs.printf("\t.8byte\t%s",(char *)sp->name->c_str());
			}
			else {
				if (syntax == MOT)
					tfs.printf("\tdc.q\t%s", (char*)sp->name->c_str());
				else
					tfs.printf("\t.8byte\t%s",(char *)sp->name->c_str());
				tfs.putch(sign);
				tfs.printf("%lld", offset);
//				fprintf(output,"\tdw\t%s%c%d",sp->name,sign,offset);
			}
		}
        outcol = 26 + sp->name->length();
        gentype = longgen;
    }
}

void genstorageskip(txtoStream& tfs, int nbytes)
{
	char buf[200];
	int64_t nn;

	nl(tfs);
	nn = (nbytes + 7) >> 3;
	if (nn) {
		if (syntax == MOT)
			sprintf_s(buf, sizeof(buf), "\talign\t3\r\n\tdc.q\t0x%I64X\r\n", nn | 0xFFF0200000000000LL);
		else
			sprintf_s(buf, sizeof(buf), "\t.align\t3\r\n\t.8byte\t0x%I64X\r\n", nn | 0xFFF0200000000000LL);
		tfs.printf("%s", buf);
	}
}

std::streampos genstorage(txtoStream& tfs, int64_t nbytes)
{
	std::streampos pos = tfs.tellp();
	nl(tfs);
	if (nbytes) {
		switch (syntax) {
		case MOT:
			tfs.printf("\tdcb.b\t%I64d,0x00                    \n", nbytes);
			break;
		default:
			;
		}
		/*
		if (syntax == MOT)
			ofs.printf("\tdcb.b\t%I64d,0x00                    \n", nbytes);
		else
			ofs.printf("\t.space\t%I64d,0x00                    \n", nbytes);
		*/
	}
	genst_cumulative += nbytes;
	return (pos);
}

void GenerateLabelReference(txtoStream& tfs, int n, int64_t offset, char* nmspace)
{ 
	char buf[200];
	
	if (nmspace == nullptr)
		nmspace = (char *)"";
	if( gentype == longgen && outcol < 58) {
		if (offset==0)
			sprintf_s(buf, sizeof(buf), ",%s.%05d", nmspace, n);
		else
			sprintf_s(buf, sizeof(buf), ",%s.%05d+%lld", nmspace, n, offset);
		tfs.printf(buf);
        outcol += 6;
    }
    else {
        nl(tfs);
				if (offset == 0) {
					if (syntax == MOT)
						sprintf_s(buf, sizeof(buf), "\tdc.l\t%s.%05d", nmspace, n);
					else
						sprintf_s(buf, sizeof(buf), "\t.4byte\t%s.%05d", nmspace, n);
				}
				else {
					if (syntax == MOT)
						sprintf_s(buf, sizeof(buf), "\tdc.l\t%s.%05d+%lld", nmspace, n, offset);
					else
						sprintf_s(buf, sizeof(buf), "\t.4byte\t%s.%05d+%lld", nmspace, n, offset);
				}
				tfs.printf(buf);
        outcol = 22;
        gentype = longgen;
    }
}

/*
 *      make s a string literal and return it's label number.
 */
int stringlit(char *s)
{      
	struct slit *lp;
	std::string str;

	lp = (struct slit *)allocx(sizeof(struct slit));
	lp->label = nextlabel++;
	str = "";
	if (currentFn)
		str.append(*currentFn->sym->GetFullName());
	lp->str = my_strdup(s);
	lp->nmspace = GetNamespace();
	if (strtab == nullptr) {
		strtab = lp;
		strtab->tail = lp;
	}
	else {
		strtab->tail->next = lp;
		strtab->tail = lp;
	}
	lp->isString = true;
	lp->pass = pass;
	return (lp->label);
}

int litlist(ENODE *node, char* nmspace)
{
	struct slit *lp;
	ENODE *ep;

	lp = strtab;
	while (lp) {
		if (lp->isString) {
			lp = lp->next;
			continue;
		}
		ep = (ENODE *)lp->str;
		if (node->IsEqual(node, ep)) {
			return (lp->label);
		}
		lp = lp->next;
	}
	lp = (struct slit *)allocx(sizeof(struct slit));
	lp->label = nextlabel++;
	lp->str = (char *)node;
	lp->nmspace = my_strdup(nmspace);
	if (strtab == nullptr) {
		strtab = lp;
		strtab->tail = lp;
	}
	else {
		strtab->tail->next = lp;
		strtab->tail = lp;
	}
	lp->isString = false;
	lp->pass = pass;
	return (lp->label);
}

// Since there are two passes to the compiler the cases might already be
// recorded.

int caselit(struct scase *cases, int64_t num)
{
	struct clit *lp;
	std::string str;

	lp = compiler.casetab;
	while (lp) {
		if (memcmp(lp->cases, cases, num * sizeof(struct scase)) == 0)
			return (lp->label);
		lp = lp->next;
	}
	lp = (struct clit *)allocx(sizeof(struct clit));
	lp->label = nextlabel++;
	str = "";
	str.append(*currentFn->sym->GetFullName());
	lp->nmspace = GetNamespace();
	lp->cases = (struct scase *)allocx(sizeof(struct scase)*(int)num);
	lp->num = (int)num;
	lp->pass = pass;
	memcpy(lp->cases, cases, (int)num * sizeof(struct scase));
	lp->next = compiler.casetab;
	compiler.casetab = lp;
	compiler.casetab->next = nullptr;
	return lp->label;
}

int quadlit(Float128 *f128)
{
	Float128 *lp;
	std::string str;

	lp = quadtab;
	// First search for the same literal constant and it's label if found.
	while(lp) {
		if (Float128::IsEqual(f128,Float128::Zero())) {
			if (Float128::IsEqualNZ(lp,f128))
				return (lp->label);
		}
		else if (Float128::IsEqual(lp,f128))
			return (lp->label);
		lp = lp->next;
	}
	lp = (Float128 *)allocx(sizeof(Float128));
	lp->label = nextlabel++;
	Float128::Assign(lp,f128);
	str = "";
	str.append(*currentFn->sym->GetFullName());
	lp->nmspace = GetNamespace();
	lp->next = quadtab;
	quadtab = lp;
	return (lp->label);
}


int NumericLiteral(ENODE* node)
{
	struct nlit* lp, *pp;
	std::string str;

	lp = numeric_tab;
	pp = nullptr;
	if (node) {
		node->constflag = true;
		node->segment = rodataseg;
	}
	// First search for the same literal constant and it's label if found.
	while (lp) {
		if (lp->typ == node->etype) {
			switch (node->etype) {
			case bt_float:
				if (lp->f == node->f)
					return (lp->label);
				break;
			case bt_double:
				if (lp->f == node->f)
					return (lp->label);
				break;
			case bt_quad:
				if (Float128::IsEqual(&node->f128, Float128::Zero())) {
					if (Float128::IsEqualNZ(&lp->f128, &node->f128))
						return (lp->label);
				}
				else if (Float128::IsEqual(&lp->f128, &node->f128))
					return (lp->label);
				break;
			case bt_posit:
				if (Posit64::IsEqual(lp->p, node->posit))
					return (lp->label);
				break;
			}
		}
		pp = lp;
		lp = lp->next;
	}
	lp = (struct nlit*)allocx(sizeof(struct nlit));
	lp->label = nextlabel++;
	Float128::Assign(&lp->f128, &node->f128);
	lp->p.val = node->posit.val;
	lp->f = node->f;
	str = "";
	str.append(*currentFn->sym->GetFullName());
	lp->nmspace = GetNamespace();
	lp->next = numeric_tab;
	lp->typ = node->etype;
	if (node->tp)
		lp->precision = node->tp->precision;
	else
		lp->precision = 64;
	if (pp == nullptr)
		numeric_tab = lp;
	else
		pp->next = lp;
	lp->next = nullptr;
	return (lp->label);
}


char *strip_crlf(char *p)
{
     static char buf[2000];
     int nn;

     for (nn = 0; *p && nn < 1998; p++) {
         if (*p != '\r' && *p!='\n') {
            buf[nn] = *p;
            nn++;
         }
     }
     buf[nn] = '\0';
	 return buf;
}

int64_t GetStrtabLen()
{
	struct slit *p;
	int64_t len;
	char *cp;

	len = 0;
	for (p = strtab; p; p = p->next) {
		if (p->isString) {
			cp = p->str;
			while (*cp) {
				len++;
				cp++;
			}
			len++;	// for null char
		}
	}
	len += 7;
	len >>= 3;
	return (len);
}

int64_t GetQuadtabLen()
{
	Float128 *p;
	int64_t len;

	len = 0;
	for (p = quadtab; p; p = p->next) {
		len++;
	}
	return (len);
}

// Dump the literal pools.

void dumplits(txtoStream& tfs)
{
	char *cp;
	int64_t nn;
	slit *lit;
	union _tagFlt {
		double f;
		int64_t i;
	} Flt;
	union _tagFlt uf;
	int ln;
	struct nlit* lp;
	lp = numeric_tab;
	struct clit* ct;
	Float128* qt;

	dfs.printf("<Dumplits>\n");
	roseg(tfs);
	if (compiler.casetab) {
		nl(tfs);
		align(tfs,8);
		nl(tfs);
	}
	for (ct = compiler.casetab; ct; ct = ct->next) {
		nl(tfs);
		if (ct->pass == 2) {
#ifdef LOCAL_LABELS
			put_label(tfs, casetab->label, "", ""/*casetab->nmspace*/, 'R', casetab->num * 4);// 'D');
#else
			put_label(tfs, ct->label, "", ct->nmspace, 'R', ct->num * 4);// 'D');
#endif
		}
		for (nn = 0; nn < ct->num; nn++) {
			if (ct->cases[nn].pass==2)
				GenerateLabelReference(tfs, ct->cases[nn].label, 0, ct->nmspace);
		}
	}

	if (numeric_tab) {
		nl(tfs);
		align(tfs,8);
		nl(tfs);
	}
	while (lp != nullptr) {
		nl(tfs);
		if (DataLabels[lp->label])
			switch (lp->typ) {
			case bt_float:
			case bt_double:
#ifdef LOCAL_LABELS
				put_label(tfs, lp->label, "", ""/*lp->nmspace*/, 'D', sizeOfFPD);
#else
				put_label(tfs, lp->label, "", lp->nmspace, 'D', sizeOfFPD);
#endif
				if (syntax == MOT)
					tfs.printf("\tdc.l\t");
				else
					tfs.printf("\t.4byte\t");
				lp->f128.Pack(64);
				tfs.printf("%s", lp->f128.ToString(64));
				outcol += 35;
				break;
			case bt_quad:
#ifdef LOCAL_LABELS
				put_label(tfs, lp->label, "", ""/*lp->nmspace*/, 'D', sizeOfFPQ);
#else
				put_label(tfs, lp->label, "", lp->nmspace, 'D', sizeOfFPQ);
#endif
				if (syntax == MOT)
					tfs.printf("\tdc.l\t");
				else
					tfs.printf("\t.4byte\t");
				lp->f128.Pack(64);
				tfs.printf("%s", lp->f128.ToString(64));
				outcol += 35;
				break;
			case bt_posit:
				switch (lp->precision) {
				case 16:
#ifdef LOCAL_LABELS
					put_label(tfs, lp->label, "", ""/*lp->nmspace*/, 'D', 2);
#else
					put_label(tfs, lp->label, "", lp->nmspace, 'D', 2);
#endif
					if (syntax == MOT)
						tfs.printf("\tdc.w\t");
					else
						tfs.printf("\t.2byte\t");
					tfs.printf("0x%04X\n", (int)(lp->p.val & 0xffffLL));
					outcol += 35;
					break;
				case 32:
#ifdef LOCAL_LABELS
					put_label(tfs, lp->label, "", ""/*lp->nmspace*/, 'D', 4);
#else
					put_label(tfs, lp->label, "", lp->nmspace, 'D', 4);
#endif
					if (syntax == MOT)
						tfs.printf("\tdc.l\t");
					else
						tfs.printf("\t.4byte\t");
					tfs.printf("0x%08X\n", (int)(lp->p.val & 0xffffffffLL));
					outcol += 35;
					break;
				default:
#ifdef LOCAL_LABELS
					put_label(tfs, lp->label, "", ""/*lp->nmspace*/, 'D', 8);
#else
					put_label(tfs, lp->label, "", lp->nmspace, 'D', 8);
#endif
					if (syntax == MOT)
						tfs.printf("\tdc.q\t");
					else
						tfs.printf("\t.8byte\t");
					tfs.printf("0x%016I64X\n", lp->p.val);
					outcol += 35;
					break;
				}
				break;
			case bt_void:
#ifdef LOCAL_LABELS
				put_label(tfs, lp->label, "", ""/*lp->nmspace*/, 'D', 0);
#else
				put_label(tfs, lp->label, "", lp->nmspace, 'D', 0);
#endif
				break;
			default:
#ifdef LOCAL_LABELS
				put_label(tfs, lp->label, "", ""/*lp->nmspace*/, 'D', 0);
#else
				put_label(tfs, lp->label, "", lp->nmspace, 'D', 0);
#endif
				;// printf("hi");
			}
		lp = lp->next;
	}

	if (compiler.quadtab) {
		nl(tfs);
		align(tfs,8);
		nl(tfs);
	}

	// Dumping to ro segment - no need for GC skip
	/*
	nn = GetQuadtabLen();
	if (nn) {
		sprintf_s(buf, sizeof(buf), "\tdw\t$%I64X ; GC_skip\n", nn | 0xFFF0200000000000LL);
		ofs.printf("%s", buf);
	}
	*/
	for (qt = compiler.quadtab; qt; qt = qt->next) {
		nl(tfs);
		if (DataLabels[qt->label]) {
#ifdef LOCAL_LABELS
			put_label(tfs, quadtab->label, "", ""/*quadtab->nmspace*/, 'D', sizeOfFPQ);
#else
			put_label(tfs, qt->label, "", qt->nmspace, 'D', sizeOfFPQ);
#endif
			tfs.printf("\tdh\t");
			qt->Pack(64);
			tfs.printf("%s", qt->ToString(64));
			outcol += 35;
		}
	}

	if (strtab) {
		nl(tfs);
		align(tfs,8);
		nl(tfs);
	}

	//nn = GetStrtabLen();
	//if (nn) {
	//	sprintf_s(buf, sizeof(buf), "\tdw\t$%I64X ; GC_skip\n", nn | 0xFFF0200000000000LL);
	//	ofs.printf("%s", buf);
	//}
	for (lit = strtab; lit; lit = lit->next) {
		ENODE *ep;
		if (string_exclude.isMember(lit->label))
			continue;
		agr = ep = (ENODE *)lit->str;
		dfs.printf(".");
		nl(tfs);
		if (!lit->isString) {
			if (DataLabels[lit->label])
#ifdef LOCAL_LABELS
				put_label(tfs, lit->label, strip_crlf(&lit->str[1]), ""/*lit->nmspace*/, 'D', ep->esize);
#else
				put_label(tfs, lit->label, strip_crlf(&lit->str[1]), lit->nmspace, 'D', ep->esize);
#endif
		}
		else {
			cp = lit->str;
			ln = 0;
			switch (*cp) {
			case 'B':
				cp++;
				while (*cp++)
					ln++;
				ln++;
				break;
			case 'W':
				cp++;
				while (*cp++)
					ln+=2;
				ln+=2;
				break;
			case 'T':
				cp++;
				while (*cp++)
					ln += 4;
				ln += 4;
				break;
			case 'O':
				cp++;
				while (*cp++)
					ln += 8;
				ln += 8;
				break;
			}
#ifdef LOCAL_LABELS
			put_label(tfs, lit->label, strip_crlf(&lit->str[1]), ""/*lit->nmspace*/, 'D', ln);
#else
			put_label(tfs, lit->label, strip_crlf(&lit->str[1]), lit->nmspace, 'D', ln);
#endif
		}
		if (lit->isString) {
			cp = lit->str;
			switch (*cp) {
			case 'B':
				cp++;
				while (*cp)
					GenerateByte(tfs,*cp++);
				GenerateByte(tfs,0);
				break;
			case 'W':
				cp++;
				while (*cp)
					GenerateChar(tfs,*cp++);
				GenerateChar(tfs,0);
				break;
			case 'T':
				cp++;
				while (*cp)
					GenerateHalf(tfs,*cp++);
				GenerateHalf(tfs,0);
				break;
			case 'O':
				cp++;
				while (*cp)
					GenerateWord(tfs,*cp++);
				GenerateWord(tfs,0);
				break;
			}
		}
		else {
			if (DataLabels[lit->label]) {
				ep->PutStructConst(tfs);
			}
		}
	}
	strtab = nullptr;
	nl(tfs);
	dfs.printf("</Dumplits>\n");
}

void nl(txtoStream& str)
{       
//	if(outcol > 0) {
	if (str)
		str.printf("\n");
	else
		str.printf("\n");
	outcol = 0;
	gentype = nogen;
//	}
}

void align(txtoStream& tfs, int n)
{
	if (syntax == MOT)
		tfs.printf("\talign\t%d\n", n);
	else
		tfs.printf("\t.align\t%d\n",n);
}

void cseg(txtoStream& tfs)
{
	{
		if (curseg != codeseg) {
			nl(tfs);
			if (syntax == MOT) {
				tfs.printf("\ttext\n");
				tfs.printf("\talign\t%d\n", cpu.code_align);
			}
			else {
				tfs.printf("\t.text\n");
				tfs.printf("\t.align\t%d\n", cpu.code_align);
				curseg = codeseg;
			}
		}
	}
}

void dseg(txtoStream& tfs)
{    
	nl(tfs);
	if (curseg != dataseg) {
		if (syntax == MOT)
			tfs.printf("\tdata\n");
		else
			tfs.printf("\t.data\n");
		curseg = dataseg;
  }
	if (syntax == MOT)
		tfs.printf("\talign\t%d\n", cpu.pagesize);
	else
		tfs.printf("\t.align\t%d\n", cpu.pagesize);
}

void tseg(txtoStream& tfs)
{    
	if( curseg != tlsseg) {
		nl(tfs);
		tfs.printf("\t.tls\n");
		tfs.printf("\t.align\t%d\n", cpu.pagesize);
		curseg = tlsseg;
    }
}

void roseg(txtoStream& tfs)
{
	if( curseg != rodataseg) {
		nl(tfs);
		if (syntax == MOT) {
			tfs.printf("\tdata\n");
			tfs.printf("\talign\t%d\n", cpu.pagesize);
		}
		else {
			tfs.printf("\t.rodata\n");
			tfs.printf("\t.align\t%d\n", cpu.pagesize);
		}
		curseg = rodataseg;
    }
}

void seg(txtoStream& tfs, int sg, int algn)
{    
	nl(tfs);
	if( curseg != sg) {
		if (syntax == MOT) {
			switch (sg) {
			case bssseg:
				tfs.printf("\tbss\n");
				break;
			case dataseg:
				tfs.printf("\tdata\n");
				break;
			case tlsseg:
				tfs.printf("\t.tls\n");
				break;
			case idataseg:
				tfs.printf("\t.idata\n");
				break;
			case codeseg:
				tfs.printf("\ttext\n");
				break;
			case rodataseg:
				tfs.printf("\tdata\n");
				break;
			}
		}
		else {
			switch (sg) {
			case bssseg:
				tfs.printf("\t.bss\n");
				break;
			case dataseg:
				tfs.printf("\t.data\n");
				break;
			case tlsseg:
				tfs.printf("\t.tls\n");
				break;
			case idataseg:
				tfs.printf("\t.idata\n");
				break;
			case codeseg:
				tfs.printf("\t.text\n");
				break;
			case rodataseg:
				tfs.printf("\t.rodata\n");
				break;
			}
		}
		curseg = sg;
    }
	if (syntax == MOT) {
		tfs.printf("\talign\t%d\n", algn);
	}
	else {
		if ((curseg==dataseg && first_dataseg) || curseg!=dataseg)
			tfs.printf("\t.align\t%d\n", algn);
		first_dataseg = false;
	}
}
