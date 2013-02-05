
import FIFO::*;

import AudioProcessorTypes::*;

module mkFIRFilter (AudioProcessor);

    FIFO#(Sample) infifo <- mkFIFO();
    FIFO#(Sample) outfifo <- mkFIFO();

    rule process (True);
        $display("got sample: %h", infifo.first());
        infifo.deq();
        outfifo.enq(infifo.first());
    endrule

    method Action putSampleInput(Sample in);
        infifo.enq(in);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        outfifo.deq();
        return outfifo.first();
    endmethod

endmodule

