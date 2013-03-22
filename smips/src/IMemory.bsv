import Types::*;
import MemTypes::*;
import BRAM::*;
import MemInit::*;

interface IMemory;
	interface Put#(MemReq) req;
	interface Get#(MemResp) resp;
	interface MemInitIfc init;
endinterface

(* synthesize *)
module mkIMemory(IMemory);
	BRAM_Configure cfg = defaultValue;
	BRAM1Port#(Bit#(16), Data) bram <- mkBRAM1Server(cfg);
	MemInitIfc memInit <- mkMemInitBRAM(bram);

	interface Put req;
		method Action put(MemReq r) if (memInit.done());
			Bit#(16) addr = truncate(r.addr >> 2);
			if (r.op == St) begin
				bram.portA.request.put(BRAMRequest { write: True
				                                   , responseOnWrite: False
								   , address: addr
								   , datain: r.data });
			end else begin
				bram.portA.request.put(BRAMRequest { write: False
				                                   , responseOnWrite: False
								   , address: addr
								   , datain: r.data });
			end
		endmethod
	endinterface

	interface Get resp;
		method ActionValue#(MemResp) get() if (memInit.done());
			let data;
			data <- bram.portA.response.get();
			return data;
		endmethod
	endinterface

	interface MemInitIfc init = memInit;
endmodule
