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
import Scoreboard::*;

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
	Addr pc;
	Addr ppc;
	Epoch epoch;
	DecodedInst dInst;
	Data rVal1;
	Data rVal2;
	Data copVal;

	// TODO: DEBUGGING
	Data inst;
} RegFetchData deriving (Bits);

typedef struct {
	ExecInst eInst;
} ExecuteData deriving (Bits);

(* synthesize *)
module [Module] mkProc(Proc);
	RFile       rf <- mkBypassRFile;
	IMemory   iMem <- mkIMemory;
	DMemory   dMem <- mkDMemory;
	Cop        cop <- mkCop;

	/* This Scoreboard is too big for now, but should be safe.
	 * It might need to be expanded later.
	 * Being too small shouldn't cause incorrect behavior,
	 * but it might cause rules to block inappropriately.
	 * Being too big might impact performance,
	 * but hopefully not on the critical path.
	 */
	Scoreboard#(8) sb <- mkPipelineScoreboard();

	Reg#(Addr) pcJump <- mkRegU;

	Bool memReady = iMem.init.done() && dMem.init.done();

	Reg#(Epoch) epoch <-mkReg(1);

	AddrPred addrPred <- mkBtb;

	Reg#(Addr) pcFetch <- mkRegU;
	Reg#(Epoch) epochFetch <-mkReg(1);

	FIFO#(FetchReqData) fetchRespFIFO <- mkFIFO();
	FIFO#(FetchData) decodeFIFO <- mkFIFO();
	FIFO#(DecodeData) regFetchFIFO <- mkFIFO();
	FIFO#(RegFetchData) executeFIFO <- mkFIFO();
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
			regFetchFIFO.enq(decodeData);
		end
	endrule

	Reg#(Maybe#(DecodeData)) regFetchHold <- mkReg(Invalid);
	Reg#(Maybe#(FullIndx)) tempSB <- mkReg(Invalid);
	rule doRegFetch(cop.started);
		DecodeData decodeData;

		if (!isValid(regFetchHold)) begin
			decodeData = regFetchFIFO.first();
			regFetchFIFO.deq();
		end else begin
			decodeData = validValue(regFetchHold);
		end

		if (epoch == decodeData.epoch) begin
			Bool inTempSB = False;
			if (isValid(tempSB)) begin
				if (isValid(decodeData.dInst.src1)) begin
					inTempSB = validValue(tempSB) == validValue(decodeData.dInst.src1);
				end
				if (isValid(decodeData.dInst.src2)) begin
					inTempSB = inTempSB || (validValue(tempSB) == validValue(decodeData.dInst.src2));
				end
			end
			if (sb.search1(decodeData.dInst.src1) || sb.search2(decodeData.dInst.src2) || inTempSB) begin
				regFetchHold <= Valid(decodeData);
				tempSB <= Invalid;
			end else begin
				regFetchHold <= Invalid;

				$display("REG FETCH: epoch: %h pc: %h ppc: %h inst: ", decodeData.epoch, decodeData.pc, decodeData.ppc, showInst(decodeData.inst));

				tempSB <= decodeData.dInst.dst;

				RegFetchData regFetchData;
				regFetchData.rVal1 = rf.rd1(validRegValue(decodeData.dInst.src1));
				regFetchData.rVal2 = rf.rd2(validRegValue(decodeData.dInst.src2));
				regFetchData.copVal = cop.rd(validRegValue(decodeData.dInst.src1));
				regFetchData.pc = decodeData.pc;
				regFetchData.ppc = decodeData.ppc;
				regFetchData.epoch = decodeData.epoch;
				regFetchData.dInst = decodeData.dInst;
				regFetchData.inst = decodeData.inst;
				executeFIFO.enq(regFetchData);
			end
		end
	endrule

	rule doExecute(cop.started);
		RegFetchData regFetchData;
		regFetchData = executeFIFO.first();
		executeFIFO.deq();

		if (epoch == regFetchData.epoch) begin
			$display("EXECUTE: epoch: %h pc: %h ppc: %h inst: ", regFetchData.epoch, regFetchData.pc, regFetchData.ppc, showInst(regFetchData.inst));

			ExecuteData executeData;
			executeData.eInst = exec(regFetchData.dInst, regFetchData.rVal1, regFetchData.rVal2, regFetchData.pc, regFetchData.ppc, regFetchData.copVal);
			sb.insert(executeData.eInst.dst);

			Redirect redirect;
			redirect.pc = regFetchData.pc;
			redirect.nextPc = executeData.eInst.addr;
			redirect.brType = executeData.eInst.iType;
			redirect.taken = executeData.eInst.brTaken;
			redirect.mispredict = executeData.eInst.mispredict;
			addrPred.update(redirect);

			if (executeData.eInst.mispredict) begin
				epoch <= epoch + 1;
				pcJump <= executeData.eInst.addr;
			end

			if(executeData.eInst.iType == Unsupported)
			begin
				$display("Executing unsupported instruction at pc: %x. Exiting. Expanded: ", regFetchData.pc, showInst(regFetchData.inst));
				$fwrite(stderr, "Executing unsupported instruction at pc: %x. Exiting\n", regFetchData.pc);
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
		sb.remove();
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
