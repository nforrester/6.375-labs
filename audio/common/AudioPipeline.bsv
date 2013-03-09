
import ClientServer::*;
import GetPut::*;

import AudioProcessorTypes::*;
import Chunker::*;
import FFT::*;
import FIRFilter::*;
import Splitter::*;
import FilterCoefficients::*;
import FixedPoint::*;
import OverSampler::*;
import Overlayer::*;
import PitchAdjust::*;

import Vector::*;

interface SettableAudioProcessor#(numeric type isize, numeric type fsize);
	interface AudioProcessor auProc;
	interface Put#(FixedPoint#(isize, fsize)) setfactor;
endinterface

module [Module] mkAudioPipeline(SettableAudioProcessor#(16, 16));

    AudioProcessor fir <- mkApFIRFilter();
    Chunker#(2, Sample) chunker <- mkChunker();
    OverSampler#(2, FFT_POINTS, Sample) overSampler <- mkOverSampler(replicate(0));
    FFT#(FFT_POINTS, FixedPoint#(16,16)) fft <- mkApFFT();
    ToMP#(FFT_POINTS, 16, 16, 16) toMP <- mkApToMP();
    SettablePitchAdjust#(FFT_POINTS, 16, 16, 16) pitchAdjust <- mkApPitchAdjust();
    FromMP#(FFT_POINTS, 16, 16, 16) fromMP <- mkApFromMP();
    FFT#(FFT_POINTS, FixedPoint#(16,16)) ifft <- mkApIFFT();
    Overlayer#(FFT_POINTS, 2, Sample) overlayer <- mkOverlayer(replicate(0));
    Splitter#(2, Sample) splitter <- mkSplitter();

    rule fir_to_chunker (True);
        let x <- fir.getSampleOutput();
        chunker.request.put(x);
    endrule

    rule chunker_to_overSampler (True);
        let x <- chunker.response.get();
	overSampler.request.put(x);
    endrule

    rule overSampler_to_fft (True);
        let x <- overSampler.response.get();
        fft.request.put(map(tocmplx, x));
    endrule

    rule fft_to_toMP (True);
        let x <- fft.response.get();
        toMP.request.put(x);
    endrule

    rule toMP_to_pitchAdjust (True);
        let x <- toMP.response.get();
        pitchAdjust.adjust.request.put(x);
    endrule

    rule pitchAdjust_to_fromMP (True);
        let x <- pitchAdjust.adjust.response.get();
        fromMP.request.put(x);
    endrule

    rule fromMP_to_ifft (True);
        let x <- fromMP.response.get();
        ifft.request.put(x);
    endrule

    rule ifft_to_overlayer (True);
        let x <- ifft.response.get();
        overlayer.request.put(map(frcmplx, x));
    endrule
    
    rule overlayer_to_splitter (True);
        let x <- overlayer.response.get();
        splitter.request.put(x);
    endrule
    
    interface AudioProcessor auProc;
	    method Action putSampleInput(Sample x);
		fir.putSampleInput(x);
	    endmethod

	    method ActionValue#(Sample) getSampleOutput();
		let x <- splitter.response.get();
		return x;
	    endmethod
    endinterface

    interface Put setfactor = pitchAdjust.setfactor;
endmodule

(* synthesize *)
module mkApFFT(FFT#(FFT_POINTS, FixedPoint#(16,16)));
	FFT#(FFT_POINTS, FixedPoint#(16,16)) fft <- mkFFT();
	return fft;
endmodule

(* synthesize *)
module mkApIFFT(FFT#(FFT_POINTS, FixedPoint#(16,16)));
	FFT#(FFT_POINTS, FixedPoint#(16,16)) ifft <- mkIFFT();
	return ifft;
endmodule

(* synthesize *)
module mkApPitchAdjust(SettablePitchAdjust#(FFT_POINTS, 16, 16, 16));
	SettablePitchAdjust#(FFT_POINTS, 16, 16, 16) pitchAdjust <- mkPitchAdjust(2);
	return pitchAdjust;
endmodule

(* synthesize *)
module mkApFIRFilter(AudioProcessor);
	AudioProcessor fir <- mkFIRFilter(c);
	return fir;
endmodule

(* synthesize *)
module mkApToMP(ToMP#(FFT_POINTS, 16, 16, 16));
	ToMP#(FFT_POINTS, 16, 16, 16) toMP <- mkToMP();
	return toMP;
endmodule

(* synthesize *)
module mkApFromMP(FromMP#(FFT_POINTS, 16, 16, 16));
	FromMP#(FFT_POINTS, 16, 16, 16) fromMP <- mkFromMP();
	return fromMP;
endmodule
