
import ClientServer::*;
import FIFO::*;
import GetPut::*;
import DefaultValue::*;
import SceMi::*;
import Clocks::*;
import ResetXactor::*;
import FixedPoint::*;

import AudioPipeline::*;
import AudioProcessorTypes::*;

typedef FixedPoint#(16, 16) FactorType;

interface DutInterface;
	interface Server#(Sample, Sample) dutServer;
	interface Put#(FactorType) setfactor;
endinterface

(* synthesize *)
module [Module] mkDutWrapper (DutInterface);

	SettableAudioProcessor#(16, 16) pipeline <- mkAudioPipeline();

	interface Server dutServer;
		interface Put request;
			method Action put(Sample x);
				pipeline.auProc.putSampleInput(x);
			endmethod
		endinterface

		interface Get response;
			method ActionValue#(Sample) get();
				let x <- pipeline.auProc.getSampleOutput();
				return x;
			endmethod
		endinterface
	endinterface

	interface Put setfactor = pipeline.setfactor;
endmodule

module [SceMiModule] mkSceMiLayer();

    SceMiClockConfiguration conf = defaultValue;

    SceMiClockPortIfc clk_port <- mkSceMiClockPort(conf);
    DutInterface dut <- buildDutWithSoftReset(mkDutWrapper, clk_port);

    Empty processor <- mkServerXactor(dut.dutServer, clk_port);
    Empty setfactor <- mkPutXactor(dut.setfactor, clk_port);

    Empty shutdown <- mkShutdownXactor();
endmodule

