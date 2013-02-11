import FIFO::*;
import FixedPoint::*;
import Vector::*;
import Multiplier::*;

import AudioProcessorTypes::*;
import FilterCoefficients::*;

module mkFIRFilter (AudioProcessor);
    FIFO#(Sample) infifo <- mkFIFO();
    FIFO#(Sample) outfifo <- mkFIFO();

    Vector#(8, Reg#(Sample)) r <- replicateM(mkReg(0));

    rule process (True);
        $display("got sample: %h", infifo.first());
    	Sample sample = infifo.first();
	infifo.deq();

	r[0] <= sample;
	for (Integer i = 0; i < 7; i = i + 1) begin
		r[i + 1] <= r[i];
	end

	FixedPoint#(16, 16) accumulate = c[0] * fromInt(sample);
	for (Integer i = 0; i < 8; i = i + 1) begin
		accumulate = accumulate + c[i + 1] * fromInt(r[i]);
	end
	
	outfifo.enq(fxptGetInt(accumulate));
    endrule

    method Action putSampleInput(Sample in);
        infifo.enq(in);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        outfifo.deq();
        return outfifo.first();
    endmethod
endmodule

