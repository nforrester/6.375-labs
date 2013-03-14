/*

Copyright (C) 2012

Arvind <arvind@csail.mit.edu>
Derek Chiou <derek@ece.utexas.edu>
Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import Types::*;
import ProcTypes::*;
import Vector::*;

(* noinline *)
function DecodedInst decode(Data inst);
  DecodedInst dInst = ?;
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
      dInst.iType = Alu;
      dInst.aluFunc = case (opcode)
        opADDIU, opLUI: Add;
        opSLTI: Slt;
        opSLTIU: Sltu;
        opANDI: And;
        opORI: Or;
        opXORI: Xor;
      endcase;
      dInst.dst  = validReg(rt);
      dInst.src1 = validReg(rs);
      dInst.src2 = Invalid;
      dInst.imm = Valid(case (opcode)
        opADDIU, opSLTI, opSLTIU: signExtend(imm);
        opLUI: {imm, 16'b0};
        default: zeroExtend(imm);
      endcase);
      dInst.brFunc = NT;
    end
    
    opLB, opLH, opLW, opLBU, opLHU:
    begin
      dInst.iType = Ld;
      dInst.aluFunc = Add;
      dInst.dst  = validReg(rt);
      dInst.src1 = validReg(rs);
      dInst.src2 = Invalid;
      dInst.imm    = Valid(signExtend(imm));
      dInst.brFunc = NT;
    end
    
    opSB, opSH, opSW:
    begin
      dInst.iType = St;
      dInst.aluFunc = Add;
      dInst.dst  = Invalid;
      dInst.src1 = validReg(rs);
      dInst.src2 = validReg(rt);
      dInst.imm    = Valid(signExtend(imm));
      dInst.brFunc = NT;
    end
    
    opJ, opJAL:
    begin
      dInst.iType = J;
      dInst.dst  = opcode == opJ? Invalid: validReg(31);
      dInst.src1 = Invalid;
      dInst.src2 = Invalid;
      dInst.imm  = Valid(zeroExtend({target,2'b00}));
      dInst.brFunc = AT;
    end
    
    opBEQ, opBNE, opBLEZ, opBGTZ, opRT:    
    begin
      dInst.iType = Br;
      dInst.brFunc = case(opcode)
        opBEQ: Eq;
        opBNE: Neq;
        opBLEZ: Le;
        opBGTZ: Gt;
        opRT: (rt==rtBLTZ ? Lt : Ge);
      endcase;
      dInst.dst  = Invalid;
      dInst.src1 = validReg(rs);
      dInst.src2 = (opcode==opBEQ || opcode==opBNE)? validReg(rt) : Invalid;
      dInst.imm  = Valid(signExtend(imm) << 2);
    end
    
    opRS: 
    begin
      case (rs)
        rsMFC0:
        begin
          dInst.iType = Mfc0;
          dInst.dst  = validReg(rt);
          dInst.src1 = validCop(rd);
          dInst.src2 = Invalid;
          dInst.imm   = Invalid;
          dInst.brFunc = NT;
        end
        rsMTC0:
        begin
          dInst.iType = Mtc0;
          dInst.dst  = validCop(rd);
          dInst.src1 = validReg(rt);
          dInst.src2 = Invalid;
          dInst.imm   = Invalid;
          dInst.brFunc = NT;
        end
      endcase
    end
    
    opFUNC:
    case(funct)
      fcJR, fcJALR:
      begin
        dInst.iType = Jr;
        dInst.dst  = funct == fcJR? Invalid: validReg(rd);
        dInst.src1 = validReg(rs);
        dInst.src2 = Invalid;
        dInst.imm  = Invalid;
        dInst.brFunc = AT;
      end
      
      fcSLL, fcSRL, fcSRA:
      begin
        dInst.iType = Alu;
        dInst.aluFunc = case (funct)
          fcSLL: LShift;
          fcSRL: RShift;
          fcSRA: Sra;
        endcase;
        dInst.dst  = validReg(rd);
        dInst.src1 = validReg(rt);
        dInst.src2 = Invalid;
        dInst.imm  = Valid(zeroExtend(shamt));
        dInst.brFunc = NT;
      end

      fcSLLV, fcSRLV, fcSRAV: 
      begin
        dInst.iType = Alu;
        dInst.aluFunc = case (funct)
          fcSLLV: LShift;
          fcSRLV: RShift;
          fcSRAV: Sra;
        endcase;
        dInst.dst  = validReg(rd);
        dInst.src1 = validReg(rt);
        dInst.src2 = validReg(rs);
        dInst.imm  = Invalid;
        dInst.brFunc = NT;
      end

      fcADDU, fcSUBU, fcAND, fcOR, fcXOR, fcNOR, fcSLT, fcSLTU:
      begin
        dInst.iType = Alu;
        dInst.aluFunc = case (funct)
          fcADDU: Add;
          fcSUBU: Sub;
          fcAND : And;
          fcOR  : Or;
          fcXOR : Xor;
          fcNOR : Nor;
          fcSLT : Slt;
          fcSLTU: Sltu;
        endcase;
        dInst.dst  = validReg(rd);
        dInst.src1 = validReg(rs);
        dInst.src2 = validReg(rt);
        dInst.imm  = Invalid;
        dInst.brFunc = NT;
      end

      default: 
        begin
          dInst.iType = Unsupported;
          dInst.dst  = Invalid;
          dInst.src1 = Invalid;
          dInst.src2 = Invalid;
          dInst.imm  = Invalid;
          dInst.brFunc = NT;
        end
    endcase

    default: 
    begin
      dInst.iType = Unsupported;
      dInst.dst  = Invalid;
      dInst.src1 = Invalid;
      dInst.src2 = Invalid;
      dInst.imm  = Invalid;
      dInst.brFunc = NT;
    end
  endcase

  if(dInst.dst matches tagged Valid .dst &&& dst.regType == Normal &&& dst.idx == 0)
    dInst.dst = tagged Invalid;

  return dInst;
endfunction

