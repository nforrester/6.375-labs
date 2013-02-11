import FIFO::*;
import FixedPoint::*;
import Vector::*;
import Counter::*;

import AudioProcessorTypes::*;
import FilterCoefficients::*;
import Multiplier::*;

module mkFIRFilter (AudioProcessor);
	FIFO#(Sample) infifo <- mkFIFO();
	FIFO#(Sample) outfifo <- mkFIFO();

	Vector#(8, Reg#(Sample)) r <- replicateM(mkReg(0));

	Vector#(9, Multiplier) mult <- replicateM(mkMultiplier());

	Counter#(32) outputReady <- mkCounter(0);

	rule pipeIn (True);
		$display("in sample: %h", infifo.first());
		Sample sample = infifo.first();
		infifo.deq();

		r[0] <= sample;
		for (Integer i = 0; i < 7; i = i + 1) begin
			r[i + 1] <= r[i];
		end

		mult[0].putOperands(c[0], sample);
		for (Integer i = 0; i < 8; i = i + 1) begin
			mult[i + 1].putOperands(c[i + 1], r[i]);
		end

		outputReady.up();
		$display("Hello");
	endrule

	rule pipeOut (outputReady.value() > 0);
		$display("World!");

		Vector#(9, FixedPoint#(16, 16)) results;
		for (Integer i = 0; i < 9; i = i + 1) begin
			results[i] <- mult[i].getResult();
		end

		FixedPoint#(16, 16) accumulate = 0;
		for (Integer i = 0; i < 9; i = i + 1) begin
			accumulate = accumulate + results[i];
		end
	
		$display("out sample: %h", accumulate);
		outputReady.down();
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

