/*

Copyright (C) 2012

Arvind <arvind@csail.mit.edu>
Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import Types::*;
import FShow::*;
import MemTypes::*;

interface Proc;
   method ActionValue#(Tuple2#(RIndx, Data)) cpuToHost;
   method Action hostToCpu(Addr startpc);
   interface MemInitIfc iMemInit;
   interface MemInitIfc dMemInit;
endinterface

typedef Bit#(5)  RIndx;

typedef enum {Unsupported, Alu, Ld, St, J, Jr, Br, Mfc0, Mtc0} IType deriving(Bits, Eq);
typedef enum {Eq, Neq, Le, Lt, Ge, Gt, AT, NT} BrFunc deriving(Bits, Eq);
typedef enum {Add, Sub, And, Or, Xor, Nor, Slt, Sltu, LShift, RShift, Sra} AluFunc deriving(Bits, Eq);

typedef enum {Normal, CopReg} RegType deriving (Bits, Eq);

typedef void Exception;

typedef struct {
  Addr pc;
  Addr nextPc;
  IType brType;
  Bool taken;
  Bool mispredict;
} Redirect deriving (Bits, Eq);

typedef struct {
  RegType regType;
  RIndx idx;
} FullIndx deriving (Bits, Eq);

function Maybe#(FullIndx) validReg(RIndx idx) = Valid (FullIndx{regType: Normal, idx: idx});

function Maybe#(FullIndx) validCop(RIndx idx) = Valid (FullIndx{regType: CopReg, idx: idx});

function RIndx validRegValue(Maybe#(FullIndx) idx) = validValue(idx).idx;

typedef struct {
  IType            iType;
  AluFunc          aluFunc;
  BrFunc           brFunc;
  Maybe#(FullIndx) dst;
  Maybe#(FullIndx) src1;
  Maybe#(FullIndx) src2;
  Maybe#(Data)     imm;
} DecodedInst deriving(Bits, Eq);

typedef struct {
  IType            iType;
  Maybe#(FullIndx) dst;
  Data             data;
  Addr             addr;
  Bool             mispredict;
  Bool             brTaken;
} ExecInst deriving(Bits, Eq);

Bit#(6) opFUNC  = 6'b000000;
Bit#(6) opRT    = 6'b000001;
Bit#(6) opRS    = 6'b010000;
                            
Bit#(6) opLB    = 6'b100000;
Bit#(6) opLH    = 6'b100001;
Bit#(6) opLW    = 6'b100011;
Bit#(6) opLBU   = 6'b100100;
Bit#(6) opLHU   = 6'b100101;
Bit#(6) opSB    = 6'b101000;
Bit#(6) opSH    = 6'b101001;
Bit#(6) opSW    = 6'b101011;
                            
Bit#(6) opADDIU = 6'b001001;
Bit#(6) opSLTI  = 6'b001010;
Bit#(6) opSLTIU = 6'b001011;
Bit#(6) opANDI  = 6'b001100;
Bit#(6) opORI   = 6'b001101;
Bit#(6) opXORI  = 6'b001110;
Bit#(6) opLUI   = 6'b001111;
                            
Bit#(6) opJ     = 6'b000010;
Bit#(6) opJAL   = 6'b000011;
Bit#(6) fcJR    = 6'b001000;
Bit#(6) fcJALR  = 6'b001001;
Bit#(6) opBEQ   = 6'b000100;
Bit#(6) opBNE   = 6'b000101;
Bit#(6) opBLEZ  = 6'b000110;
Bit#(6) opBGTZ  = 6'b000111;
Bit#(5) rtBLTZ  = 5'b00000;
Bit#(5) rtBGEZ  = 5'b00001;

Bit#(5) rsMFC0  = 5'b00000;
Bit#(5) rsMTC0  = 5'b00100;
Bit#(5) rsERET  = 5'b10000;

Bit#(6) fcSLL   = 6'b000000;
Bit#(6) fcSRL   = 6'b000010;
Bit#(6) fcSRA   = 6'b000011;
Bit#(6) fcSLLV  = 6'b000100;
Bit#(6) fcSRLV  = 6'b000110;
Bit#(6) fcSRAV  = 6'b000111;
Bit#(6) fcADDU  = 6'b100001;
Bit#(6) fcSUBU  = 6'b100011;
Bit#(6) fcAND   = 6'b100100;
Bit#(6) fcOR    = 6'b100101;
Bit#(6) fcXOR   = 6'b100110;
Bit#(6) fcNOR   = 6'b100111;
Bit#(6) fcSLT   = 6'b101010;
Bit#(6) fcSLTU  = 6'b101011;
Bit#(6) fcMULT  = 6'b011000;

function Bool dataHazard(Maybe#(RIndx) src1, Maybe#(RIndx) src2, Maybe#(RIndx) dst);
    return (isValid(dst) && ((isValid(src1) && validValue(dst)==validValue(src1)) ||
                             (isValid(src2) && validValue(dst)==validValue(src2))));
endfunction

function Fmt showInst(Data inst);
  Fmt ret = fshow("");
  let opcode = inst[ 31 : 26 ];
  let rs     = inst[ 25 : 21 ];
  let rt     = inst[ 20 : 16 ];
  let rd     = inst[ 15 : 11 ];
  let shamt  = inst[ 10 :  6 ];
  let funct  = inst[  5 :  0 ];
  let imm    = inst[ 15 :  0 ];
  let target = inst[ 25 :  0 ];

  case (opcode)
    opADDIU, opSLTI, opSLTIU, opANDI, opORI, opXORI, opLUI:
    begin
      ret = case (opcode)
        opADDIU: fshow("addiu");
        opLUI: fshow("lui");
        opSLTI: fshow("slti");
        opSLTIU: fshow("sltiu");
        opANDI: fshow("andi");
        opORI: fshow("ori");
        opXORI: fshow("xori");
      endcase;
      ret = ret + fshow(" ") + fshow(rt) + fshow(" = ") + fshow(rs) + fshow(" ");
      ret = ret + (case (opcode)
        opADDIU, opSLTI, opSLTIU: fshow(imm);
        opLUI: fshow({imm, 16'b0});
        default: fshow(imm);
      endcase);
    end
    
    opLB: 
      ret = fshow("lb ") + fshow(rt) + fshow(" = ") + fshow(rs) + fshow(" ") + fshow(imm);
    
    opLH: 
      ret = fshow("lh ") + fshow(rt) + fshow(" = ") + fshow(rs) + fshow(" ") + fshow(imm);
    
    opLW: 
      ret = fshow("lw ") + fshow(rt) + fshow(" = ") + fshow(rs) + fshow(" ") + fshow(imm);
    
    opLBU: 
      ret = fshow("lbu ") + fshow(rt) + fshow(" = ") + fshow(rs) + fshow(" ") + fshow(imm);
    
    opLHU: 
      ret = fshow("lhu ") + fshow(rt) + fshow(" = ") + fshow(rs) + fshow(" ") + fshow(imm);
    
    opSB:
      ret = fshow("sb ") + fshow(rs) + fshow(" ") + fshow(rt) + fshow(" ") + fshow(imm);
    
    opSH:
      ret = fshow("sh ") + fshow(rs) + fshow(" ") + fshow(rt) + fshow(" ") + fshow(imm);
    
    opSW:
      ret = fshow("sw ") + fshow(rs) + fshow(" ") + fshow(rt) + fshow(" ") + fshow(imm);
    
    opJ, opJAL:
      ret = (opcode == opJ? fshow("J ") : fshow("JAL ")) + fshow({target, 2'b00});
    
    opBEQ, opBNE, opBLEZ, opBGTZ, opRT:    
    begin
      ret = case(opcode)
        opBEQ: fshow("beq");
        opBNE: fshow("bne");
        opBLEZ: fshow("blez");
        opBGTZ: fshow("bgtz");
        opRT: (rt==rtBLTZ ? fshow("bltz") : fshow("bgez"));
      endcase;
      ret = ret + fshow(" ") + fshow(rs) + fshow(" ") + ((opcode == opBEQ || opcode == opBNE)? fshow(rt) : fshow(imm));
    end
    
    opRS: 
    begin
      case (rs)
        rsMFC0:
          ret = fshow("mfc0 ") + fshow(rt) + fshow(" = [") + fshow(rd) + fshow("]");
        rsMTC0:
          ret = fshow("mtc0 [") + fshow(rd) + fshow("] = ") + fshow(rt);
      endcase
    end
    
    opFUNC:
    case(funct)
      fcJR, fcJALR:
        ret = (funct == fcJR ? fshow("jr") : fshow("jalr")) + fshow(" ") + fshow(rd) + fshow(" = ") + fshow(rs);
      
      fcSLL, fcSRL, fcSRA:
      begin
        ret = case (funct)
          fcSLL: fshow("sll");
          fcSRL: fshow("srl");
          fcSRA: fshow("sra");
        endcase;
        ret = ret + fshow(" ") + fshow(rd) + fshow(" = ") + fshow(rt) + fshow(" ") + fshow(shamt);
      end

      fcSLLV, fcSRLV, fcSRAV: 
      begin
        ret = case (funct)
          fcSLLV: fshow("sllv");
          fcSRLV: fshow("srlv");
          fcSRAV: fshow("srav");
        endcase;
        ret = ret + fshow(" ") + fshow(rd) + fshow(" = ") + fshow(rt) + fshow(" ") + fshow(rs);
      end

      default: 
      begin
        ret = case (funct)
          fcADDU: fshow("addu");
          fcSUBU: fshow("subu");
          fcAND : fshow("and");
          fcOR  : fshow("or");
          fcXOR : fshow("xor");
          fcNOR : fshow("nor");
          fcSLT : fshow("slt");
          fcSLTU: fshow("sltu");
        endcase;
        ret = ret + fshow(" ") + fshow(rd) + fshow(" = ") + fshow(rs) + fshow(" ") + fshow(rt);
      end
    endcase

    default: 
      ret = fshow("nop");
  endcase

  return ret;
  
endfunction
