import ClientServer::*;
import FIFO::*;
import GetPut::*;
import FixedPoint::*;
import Cordic::*;

import Vector::*;

import Complex::*;
import ComplexMP::*;


typedef Server#(
	Vector#(nbins, ComplexMP#(isize, fsize, psize)),
	Vector#(nbins, ComplexMP#(isize, fsize, psize))
) PitchAdjust#(numeric type nbins, numeric type isize, numeric type fsize, numeric type psize);


// s - the amount each window is shifted from the previous window.
//
// factor - the amount to adjust the pitch.
//  1.0 makes no change. 2.0 goes up an octave, 0.5 goes down an octave, etc...
module mkPitchAdjust(Integer s, FixedPoint#(isize, fsize) factor, PitchAdjust#(nbins, isize, fsize, psize) ifc) provisos (Add#(a__, TAdd#(3, TLog#(nbins)), isize), Add#(b__, psize, isize), Add#(c__, psize, TAdd#(isize, isize)));
	FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) inputFIFO  <- mkFIFO();
	FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) outputFIFO <- mkFIFO();

	Vector#(nbins, Reg#(Phase#(psize))) inPhases  <- replicateM(mkReg(0));
	Vector#(nbins, Reg#(Phase#(psize))) outPhases <- replicateM(mkReg(0));

	rule pitchAdjust(True);
		let in = inputFIFO.first();
		inputFIFO.deq();

		Vector#(nbins, ComplexMP#(isize, fsize, psize)) out = replicate(cmplxmp(0, 0));

		for(Integer i = 0; i < valueof(nbins); i = i + 1) begin
			let phase = phaseof(in[i]);
			let mag = in[i].magnitude;
			
			let dphase = phase - inPhases[i];
			inPhases[i] <= phase;

			Int#(TAdd#(3, TLog#(nbins))) bin = truncate(fxptGetInt(fromInteger(i) * factor));
			Int#(TAdd#(3, TLog#(nbins))) nbin = truncate(fxptGetInt(fromInteger(i + 1) * factor));

			if (nbin != bin && bin >= 0 && bin < fromInteger(valueof(nbins))) begin
				FixedPoint#(isize, fsize) dphaseFxpt = fromInt(dphase);
				let multiplied = fxptMult(dphaseFxpt, factor);
				let multInt = fxptGetInt(multiplied);
				let shifted = truncate(multInt);
				outPhases[bin] <= outPhases[bin] + shifted;
				out[bin] = cmplxmp(mag, outPhases[bin] + shifted);
			end
		end

		outputFIFO.enq(out);
	endrule

	interface Put request;
		method Action put(Vector#(nbins, ComplexMP#(isize, fsize, psize)) x);
			inputFIFO.enq(x);
		endmethod
	endinterface

	interface Get response = toGet(outputFIFO);
endmodule

typedef Server#( Vector#(len, Complex#(FixedPoint#(isize, fsize)))
               , Vector#(len, ComplexMP#(isize, fsize, psize))
               ) ToMP#(numeric type len, numeric type isize, numeric type fsize, numeric type psize);

module mkToMP(ToMP#(len, isize, fsize, psize));
	FIFO#(Vector#(len, Complex#(FixedPoint#(isize, fsize)))) inputFIFO  <- mkFIFO();
	FIFO#(Vector#(len, ComplexMP#(isize, fsize, psize))) outputFIFO     <- mkFIFO();

	Vector#(len, ToMagnitudePhase#(isize, fsize, psize)) fs <- replicateM(mkCordicToMagnitudePhase());

	rule mapIn(True);
		let xs = inputFIFO.first();
		inputFIFO.deq();

		for (Integer i = 0; i < valueof(len); i = i + 1) begin
			fs[i].request.put(xs[i]);
		end
	endrule

	rule mapOut(True);
		Vector#(len, ComplexMP#(isize, fsize, psize)) ys;
		for (Integer i = 0; i < valueof(len); i = i + 1) begin
			ys[i] <- fs[i].response.get();
		end
		outputFIFO.enq(ys);
	endrule

	interface Put request;
		method Action put(Vector#(len, Complex#(FixedPoint#(isize, fsize))) xs);
			inputFIFO.enq(xs);
		endmethod
	endinterface

	interface Get response = toGet(outputFIFO);
endmodule

typedef Server#( Vector#(len, ComplexMP#(isize, fsize, psize))
               , Vector#(len, Complex#(FixedPoint#(isize, fsize)))
               ) FromMP#(numeric type len, numeric type isize, numeric type fsize, numeric type psize);

module mkFromMP(FromMP#(len, isize, fsize, psize));
	FIFO#(Vector#(len, ComplexMP#(isize, fsize, psize))) inputFIFO      <- mkFIFO();
	FIFO#(Vector#(len, Complex#(FixedPoint#(isize, fsize)))) outputFIFO <- mkFIFO();

	Vector#(len, FromMagnitudePhase#(isize, fsize, psize)) fs <- replicateM(mkCordicFromMagnitudePhase());

	rule mapIn(True);
		let xs = inputFIFO.first();
		inputFIFO.deq();

		for (Integer i = 0; i < valueof(len); i = i + 1) begin
			fs[i].request.put(xs[i]);
		end
	endrule

	rule mapOut(True);
		Vector#(len, Complex#(FixedPoint#(isize, fsize))) ys;
		for (Integer i = 0; i < valueof(len); i = i + 1) begin
			ys[i] <- fs[i].response.get();
		end
		outputFIFO.enq(ys);
	endrule

	interface Put request;
		method Action put(Vector#(len, ComplexMP#(isize, fsize, psize)) xs);
			inputFIFO.enq(xs);
		endmethod
	endinterface

	interface Get response = toGet(outputFIFO);
endmodule
