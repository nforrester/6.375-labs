import FIFO::*;
import FixedPoint::*;
import Vector::*;
import Counter::*;

import AudioProcessorTypes::*;
import Multiplier::*;

module mkFIRFilter(Vector#(nTapsP1, FixedPoint#(16, 16)) coeffs, AudioProcessor ifc);
	FIFO#(Sample) infifo <- mkFIFO();
	FIFO#(Sample) outfifo <- mkFIFO();

	Vector#(TSub#(nTapsP1, 1), Reg#(Sample)) r <- replicateM(mkReg(0));

	Vector#(nTapsP1, Multiplier) mult <- replicateM(mkMultiplier());

	rule pipeIn (True);
		//$display("in sample: %h", infifo.first());
		Sample sample = infifo.first();
		infifo.deq();

		r[0] <= sample;
		for (Integer i = 0; i < valueof(TSub#(nTapsP1, 2)); i = i + 1) begin
			r[i + 1] <= r[i];
		end

		mult[0].putOperands(coeffs[0], sample);
		for (Integer i = 0; i < valueof(TSub#(nTapsP1, 1)); i = i + 1) begin
			mult[i + 1].putOperands(coeffs[i + 1], r[i]);
		end
	endrule

	rule pipeOut (True);
		Vector#(nTapsP1, FixedPoint#(16, 16)) results;
		for (Integer i = 0; i < valueof(nTapsP1); i = i + 1) begin
			results[i] <- mult[i].getResult();
		end

		FixedPoint#(16, 16) accumulate = 0;
		for (Integer i = 0; i < valueof(nTapsP1); i = i + 1) begin
			accumulate = accumulate + results[i];
		end
	
		//$display("out sample: %h", accumulate);
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
