#include <stdio.h>
#include <stdlib.h>

short			last = 0;
int				ct = -2;

unsigned char	dig[0x100];

int				ia = 0;
short			ad[3];

#define arraysiz	16

short			word() {
	int c1 = 0, c2 = 0;
	c1 = fgetc(stdin);
	c2 = fgetc(stdin);
	if(c1 == EOF || c2 == EOF)
		exit(0);
	ct += 2;
	last = ((c2 & 0xFF) << 8) + (c1 & 0xFF);
	return last;
}

void			array() {
	short nb = word();
	if(nb < 0 || nb > arraysiz)
		exit(0);
	ad[ia++] = ct + 0x200;
	printf("Array[%02d]: %04X\n ", nb, ct + 0x200);
	short pos = word();
	short arr[arraysiz];
	for(int i = 0; i != arraysiz; i++) {
		arr[i] = word();
		printf("%c%03d%c ", (ct == (pos & 0xFF) ? '[' : ' '), (unsigned short)arr[i], (ct == (pos & 0xFF) ? ']' : ' '));
	}
	printf("\n");
}
	
int				main() {
	for(int i = 0; i != 0x100; i++)
		dig[i] = '.';
	dig[0x00] = ' ';
	dig[0x02] = '-';
	dig[0x9C] = '[';
	dig[0xF0] = ']';
	dig[0x3E] = 'P';
	dig[0x4E] = 'h';
	dig[0x6E] = 'H';
	dig[0xD6] = 'S';
	dig[0x9C] = 'C';
	dig[0x8C] = 'L';
	dig[0x7C] = 'N';
	dig[0x9E] = 'E';
	dig[0x0A] = 'r';
	dig[0x60] = 'I';
	dig[0x4A] = 'n';
	dig[0x82] = '=';
	dig[0x7E] = 'a';
	dig[0xCE] = 'b';
	dig[0x8A] = 'c';
	dig[0xCA] = 'o';
	dig[0x8E] = 't';
	dig[0xFC] = '0';
	dig[0x60] = '1';
	dig[0xBA] = '2';
	dig[0xF2] = '3';
	dig[0x66] = '4';
	dig[0xD6] = '5';
	dig[0xDE] = '6';
	dig[0x70] = '7';
	dig[0xFE] = '8';
	dig[0xF6] = '9';
	dig[0x7E] = 'A';
	dig[0xCE] = 'B';
	dig[0x9C] = 'C';
	dig[0xEA] = 'D';
	dig[0x9E] = 'E';
	dig[0x1E] = 'F';
	dig[0x10] = '/';
	dig[0x04] = '/';
	dig[0x20] = '/';
	dig[0x08] = '/';
	dig[0x40] = '/';
	dig[0x80] = '/';

	word();
	if((unsigned short)last == 0xFFFF) {
		printf("No dump\n");
		exit(0);
	}
	printf("Status:\t%04X %cH%c %s%s%s%s\n", (unsigned short)last,
		(last & 0x0004 ? 'r' : 'p'),
		(last & 0x0002 ? '-' : '+'),
		(last & 0x1000 ? "/ " : ""),
		(last & 0x2000 ? "FV " : ""),
		(last & 0x4000 ? "IOK" : ""),
		(last & 0x8000 ? "IKO " : "")
	);
	printf("SetP:\t%d\n", word());
	printf("CalV1:\t%d\n", word());
	printf("CalV2:\t%d\n", word());
	printf("CalA:\t%d\n", word());
	printf("DosCnt:\t%d\n", word());
	array();
	array();
	array();
	printf("RefMON:\t%d\n", word());
	printf("RefxHM:\t%d\n", word());
	printf("V1Ref:\t%d\n", word());
	printf("V2Ref:\t%d\n", word());
	short SP = word();
	word();
	printf("- SR:\t\t%c%c%c%c\n",
		(last & 0x0004 ? 'N' : '-'),
		(last & 0x0002 ? 'Z' : '-'),
		(last & 0x0001 ? 'C' : '-'),
		(last & 0x0100 ? 'V' : '-')
	);
	word();
	printf("- R4:\tArg1:\t0x%04X %d\n", (unsigned short)last, last);
	word();
	printf("- R5:\tArg2:\t0x%04X %d %s\n", (unsigned short)last, last, (last == ad[0] ? "H0" : last == ad[1] ? "H1" : last == ad[2] ? "H2" : ""));
	word();
	printf("- R6:\tRes:\t0x%04X %d\n", (unsigned short)last, last);
	word();
	printf("- R7:\tStep:\t0x%04X %d\n", (unsigned short)last, (unsigned short)last);
	word();
	printf("- R8:\tWait:\t0x%04X %d\n", (unsigned short)last, (unsigned short)last);
	word();
	printf("- R9:\tSimP:\t0x%04X\n", (unsigned short)last);
	word();
	printf("- R10:\tTA1E:\t0x%04X %d\n", (unsigned short)last, last);
	word();
	printf("- R11:\tCalR\t0x%04X %d\n", (unsigned short)last, last);
	word();
	printf("- R12:\tMot:\t0x%04X %d\n", (unsigned short)last, (unsigned short)last);
	word();
	printf("- R13:\tEnt:\t0x%04X %d\n", (unsigned short)last, (unsigned short)last);
	word();
	printf("- R14:\tDisp:\t\"%c%s%c%s\"\n", dig[(last >> 8) & 0xFE], (last & 0x100 ? "." : ""), dig[last & 0xFE], (last & 0x001 ? "." : ""));
	word();
	printf("- R15:\tStat:\t%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
		(last & 0x8000 ? "- " : "+ "),
		(last & 0x4000 ? "MCal " : "ACal "),
		(last & 0x0002 ? "Set " : ""),
		(last & 0x0004 ? "Cal " : ""),
		(last & 0x0800 ? "STOP " : ""),
		(last & 0x1000 ? "ABV " : ""),
		(last & 0x0400 ? "END " : ""),
		(last & 0x0200 ? "EFF " : ""),
		(last & 0x0100 ? "ACT " : ""),
		(last & 0x0001 ? "SPD " : ""),
		(last & 0x0008 ? "RAW " : ""),
		(last & 0x0010 ? "LED " : ""),
		(last & 0x0020 ? "NL " : ""),
		(last & 0x0040 ? "VAL " : ""),
		(last & 0x0080 ? "Pr " : ""),
		(last & 0x2000 ? "MUL" : "")
	);
	printf("SimEnt:\t%d\n", word());
	printf("Stack: %04X\n", (unsigned short)SP);
	int start = 0;
	while(word(), ct != 0x100) {
		start |= last != 0;
		if(start)
			printf("%c %04X %s\n", (ct == (SP & 0xFF) ? '*' : ' '), (unsigned short)last, (
				(unsigned short)last >= 0xF200 ? "ROM" : last == ad[0] ? "A0" : last == ad[1] ? "A1" : last == ad[2] ? "A2": ""
			));
	}
	return 0;
}
