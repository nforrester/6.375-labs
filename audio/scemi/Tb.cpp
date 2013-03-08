
#include <iostream>
#include <unistd.h>
#include <cmath>

#include "bsv_scemi.h"
#include "SceMiHeaders.h"
#include "ResetXactor.h"

FILE* outpcm = NULL;

bool indone = false;
long int putcount = 0;
long int gotcount = 0;


void out_cb(void* x, const BitT<16>& res)
{
    if (gotcount < putcount) {
        int a = res.get() & 0xFF;
        int b = (res.get() & 0xFF00) >> 8;

        fputc(a, outpcm);
        fputc(b, outpcm);
        gotcount++;
    } else if (indone && outpcm) {
        fclose(outpcm);
        outpcm = NULL;
    }
}

void runtest(InportProxyT<BitT<16> >& inport)
{
    FILE* inpcm = fopen("in.pcm", "rb");
    if (inpcm == NULL) {
        std::cerr << "couldn't open in.pcm" << std::endl;
        return;
    }

    outpcm = fopen("out.pcm", "wb");
    if (outpcm == NULL) {
        std::cerr << "couldn't open out.pcm" << std::endl;
        return;
    }

    while (outpcm) {
        if (!indone) {
            int a = fgetc(inpcm);
            int b = fgetc(inpcm);

            if (a == -1 || b == -1) {
                indone = true;
                fclose(inpcm);
                inpcm = NULL;
            } else {
                unsigned int data = (0xFF & a) | ((0xFF & b) << 8);
                putcount++;
                inport.sendMessage(BitT<16>(data));
            }
        } else {
            inport.sendMessage(BitT<16>(0));
        }
        sleep(0);
    }
}

int main(int argc, char* argv[])
{
    int sceMiVersion = SceMi::Version( SCEMI_VERSION_STRING );
    SceMiParameters params("scemi.params");
    SceMi *sceMi = SceMi::Init(sceMiVersion, &params);

    // Initialize the SceMi inport
    InportProxyT<BitT<16> > inport ("", "scemi_processor_req_inport", sceMi);

    // Initialize the SceMi outport
    OutportProxyT<BitT<16> > outport ("", "scemi_processor_resp_outport", sceMi);
    outport.setCallBack(out_cb, NULL);

    // Initialize the reset port.
    ResetXactor reset("", "scemi", sceMi);

    ShutdownXactor shutdown("", "scemi_shutdown", sceMi);

    // Service SceMi requests
    SceMiServiceThread *scemi_service_thread = new SceMiServiceThread (sceMi);

    // Reset the dut.
    reset.reset();

    // Send in all the data.
    runtest(inport);

    std::cout << "shutting down..." << std::endl;
    shutdown.blocking_send_finish();
    scemi_service_thread->stop();
    scemi_service_thread->join();
    SceMi::Shutdown(sceMi);
    std::cout << "finished" << std::endl;

    return 0;
}

