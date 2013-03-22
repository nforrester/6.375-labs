#*****************************************************************************
# smipsv1_addiu.S
#-----------------------------------------------------------------------------
# $Id: smipsv1_addiu.S,v 1.1.1.1 2006/02/20 03:53:12 cbatten Exp $
#
#  Test addiu instruction
#       

#include "smipstest.h"
        
TEST_SMIPSRAW

        .text
main:        
        
        # Test: Force a RAW hazard with $\sum{n=1}{30}n$

        addiu $2, $0, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $2, $2, 1
        addiu $4, $0, 30
        bne   $4, $2, fail

        # If we get here then we passed

        addiu $2, $0, 1
        bne   $0, $2, pass
        
fail:          
        addiu $2, $0, 1
        mtc0  $2, $21      
1:      beq   $0, $0, 1b    

pass:           
        mtc0  $0, $21       
1:      beq   $0, $0, 1b    

                            

        

