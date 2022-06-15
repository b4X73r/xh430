#include <stdio.h>
#include <stdlib.h>
#include <string.h>

u_int16_t		swap(u_int16_t a) {
	return (a >> 8) | (a << 8);
}
u_int8_t		chksum(const char * const s) {
	u_int8_t	res = 0;
	char		r[3];
	for(size_t i = 0; i < strlen(s); i += 2) {
		strncpy(r, &s[i], 2);
		res -= strtoul(r, NULL, 16);
	}
	return res;
}

int				main() {
	char		mode;
	char		s[33];
	u_int8_t	m;
	u_int16_t	sp, v1, v2, a, d;
	scanf("%[-+r]\n%hd\n%hd\n%hd\n%hd\n%hd\n", &mode, &sp, &v1, &v2, &a, &d);
	m = (mode == '+' ? 0 : mode == '-' ? 2 : 4);
	snprintf(s, 33, "0C101000%02X00%04X%04X%04X%04X%04X",
		m,
		swap(sp),
		swap(v1),
		swap(v2),
		swap(a),
		swap(d)
	);
	printf(":%s%02X\n:00102001D0\n", s, chksum(s));
	return 0;
}
