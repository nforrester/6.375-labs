
import ClientServer::*;
import FIFO::*;
import GetPut::*;
import DefaultValue::*;
import SceMi::*;
import Clocks::*;
import ResetXactor::*;

import AudioPipeline::*;
import AudioProcessorTypes::*;

typedef Server#(Sample, Sample) DutInterface;

(* synthesize *)
module [Module] mkDutWrapper (DutInterface);

    AudioProcessor pipeline <- mkAudioPipeline();

    interface Put request;
        method Action put(Sample x);
            pipeline.putSampleInput(x);
        endmethod
    endinterface

    interface Get response;
        method ActionValue#(Sample) get();
            let x <- pipeline.getSampleOutput();
            return x;
        endmethod
    endinterface
endmodule

module [SceMiModule] mkSceMiLayer();

    SceMiClockConfiguration conf = defaultValue;

    SceMiClockPortIfc clk_port <- mkSceMiClockPort(conf);
    DutInterface dut <- buildDutWithSoftReset(mkDutWrapper, clk_port);

    Empty processor <- mkServerXactor(dut, clk_port);

    Empty shutdown <- mkShutdownXactor();
endmodule

