import FIFO::*;
import FixedPoint::*;
import Vector::*;
import Counter::*;

import AudioProcessorTypes::*;
import Multiplier::*;

typedef 8 NTaps;
typedef TAdd#(NTaps, 1) NTapsP1;
typedef TSub#(NTaps, 1) NTapsM1;

module mkFIRFilter(Vector#(9, FixedPoint#(16, 16)) coeffs, AudioProcessor ifc);
	FIFO#(Sample) infifo <- mkFIFO();
	FIFO#(Sample) outfifo <- mkFIFO();

	Vector#(NTaps, Reg#(Sample)) r <- replicateM(mkReg(0));

	Vector#(NTapsP1, Multiplier) mult <- replicateM(mkMultiplier());

	rule pipeIn (True);
		//$display("in sample: %h", infifo.first());
		Sample sample = infifo.first();
		infifo.deq();

		r[0] <= sample;
		for (Integer i = 0; i < valueof(NTapsM1); i = i + 1) begin
			r[i + 1] <= r[i];
		end

		mult[0].putOperands(coeffs[0], sample);
		for (Integer i = 0; i < valueof(NTaps); i = i + 1) begin
			mult[i + 1].putOperands(coeffs[i + 1], r[i]);
		end
	endrule

	rule pipeOut (True);
		Vector#(NTapsP1, FixedPoint#(16, 16)) results;
		for (Integer i = 0; i < valueof(NTapsP1); i = i + 1) begin
			results[i] <- mult[i].getResult();
		end

		FixedPoint#(16, 16) accumulate = 0;
		for (Integer i = 0; i < valueof(NTapsP1); i = i + 1) begin
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
