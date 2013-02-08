import FIFO::*;
import FixedPoint::*;
import Vector::*;

import AudioProcessorTypes::*;
import FilterCoefficients::*;
import Multiplier::*;

module mkFIRFilter (AudioProcessor);
	FIFO#(Sample) infifo <- mkFIFO();
	FIFO#(Sample) outfifo <- mkFIFO();

	Vector#(8, Reg#(Sample)) r <- replicateM(mkReg(0));

	Vector#(9, Multiplier) mult <- replicateM(mkMultiplier());

	Reg#(Bool) outputReady <- mkReg(False);

	rule pipeIn (True);
		$display("in sample: %h", infifo.first());
		Sample sample = infifo.first();
		infifo.deq();

		r[0] <= sample;
		for (Integer i = 0; i < 7; i = i + 1) begin
			r[i + 1] <= r[i];
		end

		mult[0].putOperands(c[0], sample);
		for (Integer i = 0; i < 7; i = i + 1) begin
			mult[i + 1].putOperands(c[i + 1], r[i]);
		end

		outputReady <= True;
		$display("Hello");
	endrule

	rule pipeOut (outputReady);
		$display("World!");
		let results0 <- mult[0].getResult();
		let results1 <- mult[1].getResult();
		let results2 <- mult[2].getResult();
		let results3 <- mult[3].getResult();
		let results4 <- mult[4].getResult();
		let results5 <- mult[5].getResult();
		let results6 <- mult[6].getResult();
		let results7 <- mult[7].getResult();
		let results8 <- mult[8].getResult();

		FixedPoint#(16, 16) accumulate = results0
		                               + results1
		                               + results2
		                               + results3
		                               + results4
		                               + results5
		                               + results6
		                               + results7
		                               + results8;
	
		$display("out sample: %h", accumulate);
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

