/*

Copyright (C) 2012 Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import Types::*;
import ProcTypes::*;
import RegFile::*;
import Vector::*;

interface AddrPred;
  method Addr predPc(Addr pc);
  method Action update(Redirect rd);
endinterface

module mkPcPlus4(AddrPred);
  method Addr predPc(Addr pc) = pc + 4;

  method Action update(Redirect rd);
    noAction;
  endmethod
endmodule

typedef 64 BtbEntries;
typedef Bit#(TLog#(BtbEntries)) BtbIndex;
typedef Bit#(TSub#(TSub#(AddrSz, TLog#(BtbEntries)), 2)) BtbTag;

(* synthesize *)
module mkBtb(AddrPred);
  RegFile#(BtbIndex, Addr) arr <- mkRegFileFull;
  RegFile#(BtbIndex, BtbTag) tagArr <- mkRegFileFull;
  Vector#(BtbEntries, Reg#(Bool)) validArr <- replicateM(mkReg(False));

  function BtbIndex getIndex(Addr pc) = truncate(pc >> 2);
  function BtbTag getTag(Addr pc) = truncateLSB(pc); 

  method Addr predPc(Addr pc);
    BtbIndex index = getIndex(pc);
    BtbTag tag = getTag(pc);
    if(validArr[index] && tag == tagArr.sub(index))
      return arr.sub(index);
    else
      return (pc + 4);
  endmethod

  method Action update(Redirect rd);
    if(rd.taken)
    begin
      let index = getIndex(rd.pc);
      let tag = getTag(rd.pc);
      validArr[index] <= True;
      tagArr.upd(index, tag);
      arr.upd(index, rd.nextPc);
    end
  endmethod
endmodule
