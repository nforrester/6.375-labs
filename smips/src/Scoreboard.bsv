/*

Copyright (C) 2012 Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import Fifo::*;
import ProcTypes::*;

interface Scoreboard#(numeric type size);
  method Action insert(Maybe#(FullIndx) r);
  method Action remove;
  method Bool search1(Maybe#(FullIndx) r);
  method Bool search2(Maybe#(FullIndx) r);
  method Bool search3(Maybe#(FullIndx) r);
  method Action clear;
endinterface

function Bool isFound(Maybe#(FullIndx) x, Maybe#(FullIndx) k);
   if(x matches tagged Valid .xv &&& k matches tagged Valid .kv &&& kv == xv)
     return True;
   else
     return False;
endfunction

// search CF {enq, deq, first, notEmpty, notFull}
// deq CF enq
// search < clear
module mkCFScoreboard(Scoreboard#(size));
  SFifo#(size, Maybe#(FullIndx), Maybe#(FullIndx))  f <- mkCFSFifo(isFound);

  method insert = f.enq;

  method remove = f.deq;

  method search1 = f.search;
  method search2 = f.search;
  method search3 = f.search;

  method clear = f.clear;
endmodule

// notEmpty < first < deq < search < notFull < enq < clear
module mkPipelineScoreboard(Scoreboard#(size));
  SFifo#(size, Maybe#(FullIndx), Maybe#(FullIndx)) f <- mkPipelineSFifo(isFound);

  method insert = f.enq;

  method remove = f.deq;

  method search1 = f.search;
  method search2 = f.search;
  method search3 = f.search;

  method clear = f.clear;
endmodule

interface CountScoreboard#(numeric type size);
  method Action insert(Maybe#(FullIndx) r);
  method Action remove;
  method Bit#(TLog#(TAdd#(size, 1))) search1(Maybe#(FullIndx) r);
  method Bit#(TLog#(TAdd#(size, 1))) search2(Maybe#(FullIndx) r);
  method Bit#(TLog#(TAdd#(size, 1))) search3(Maybe#(FullIndx) r);
  method Action clear;
endinterface

// search CF {enq, deq, first, notEmpty, notFull}
// deq CF enq
// search < clear
module mkCFCountScoreboard(CountScoreboard#(size));
  SCountFifo#(size, Maybe#(FullIndx), Maybe#(FullIndx))  f <- mkCFSCountFifo(isFound);

  method insert = f.enq;

  method remove = f.deq;

  method search1 = f.search;
  method search2 = f.search;
  method search3 = f.search;

  method clear = f.clear;
endmodule

