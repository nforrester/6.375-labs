
CC=smips-gcc -B/mit/6.375/tools/smips-gcc/lib/gcc-lib/smips/egcs-2.90.29/ -B/mit/6.375/tools/smips-gcc/bin/ -B/mit/6.375/tools/smips-gcc/smips/bin/ -G 0

benchmarks:=median multiply qsort towers vvadd
assembly:=$(patsubst src/assembly/%.S,%,$(wildcard src/assembly/*.S))

benchmarks_vmh:=$(patsubst %,build/%.bench.vmh,$(benchmarks))
assembly_vmh:=$(patsubst %,build/%.asm.vmh,$(assembly))

all: $(benchmarks_vmh) $(assembly_vmh)

build/filters.bench.exe: src/filters/main.c
build/median.bench.exe: src/median/median.c src/median/median_main.c
build/multiply.bench.exe: src/multiply/multiply.c src/multiply/multiply_main.c
build/print.bench.exe: src/print/main.c
build/qsort.bench.exe: src/qsort/qsort_main.c
build/towers.bench.exe: src/towers/towers_main.c
build/vvadd.bench.exe: src/vvadd/vvadd_main.c

build/smipsv1_addiu.asm.exe:       src/assembly/smipsv1_addiu.S
build/smipsv1_bne.asm.exe:         src/assembly/smipsv1_bne.S
build/smipsv1_lw.asm.exe:          src/assembly/smipsv1_lw.S
build/smipsv1_simple.asm.exe:      src/assembly/smipsv1_simple.S
build/smipsv1_sw.asm.exe:          src/assembly/smipsv1_sw.S
build/smipsv2_addiu.asm.exe:       src/assembly/smipsv2_addiu.S
build/smipsv2_addu.asm.exe:        src/assembly/smipsv2_addu.S
build/smipsv2_andi.asm.exe:        src/assembly/smipsv2_andi.S
build/smipsv2_and.asm.exe:         src/assembly/smipsv2_and.S
build/smipsv2_beq.asm.exe:         src/assembly/smipsv2_beq.S
build/smipsv2_bgez.asm.exe:        src/assembly/smipsv2_bgez.S
build/smipsv2_bgtz.asm.exe:        src/assembly/smipsv2_bgtz.S
build/smipsv2_blez.asm.exe:        src/assembly/smipsv2_blez.S
build/smipsv2_bltz.asm.exe:        src/assembly/smipsv2_bltz.S
build/smipsv2_bne.asm.exe:         src/assembly/smipsv2_bne.S
build/smipsv2_jalr.asm.exe:        src/assembly/smipsv2_jalr.S
build/smipsv2_jal.asm.exe:         src/assembly/smipsv2_jal.S
build/smipsv2_jr.asm.exe:          src/assembly/smipsv2_jr.S
build/smipsv2_j.asm.exe:           src/assembly/smipsv2_j.S
build/smipsv2_lui.asm.exe:         src/assembly/smipsv2_lui.S
build/smipsv2_lw.asm.exe:          src/assembly/smipsv2_lw.S
build/smipsv2_nor.asm.exe:         src/assembly/smipsv2_nor.S
build/smipsv2_ori.asm.exe:         src/assembly/smipsv2_ori.S
build/smipsv2_or.asm.exe:          src/assembly/smipsv2_or.S
build/smipsv2_simple.asm.exe:      src/assembly/smipsv2_simple.S
build/smipsv2_sll.asm.exe:         src/assembly/smipsv2_sll.S
build/smipsv2_sllv.asm.exe:        src/assembly/smipsv2_sllv.S
build/smipsv2_slti.asm.exe:        src/assembly/smipsv2_slti.S
build/smipsv2_sltiu.asm.exe:       src/assembly/smipsv2_sltiu.S
build/smipsv2_slt.asm.exe:         src/assembly/smipsv2_slt.S
build/smipsv2_sltu.asm.exe:        src/assembly/smipsv2_sltu.S
build/smipsv2_sra.asm.exe:         src/assembly/smipsv2_sra.S
build/smipsv2_srav.asm.exe:        src/assembly/smipsv2_srav.S
build/smipsv2_srl.asm.exe:         src/assembly/smipsv2_srl.S
build/smipsv2_srlv.asm.exe:        src/assembly/smipsv2_srlv.S
build/smipsv2_subu.asm.exe:        src/assembly/smipsv2_subu.S
build/smipsv2_sw.asm.exe:          src/assembly/smipsv2_sw.S
build/smipsv2_xori.asm.exe:        src/assembly/smipsv2_xori.S
build/smipsv2_xor.asm.exe:         src/assembly/smipsv2_xor.S

%.exe:
	mkdir -p build
	$(CC) -static -O2 -nostdlib -nostartfiles -Wa,-O0 -Wl,-Ttext=0x1000,-e__start lib/start.c lib/print.c lib/cop.c $^ -o $@

%.dump: %.exe
	smips-objdump --disassemble-all --disassemble-zeroes $< > $@

%.vmh: %.dump
	objdump2vmh.pl $< $@

clean:
	-rm build/*


