void __start() {
  int c = main();
  asm volatile( "mtc0 %0, $21"
                : : "r" (c) );
  while(1);
}

