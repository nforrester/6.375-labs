import ClientServer::*;
import Complex::*;
import FIFO::*;
import GetPut::*;
import Real::*;
import Vector::*;

typedef Server#(
    Vector#(fft_points, Complex#(complex)),
    Vector#(fft_points, Complex#(complex))
) FFT#(numeric type fft_points, type complex);

// Get the appropriate twiddle factor for the given stage and index.
// This computes the twiddle factor statically.
function Complex#(complex) getTwiddle(Integer stage, Integer index, Integer points) provisos (RealLiteral#(complex));
    Integer i = ((2*index)/(2 ** (log2(points)-stage))) * (2 ** (log2(points)-stage));
    return cmplx(fromReal(cos(fromInteger(i)*pi/fromInteger(points))),
                 fromReal(-1*sin(fromInteger(i)*pi/fromInteger(points))));
endfunction

// Generate a table of all the needed twiddle factors.
// The table can be used for looking up a twiddle factor dynamically.
typedef Vector#(TLog#(fft_points), Vector#(TDiv#(fft_points, 2), Complex#(complex))) TwiddleTable#(type fft_points, type complex);
function TwiddleTable#(fft_points, complex) genTwiddles() provisos (RealLiteral#(complex));
    TwiddleTable#(fft_points, complex) twids = newVector;
    for (Integer s = 0; s < valueof(TLog#(fft_points)); s = s+1) begin
        for (Integer i = 0; i < valueof(TDiv#(fft_points, 2)); i = i+1) begin
            twids[s][i] = getTwiddle(s, i, valueof(fft_points));
        end
    end
    return twids;
endfunction

// Given the destination location and the number of points in the fft, return
// the source index for the permutation.
function Integer permute(Integer dst, Integer points);
    Integer src = ?;
    if (dst < points/2) begin
        src = dst*2;
    end else begin
        src = (dst - points/2)*2 + 1;
    end
    return src;
endfunction

// Reorder the given vector by swapping words at positions
// corresponding to the bit-reversal of their indices.
// The reordering can be done either as as the
// first or last phase of the FFT transformation.
function Vector#(fft_points, Complex#(complex)) bitReverse(Vector#(fft_points,Complex#(complex)) inVector);
    Vector#(fft_points, Complex#(complex)) outVector = newVector();
    for(Integer i = 0; i < valueof(fft_points); i = i+1) begin
        Bit#(TLog#(fft_points)) reversal = reverseBits(fromInteger(i));
        outVector[reversal] = inVector[i];
    end
    return outVector;
endfunction

// 2-way Butterfly
function Vector#(2, Complex#(complex)) bfly2(Vector#(2, Complex#(complex)) t, Complex#(complex) k) provisos (Arith#(Complex#(complex)));
    Complex#(complex) m = t[1] * k;

    Vector#(2, Complex#(complex)) z = newVector();
    z[0] = t[0] + m;
    z[1] = t[0] - m;

    return z;
endfunction

// Perform a single stage of the FFT, consisting of butterflys and a single
// permutation.
// We pass the table of twiddles as an argument so we can look those up
// dynamically if need be.
function Vector#(fft_points, Complex#(complex)) stage_ft(TwiddleTable#(fft_points, complex) twiddles, Bit#(TLog#(TLog#(fft_points))) stage, Vector#(fft_points, Complex#(complex)) stage_in) provisos(Add#(2, a__, fft_points), Arith#(complex));
    Vector#(fft_points, Complex#(complex)) stage_temp = newVector();
    for(Integer i = 0; i < (valueof(fft_points)/2); i = i+1) begin
        Integer idx = i * 2;
        let twid = twiddles[stage][i];
        let y = bfly2(takeAt(idx, stage_in), twid);

        stage_temp[idx]   = y[0];
        stage_temp[idx+1] = y[1];
    end

    Vector#(fft_points, Complex#(complex)) stage_out = newVector();
    for (Integer i = 0; i < valueof(fft_points); i = i+1) begin
        stage_out[i] = stage_temp[permute(i, valueof(fft_points))];
    end
    return stage_out;
endfunction

module mkCombinationalFFT (FFT#(fft_points, complex)) provisos(Add#(2, a__, fft_points), Arith#(complex), RealLiteral#(complex), Bits#(complex, c__));

  // Statically generate the twiddle factors table.
  TwiddleTable#(fft_points, complex) twiddles = genTwiddles();

  // Define the stage_f function which uses the generated twiddles.
  function Vector#(fft_points, Complex#(complex)) stage_f(Bit#(TLog#(TLog#(fft_points))) stage, Vector#(fft_points, Complex#(complex)) stage_in);
      return stage_ft(twiddles, stage, stage_in);
  endfunction

  FIFO#(Vector#(fft_points, Complex#(complex))) inputFIFO  <- mkFIFO();
  FIFO#(Vector#(fft_points, Complex#(complex))) outputFIFO <- mkFIFO();

  // This rule performs fft using a big mass of combinational logic.
  rule comb_fft;

    Vector#(TAdd#(1, TLog#(fft_points)), Vector#(fft_points, Complex#(complex))) stage_data = newVector();
    stage_data[0] = inputFIFO.first();
    inputFIFO.deq();

    for(Integer stage = 0; stage < valueof(TLog#(fft_points)); stage=stage+1) begin
        stage_data[stage+1] = stage_f(fromInteger(stage), stage_data[stage]);
    end

    outputFIFO.enq(stage_data[valueof(TLog#(fft_points))]);
  endrule

  interface Put request;
    method Action put(Vector#(fft_points, Complex#(complex)) x);
        inputFIFO.enq(bitReverse(x));
    endmethod
  endinterface

  interface Get response = toGet(outputFIFO);

endmodule

// Wrapper around The FFT module we actually want to use
module mkFFT (FFT#(fft_points, complex)) provisos(Add#(2, a__, fft_points), Arith#(complex), RealLiteral#(complex), Bits#(complex, c__));
    let fft <- mkCircularFFT();

    interface Put request = fft.request;
    interface Get response = fft.response;
endmodule

// Inverse FFT, based on the mkFFT module.
// ifft[k] = fft[N-k]/N
module mkIFFT (FFT#(fft_points, complex)) provisos(Add#(2, a__, fft_points), Arith#(complex), RealLiteral#(complex), Bits#(complex, c__), Bitwise#(complex));

    let fft <- mkFFT();
    FIFO#(Vector#(fft_points, Complex#(complex))) outfifo <- mkFIFO();

    Integer n = valueof(fft_points);
    Integer lgn = valueof(TLog#(fft_points));

    function Complex#(complex) scaledown(Complex#(complex) x);
        return cmplx(x.rel >> lgn, x.img >> lgn);
    endfunction

    rule inversify (True);
        let x <- fft.response.get();
        Vector#(fft_points, Complex#(complex)) rx = newVector;

        for (Integer i = 0; i < n; i = i+1) begin
            rx[i] = x[(n - i)%n];
        end
        outfifo.enq(map(scaledown, rx));
    endrule

    interface Put request = fft.request;
    interface Get response = toGet(outfifo);

endmodule






module mkLinearFFT (FFT#(fft_points, complex)) provisos(Add#(2, a__, fft_points), Arith#(complex), RealLiteral#(complex), Bits#(complex, c__));
	// Statically generate the twiddle factors table.
	TwiddleTable#(fft_points, complex) twiddles = genTwiddles();

	Vector#(TAdd#(1, TLog#(fft_points)), FIFO#(Vector#(fft_points, Complex#(complex)))) stageFIFO <- replicateM(mkFIFO());

	Vector#(TLog#(fft_points), FIFO#(Vector#(fft_points /* fft_points/2 would be better*/, Complex#(complex)))) multResults <- replicateM(mkFIFO());

	for(Integer stage = 0; stage < valueof(TLog#(fft_points)); stage = stage + 1) begin
		rule fft_stage_a;
			Vector#(fft_points, Complex#(complex)) stage_temp = newVector();
			Vector#(fft_points /* fft_points/2 would be better*/, Complex#(complex)) m = newVector();
			for(Integer i = 0; i < (valueof(fft_points)/2); i = i+1) begin
				Integer idx = i * 2;
				Complex#(complex) twid = twiddles[fromInteger(stage)][i];
				Vector#(2, Complex#(complex)) t = takeAt(idx, stageFIFO[stage].first());

				m[i] = t[1] * twid;
			end
			multResults[stage].enq(m);
		endrule

		rule fft_stage_b;
			Vector#(fft_points, Complex#(complex)) stage_temp = newVector();
			Vector#(fft_points /* fft_points/2 would be better*/, Complex#(complex)) m = newVector();
			m = multResults[stage].first();
			multResults[stage].deq();
			for(Integer i = 0; i < (valueof(fft_points)/2); i = i+1) begin
				Integer idx = i * 2;
				Vector#(2, Complex#(complex)) t = takeAt(idx, stageFIFO[stage].first());
				stage_temp[idx]   = t[0] + m[i];
				stage_temp[idx+1] = t[0] - m[i];
			end

			Vector#(fft_points, Complex#(complex)) stage_out = newVector();
			for (Integer i = 0; i < valueof(fft_points); i = i+1) begin
				stage_out[i] = stage_temp[permute(i, valueof(fft_points))];
			end

			stageFIFO[stage+1].enq(stage_out);
			stageFIFO[stage].deq();
		endrule
	end

	interface Put request;
		method Action put(Vector#(fft_points, Complex#(complex)) x);
			stageFIFO[0].enq(bitReverse(x));
		endmethod
	endinterface

	interface Get response = toGet(stageFIFO[valueof(TLog#(fft_points))]);
endmodule

module mkCircularFFT (FFT#(fft_points, complex)) provisos(Add#(2, a__, fft_points), Arith#(complex), RealLiteral#(complex), Bits#(complex, c__));
	// Statically generate the twiddle factors table.
	TwiddleTable#(fft_points, complex) twiddles = genTwiddles();

	// Define the stage_f function which uses the generated twiddles.
	function Vector#(fft_points, Complex#(complex)) stage_f(Bit#(TLog#(TLog#(fft_points))) stage, Vector#(fft_points, Complex#(complex)) stage_in);
		return stage_ft(twiddles, stage, stage_in);
	endfunction

	Reg#(Bool) done <- mkReg(True);
	Reg#(Bit#(TLog#(TLog#(fft_points)))) stage <- mkReg(fromInteger(valueof(TLog#(fft_points))));
	Reg#(Vector#(fft_points, Complex#(complex))) sample <- mkRegU();
	FIFO#(Vector#(fft_points, Complex#(complex))) outputFIFO <- mkFIFO();

	rule fft_circular(stage < fromInteger(valueof(TLog#(fft_points))) && !done);
		sample <= stage_f(stage, sample);
		stage <= stage + 1;
	endrule

	rule fft_circular_out(stage == fromInteger(valueof(TLog#(fft_points))) && !done);
		outputFIFO.enq(sample);
		done <= True;
	endrule

	interface Put request;
		method Action put(Vector#(fft_points, Complex#(complex)) x) if (done);
			sample <= bitReverse(x);
			stage <= 0;
			done <= False;
		endmethod
	endinterface

	interface Get response = toGet(outputFIFO);
endmodule
