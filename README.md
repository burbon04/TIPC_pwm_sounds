# PWM digitized sound on TIPC

PWM-based digitized audio appeared in the late 1980s, around the time PC sound cards started to emerge.  
Of course, the sound quality was much lower, but so was the price tag: you didn't need any extra hardware. 

The Texas Instruments Professional Computer (TIPC) is a 5 MHz 8088-based machine, to quote Wikipedia:  

> The Texas Instruments Professional Computer (abbreviated TIPC or TI PC) is a personal computer produced by Texas Instruments (TI) that was released on January 31, 1983, and discontinued around 1985; the TIPC is a desktop PC and the Texas Instruments Professional Portable Computer (TIPPC) is a portable version that is fully compatible with it. Both computers were most often used by white-collar information workers and professionals that needed to gather, manipulate and transmit information.

It features a customized version of MS-DOS, which was mostly compatible with IBM PC MS-DOS. However, the system as a whole was not fully IBM PC-compatible, as its hardware architecture differed in some respects. Software that used more than just the basic MS-DOS functions therefore had to be specifically adapted for that platform.

But since the system's mainboard incorporates the same Intel 8253 Programmable Interval Timer (PIT) as on IBM, I attempted to get PWM-based digitized audio playback working on that platform. There's a neat, highly optimized IBM-PC version available along with source code: pcs_pwm.asm from Bumbershoot (available on Github), so I took that as a starting point.

**PIT channel differences**

| channel | IBM | TIPC |
| --- | --- | --- |
| 0 | system timer | speaker |
| 1 | | system timer |
| 2 | speaker | |

**PIT I/O port differences**
| port | IBM | TIPC |
| --- | --- | --- |
| ch 0 | 40h | 14h |
| ch 1 | 41h | 15h |
| ch 2 | 42h | 16h |
| cmd   | 43h | 17h |

**PIC IRQ port differences**
| port | IBM | TIPC |
| --- | --- | --- |
| cmd | 20h | 18h |

Further details can be found in the available TIPC System ROM 1.23 Listing.

**NOTES**

The IBM PC version employs a 16KHz carrier frequency and specifies a minimum CPU clock frequency of 16 MHz... more than 3 times the clock we have on TIPC. 
In addition, listening tests showed that a carrier frequency of at least 20 kHz is required on the TIPC.
Otherwise, a highly noticeable high-pitched whine becomes audible in the background. It looked like a very tight fit from the beginning.

But it turned out that 20 kHz was achievable (while fully saturating the 8088 CPU) by using pre-optimized, bitrate adjusted PWM data patterns.
As soon as we enter the ISR (interrupt service routine), we put on blinders and just loop over all the PCM data as fast as we can.

**Do not attempt to run this version on IBM compatible systems, it won't work as different I/O ports and memory patterns are used!**

For a set of .exe files including audio samples see the AtariAge forums thread "TI professional computer" (in TI-99/4A Computers -> TI-99/4A Development).


