/**
 * \brief OBPMark common functions for timing
 * \file obpmark_time.h
 * \author David Steenari
 * 
 * To enable timing measurements, define "OBPMARK_TIMING 1". 
 * To enable verbose timing measurements, define "OBPMARK_TIMING 2". 
 */
#ifndef OBPMARK_TIME_H_
#define OBPMARK_TIME_H_

// FIXME temporary placement
#define OBPMARK_TIMING 2

/* Stdlib implemenation, replace if other timing library is to be used */
#if (OBPMARK_TIMING > 0)

    #if defined (__MICROBLAZE__) || defined (__riscv)
	    //MB_StartAxiTimer(); -> in main
	    #include "runtime.h"
        #define T_START(t_timer) t_timer = get_mcycle()
        #define T_STOP(t_timer) t_timer = get_mcycle() - t_timer
        #define T_TO_SEC(t_timer) ((float)t_timer/COUNTS_PER_SECOND)

    #else
        #include <time.h>
        //#define T_INIT(t_timer) time_t t_timer
        #define T_START(t_timer) t_timer = clock()
        #define T_STOP(t_timer) t_timer = (clock() - t_timer)
        #define T_TO_SEC(t_timer) ((float)t_timer/CLOCKS_PER_SEC)
    #endif

	#if (OBPMARK_TIMING > 1)
		#define T_START_VERBOSE(t_timer) T_START(t_timer)
		#define T_STOP_VERBOSE(t_timer)	T_STOP(t_timer) 
	#else
		#define T_START_VERBOSE(t_timer)
		#define T_STOP_VERBOSE(t_timer)
	#endif
#else
	#define T_START(t_timer)
	#define T_STOP(t_timer)
#endif

#endif // OBPMARK_TIME_H_
