
import GetPut::*;

import Types::*;

typedef Data Line;

typedef Line MemResp;

typedef enum{Ld, St} MemOp deriving(Eq,Bits);
typedef struct{
    MemOp op;
    Addr  addr;
    Data  data;
} MemReq deriving(Eq,Bits);

typedef 16 NumTokens;
typedef Bit#(TLog#(NumTokens)) Token;

typedef 16 LoadBufferSz;
typedef Bit#(TLog#(LoadBufferSz)) LoadBufferIndex;

typedef struct {
    Addr addr;
    Data data;
} MemInitLoad deriving(Eq, Bits);

typedef union tagged {
   MemInitLoad InitLoad;
   void InitDone;
} MemInit deriving(Eq, Bits);

interface MemInitIfc;
  interface Put#(MemInit) request;
  method Bool done();
endinterface

