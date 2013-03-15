import Types::*;
import ProcTypes::*;
import MemTypes::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import Cop::*;
import GetPut::*;

typedef enum {Fetch, Decode, Execute, WriteBack} State deriving (Bits, Eq);

(* synthesize *)
module [Module] mkProc(Proc);
	Reg#(Addr)  pc <- mkRegU;
	Reg#(Addr) ppc <- mkRegU;
	RFile       rf <- mkRFile;
	IMemory   iMem <- mkIMemory;
	DMemory   dMem <- mkDMemory;
	Cop        cop <- mkCop;

	Reg#(State) state <- mkReg(Fetch);

	Bool memReady = iMem.init.done() && dMem.init.done();

	Reg#(ExecInst) eInstR <- mkRegU;
	Reg#(DecodedInst) dInstR <- mkRegU;

	Reg#(UInt#(4)) epoch0 <-mkReg(0);
	Reg#(UInt#(4)) epoch1 <-mkRegU;

	AddrPred addrPred <- mkPcPlus4;

	rule doFetch(cop.started && state == WriteBack);
		ppc <= addrPred.predPc(pc);

		iMem.req.put(MemReq{op: Ld, addr: ppc, data: ?});

		epoch1 <= epoch0;
	endrule

	rule doDecode(cop.started && state == Decode);
		if (epoch0 == epoch1) begin
			let inst;
			inst <- iMem.resp.get();
			$display("epoch: %h", epoch1);
			$display("ppc: %h inst: (%h) expanded: ", ppc, inst, showInst(inst));

			let dInst = decode(inst);
			dInstR <= dInst;
		end
		// switch to execute state
		state <= Execute;
	endrule

	rule doExecute(cop.started && state == Execute);
		if (epoch0 == epoch1) begin
			let dInst = dInstR;

			let rVal1 = rf.rd1(validRegValue(dInst.src1));
			let rVal2 = rf.rd2(validRegValue(dInst.src2));

			let copVal = cop.rd(validRegValue(dInst.src1));

			let eInst = exec(dInst, rVal1, rVal2, pc, ppc, copVal);

			if(eInst.iType == Unsupported)
			begin
				$fwrite(stderr, "Executing unsupported instruction at pc: %x. Exiting\n", pc);
				$finish;
			end

			if(eInst.iType == Ld)
			begin
				dMem.req.put(MemReq{op: Ld, addr: eInst.addr, data: ?});
			end
			else if(eInst.iType == St)
			begin
				dMem.req.put(MemReq{op: St, addr: eInst.addr, data: eInst.data});
			end

			eInstR <= eInst;
		end
		state <= WriteBack;
	endrule

	rule doWriteBack(cop.started && state == WriteBack);
		if (epoch0 == epoch1) begin
			let eInst = eInstR;
			if(eInst.iType == Ld)
			begin
				eInst.data <- dMem.resp.get();
			end

			if (isValid(eInst.dst) && validValue(eInst.dst).regType == Normal) begin
				rf.wr(validRegValue(eInst.dst), eInst.data);
			end

			pc <= eInst.brTaken ? eInst.addr : pc + 4;

			if (eInst.mispredict) begin
				epoch0 <= epoch0 + 1;
			end

			cop.wr(eInst.dst, eInst.data);
		end
		state <= Decode;
	endrule

	method ActionValue#(Tuple2#(RIndx, Data)) cpuToHost;
		let ret <- cop.cpuToHost;
		return ret;
	endmethod

	method Action hostToCpu(Bit#(32) startpc) if (!cop.started && memReady);
		cop.start;
		pc <= startpc;
	endmethod

	interface MemInit iMemInit = iMem.init;
	interface MemInit dMemInit = dMem.init;
endmodule
