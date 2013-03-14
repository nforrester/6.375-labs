
#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>

#include "bsv_scemi.h"
#include "SceMiHeaders.h"
#include "ResetXactor.h"


// Initialize the memories from the given vmh file.
bool mem_init(const char *filename, InportProxyT<MemInit>& imem, InportProxyT<MemInit>& dmem)
{
    char *line;
    size_t len = 0;
    int read;

    FILE *file = fopen(filename, "r");

    if (file == NULL)
    {
        fprintf(stderr, "could not open VMH file %s.\n", filename);
        return false;
    }

    uint32_t addr = 0;
    while ((read = getline(&line, &len, file)) != -1) {
        if (read != 0) {
            if (line[0] == '@') {
                addr = strtoul(&line[1], NULL, 16);
            } else {
                uint32_t data = strtoul(line, NULL, 16);

                MemInit msg;
                msg.the_tag = MemInit::tag_InitLoad;
                msg.m_InitLoad.m_addr = addr;
                msg.m_InitLoad.m_data = data;
                imem.sendMessage(msg);
                dmem.sendMessage(msg);

                addr++;
            }
        }
    }

    free(line);
    fclose(file);

    MemInit msg;
    msg.the_tag = MemInit::tag_InitDone;
    imem.sendMessage(msg);
    dmem.sendMessage(msg);
    return true;
}

int main(int argc, char* argv[])
{
    if (argc < 2) {
        fprintf(stderr, "usage: TestDriver <vmh-file>\n");
        return 1;
    }
    char* vmh = argv[1];

    int sceMiVersion = SceMi::Version( SCEMI_VERSION_STRING );
    SceMiParameters params("scemi.params");
    SceMi *sceMi = SceMi::Init(sceMiVersion, &params);

    // Initialize the SceMi ports
    InportProxyT<MemInit> imem("", "scemi_imem_inport", sceMi);
    InportProxyT<MemInit> dmem("", "scemi_dmem_inport", sceMi);
    OutportQueueT<ToHost> tohost("", "scemi_tohost_get_outport", sceMi);
    InportProxyT<FromHost> fromhost("", "scemi_fromhost_put_inport", sceMi);
    ResetXactor reset("", "scemi", sceMi);
    ShutdownXactor shutdown("", "scemi_shutdown", sceMi);

    // Service SceMi requests
    SceMiServiceThread *scemi_service_thread = new SceMiServiceThread(sceMi);

    // Reset the dut.
    reset.reset();

    // Initialize the memories.
    if (!mem_init(vmh, imem, dmem)) {
        fprintf(stderr, "Failed to load memory\n");
        std::cout << "shutting down..." << std::endl;
        shutdown.blocking_send_finish();
        scemi_service_thread->stop();
        scemi_service_thread->join();
        SceMi::Shutdown(sceMi);
        std::cout << "finished" << std::endl;
        return 1;
    }

    // Start the core
    fromhost.sendMessage(0x1000);

    // Handle tohost requests.
    while (true) {
        ToHost msg = tohost.getMessage();
        uint32_t idx = msg.m_tpl_1;
        uint32_t data = msg.m_tpl_2;

        if (idx == 18) {
            fprintf(stderr, "%i", data);
        } else if (idx == 19) {
            fprintf(stderr, "%c", data);
        } else if (idx == 21) {
            if(data == 0) {
              fprintf(stderr, "PASSED\n");
            } else {
              fprintf(stderr, "FAILED %d\n", data);
            }
            break;
        }
    }

    shutdown.blocking_send_finish();
    scemi_service_thread->stop();
    scemi_service_thread->join();
    SceMi::Shutdown(sceMi);

    return 0;
}

