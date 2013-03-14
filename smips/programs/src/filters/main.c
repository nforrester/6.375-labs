// *************************************************************************
// filters filter bencmark
// -------------------------------------------------------------------------
// $Id: filters_main.c,v 1.2 2006-02-20 23:03:57 pellauer Exp $
//
// This benchmark tests the software filters implemenation. The
// input data (and reference data) should be generated using the
// filters_gendata.pl perl script and dumped to a file named
// dataset1.h
//--------------------------------------------------------------------------
// Input/Reference Data

#include "dataset1.h"

// *************************************************************************
// Filter implementations
// For various reasons, the compiler is happier when all these functions are
// in the same .c file.


// multiply function
int multiply( int x, int y )
{

 int i;
 int result = 0;

 for (i = 0; i < 32; i++) 
 {
   if ((x & 0x1) == 1)
     result = result + y;
       
   x = x >> 1;
   y = y << 1;
 } 
 
 return result;

}


// divide function
int divide( int x, int y )
{
 int i, y2 = y, tmp = 1;
 int result = 1;
 
 while (x > y2)
 {
   y2 = y2 << 1;
   tmp = tmp << 1;
 }

 while (x > y)
 {
   if (x > y2)
   {
     x = x - y2;
     result = result + tmp;
   }
   tmp = tmp >> 1;
   y2 = y2 >> 1;
 }

 return result;

}

void remove_red(int pmap_r[DATA_SIZE][DATA_SIZE], int pmap_g[DATA_SIZE][DATA_SIZE], int pmap_b[DATA_SIZE][DATA_SIZE],
                int res_r[DATA_SIZE][DATA_SIZE], int res_g[DATA_SIZE][DATA_SIZE], int res_b[DATA_SIZE][DATA_SIZE])
{
  int i, j;
  printStr("called remove_red\n");
  for (i = 0; i < DATA_SIZE; i++)
  {
    for (j = 0; j < DATA_SIZE; j++)
    {
      res_r[i][j] = 0;
      res_g[i][j] = pmap_g[i][j];
      res_b[i][j] = pmap_b[i][j];
    }
  }

  printStr("exiting remove_red\n");
}

void sharpen(int pmap_r[DATA_SIZE][DATA_SIZE], int pmap_g[DATA_SIZE][DATA_SIZE], int pmap_b[DATA_SIZE][DATA_SIZE],
             int res_r[DATA_SIZE][DATA_SIZE], int res_g[DATA_SIZE][DATA_SIZE], int res_b[DATA_SIZE][DATA_SIZE])
{
  int i, j, k, l, x, y;
  
  int sharpen_filter[3][3]={{0,-1,0},{-1,5,-1},{0,-1,0}};
  
  int sum_r = 0;
  int sum_g = 0;
  int sum_b = 0;
  
  printStr("called sharpen\n");

  for (i = 0; i < DATA_SIZE; i++) 
  {
    res_r[0][i] = pmap_r[0][i]; 
    res_g[0][i] = pmap_g[0][i]; 
    res_b[0][i] = pmap_b[0][i]; 
    res_r[DATA_SIZE-1][i] = pmap_r[DATA_SIZE-1][i]; 
    res_g[DATA_SIZE-1][i] = pmap_g[DATA_SIZE-1][i]; 
    res_b[DATA_SIZE-1][i] = pmap_b[DATA_SIZE-1][i]; 
    
    res_r[i][0] = pmap_r[i][0]; 
    res_g[i][0] = pmap_g[i][0]; 
    res_b[i][0] = pmap_b[i][0]; 
    res_r[i][DATA_SIZE-1] = pmap_r[i][DATA_SIZE-1]; 
    res_g[i][DATA_SIZE-1] = pmap_g[i][DATA_SIZE-1]; 
    res_b[i][DATA_SIZE-1] = pmap_b[i][DATA_SIZE-1]; 
    
  }
  
  for (i = 1; i < DATA_SIZE; i++)
  {
    for (j = 1; j < DATA_SIZE; j++)
    {
      sum_r = 0;
      sum_g = 0;
      sum_b = 0;
      
      for (k = 0; k < 3; k++)
      {
	for (l = 0; l < 3; l++)
	{
	  x = i + k - 1;
	  y = j + l - 1;
          sum_r = sum_r + multiply(pmap_r[x][y], sharpen_filter[k][l]);
          sum_g = sum_g + multiply(pmap_g[x][y], sharpen_filter[k][l]);
          sum_b = sum_b + multiply(pmap_b[x][y], sharpen_filter[k][l]);
	}
      }
      
      res_r[i][j] = (sum_r > 255)? 255 : (sum_r >= 0)? sum_r : 0;
      res_g[i][j] = (sum_g > 255)? 255 : (sum_g >= 0)? sum_g : 0;
      res_b[i][j] = (sum_b > 255)? 255 : (sum_b >= 0)? sum_b : 0;
    
    }
  }
  printStr("exiting sharpen\n");
}

//--------------------------------------------------------------------------
// Helper functions

int verify(int test[DATA_SIZE][DATA_SIZE], int correct[DATA_SIZE][DATA_SIZE])
{
  int i, j;
  for ( i = 0; i < DATA_SIZE; i++ ) {
    for ( j = 0; j < DATA_SIZE; j++ ) {
      if ( test[i][j] != correct[i][j] ) {
	return 2;
      }
    }
  }
  return 1;
}

//--------------------------------------------------------------------------
// Main

int main( int argc, char* argv[] )
{
  int i;
  int resr, resg, resb;
  int results_data_r[DATA_SIZE][DATA_SIZE];
  int results_data_g[DATA_SIZE][DATA_SIZE];
  int results_data_b[DATA_SIZE][DATA_SIZE];
  int cycles, insts;
  cycles = getTime();
  insts = getInsts();
  for (i = 0; i < DATA_SIZE; i++)
  {
    sharpen( input_data_r, input_data_g, input_data_b,
                results_data_r, results_data_g, results_data_b);
  }
  cycles = getTime() - cycles;
  insts = getInsts() - insts;
  printStr("Cycles = "); printInt(cycles); printChar('\n');
  printStr("Insts  = "); printInt(insts); printChar('\n');
  
  // Check the results

  resr = verify(results_data_r, verify_data_r);
  resg = verify(results_data_g, verify_data_g);
  resb = verify(results_data_b, verify_data_b);

  return (resr != 1 || resg != 1 || resb != 1);
}
