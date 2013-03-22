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
import AddrPred::*;
import FIFO::*;

typedef UInt#(4) Epoch;

typedef struct {
	Addr pc;
	Addr ppc;
	Epoch epoch;
} FetchReqData deriving (Bits);

typedef struct {
	Addr pc;
	Addr ppc;
	Epoch epoch;
	Data inst;
} FetchData deriving (Bits);

typedef struct {
	Addr pc;
	Addr ppc;
	Epoch epoch;
	DecodedInst dInst;

	// TODO: DEBUGGING
	Data inst;
} DecodeData deriving (Bits);

typedef struct {
	ExecInst eInst;
} ExecuteData deriving (Bits);

(* synthesize *)
module [Module] mkProc(Proc);
	RFile       rf <- mkBypassRFile;
	IMemory   iMem <- mkIMemory;
	DMemory   dMem <- mkDMemory;
	Cop        cop <- mkCop;

	Reg#(Addr) pcJump <- mkRegU;

	Bool memReady = iMem.init.done() && dMem.init.done();

	Reg#(Epoch) epoch <-mkReg(1);

	AddrPred addrPred <- mkPcPlus4;

	Reg#(Addr) pcFetch <- mkRegU;
	Reg#(Epoch) epochFetch <-mkReg(1);

	FIFO#(FetchReqData) fetchRespFIFO <- mkFIFO();
	FIFO#(FetchData) decodeFIFO <- mkFIFO();
	FIFO#(DecodeData) executeFIFO <- mkFIFO();
	FIFO#(ExecuteData) writeBackFIFO <- mkFIFO();

	rule doFetchReq(cop.started);
		let pcNow;
		let epochNow;
		if (epochFetch != epoch) begin
			epochNow = epoch;
			pcNow = pcJump;
		end else begin
			epochNow = epochFetch;
			pcNow = pcFetch;
		end
		let ppc = addrPred.predPc(pcNow);
		pcFetch <= ppc;
		epochFetch <= epochNow;

		FetchReqData fetchReqData;
		fetchReqData.pc = pcNow;
		fetchReqData.ppc = ppc;
		fetchReqData.epoch = epochNow;
		fetchRespFIFO.enq(fetchReqData);
		iMem.req.put(MemReq{op: Ld, addr: pcNow, data: ?});
		$display("FETCHreq: epoch: %h pc: %h ppc: %h", fetchReqData.epoch, fetchReqData.pc, fetchReqData.ppc);
	endrule

	rule doFetchResp(cop.started);
		FetchReqData fetchReqData;
		fetchReqData = fetchRespFIFO.first();
		fetchRespFIFO.deq();
		FetchData fetchData;
		fetchData.pc = fetchReqData.pc;
		fetchData.ppc = fetchReqData.ppc;
		fetchData.epoch = fetchReqData.epoch;
		fetchData.inst <- iMem.resp.get();
		decodeFIFO.enq(fetchData);
		$display("FETCHresp: epoch: %h pc: %h ppc: %h", fetchData.epoch, fetchData.pc, fetchData.ppc);
	endrule

	rule doDecode(cop.started);
		FetchData fetchData;
		fetchData = decodeFIFO.first();
		decodeFIFO.deq();
		if (epoch == fetchData.epoch) begin
			$display("DECODE: epoch: %h pc: %h ppc: %h inst: ", fetchData.epoch, fetchData.pc, fetchData.ppc, showInst(fetchData.inst));

			DecodeData decodeData;
			decodeData.pc = fetchData.pc;
			decodeData.ppc = fetchData.ppc;
			decodeData.epoch = fetchData.epoch;
			decodeData.dInst = decode(fetchData.inst);
			decodeData.inst = fetchData.inst;
			executeFIFO.enq(decodeData);
		end
	endrule

	rule doExecute(cop.started);
		DecodeData decodeData;
		decodeData = executeFIFO.first();
		executeFIFO.deq();
		if (epoch == decodeData.epoch) begin
			$display("EXECUTE: epoch: %h pc: %h ppc: %h inst: ", decodeData.epoch, decodeData.pc, decodeData.ppc, showInst(decodeData.inst));
			ExecuteData executeData;

			let rVal1 = rf.rd1(validRegValue(decodeData.dInst.src1));
			let rVal2 = rf.rd2(validRegValue(decodeData.dInst.src2));

			let copVal = cop.rd(validRegValue(decodeData.dInst.src1));

			executeData.eInst = exec(decodeData.dInst, rVal1, rVal2, decodeData.pc, decodeData.ppc, copVal);

			if (executeData.eInst.mispredict) begin
				epoch <= epoch + 1;
				pcJump <= executeData.eInst.addr;
			end

			if(executeData.eInst.iType == Unsupported)
			begin
				$display("Executing unsupported instruction at pc: %x. Exiting. Expanded: ", decodeData.pc, showInst(decodeData.inst));
				$fwrite(stderr, "Executing unsupported instruction at pc: %x. Exiting\n", decodeData.pc);
				$finish;
			end

			if(executeData.eInst.iType == Ld)
			begin
				dMem.req.put(MemReq{op: Ld, addr: executeData.eInst.addr, data: ?});
			end
			else if(executeData.eInst.iType == St)
			begin
				dMem.req.put(MemReq{op: St, addr: executeData.eInst.addr, data: executeData.eInst.data});
			end

			writeBackFIFO.enq(executeData);
		end
	endrule

	rule doWriteBack(cop.started);
		ExecuteData executeData;
		executeData = writeBackFIFO.first();
		writeBackFIFO.deq();
		$display("WRITEBACK");
		if(executeData.eInst.iType == Ld)
		begin
			executeData.eInst.data <- dMem.resp.get();
		end

		if (isValid(executeData.eInst.dst) && validValue(executeData.eInst.dst).regType == Normal) begin
			rf.wr(validRegValue(executeData.eInst.dst), executeData.eInst.data);
		end

		cop.wr(executeData.eInst.dst, executeData.eInst.data);
	endrule

	method ActionValue#(Tuple2#(RIndx, Data)) cpuToHost;
		let ret <- cop.cpuToHost;
		return ret;
	endmethod

	method Action hostToCpu(Bit#(32) startpc) if (!cop.started && memReady);
		cop.start;
		pcFetch <= startpc;
	endmethod

	interface MemInit iMemInit = iMem.init;
	interface MemInit dMemInit = dMem.init;
endmodule
