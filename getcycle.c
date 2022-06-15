#include <stdio.h>
#include <stdlib.h>
#include <string.h>

u_int16_t		swap(u_int16_t a) {
	return (a >> 8) | (a << 8);
}

int				main() {
	int			wait = 0;
	int			pointer = 0;
	u_int8_t	size, mode;
	u_int16_t	addr, value;
	char		s[46];
	while(fgets(s, 46, stdin) != NULL) {
		sscanf(s, ":%02hhX%04hX%02hhX", &size, &addr, &mode);
		if(mode != 0 || addr == 0)
			continue;
		for(size_t i = pointer; i < size * 2 ; i += 12) {
			sscanf(&s[9 + i], "%04hX", &value);
			if(value == 0)
				break;
			wait += swap(value);
		}
		pointer = (12 - (size * 2  - pointer) % 12) % 12;
	}
	printf("%d\n", wait);
	return 0;
}
