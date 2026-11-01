/* ushow <from> <to> [nspredicate]: print persisted unified log (/var/db/diagnostics) between two times.
 * Times are "YYYY-MM-DD HH:MM:SS" local. Same entitlements as ulog (ulog.xml). */
#include <dlfcn.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>
typedef void *id;
static void *o;
static id (*cls)(const char *); static void *(*sel)(const char *); static void *M;
#define MSG(r, ...) ((r (*)(__VA_ARGS__))M)
static const char *str(id s) { return s ? MSG(const char *, id, void *)(s, sel("UTF8String")) : "-"; }
static id date(const char *s) {
	struct tm tm = {0};
	if (!strptime(s, "%Y-%m-%d %H:%M:%S", &tm)) { fprintf(stderr, "bad time: %s\n", s); exit(1); }
	tm.tm_isdst = -1;
	return MSG(id, id, void *, double)(cls("NSDate"), sel("dateWithTimeIntervalSince1970:"), (double)mktime(&tm));
}
int main(int argc, char **argv) {
	if (argc < 3) { fprintf(stderr, "usage: ushow <from> <to> [predicate]\n"); return 1; }
	setvbuf(stdout, NULL, _IOLBF, 0);
	o = dlopen("/usr/lib/libobjc.A.dylib", RTLD_NOW);
	dlopen("/System/Library/Frameworks/Foundation.framework/Foundation", RTLD_NOW);
	dlopen("/System/Library/PrivateFrameworks/LoggingSupport.framework/LoggingSupport", RTLD_NOW);
	cls = dlsym(o, "objc_getClass"); sel = dlsym(o, "sel_registerName"); M = dlsym(o, "objc_msgSend");
	static id from, to, pred;
	from = date(argv[1]); to = date(argv[2]);
	if (argc > 3) {
		id f = MSG(id, id, void *, const char *)(cls("NSString"), sel("stringWithUTF8String:"), argv[3]);
		pred = MSG(id, id, void *, id, id)(cls("NSPredicate"), sel("predicateWithFormat:argumentArray:"), f, NULL);
	}
	id store = MSG(id, id, void *)(cls("OSLogEventStore"), sel("localStore"));
	MSG(void, id, void *, void (^)(id, id))(store, sel("prepareWithCompletionHandler:"), ^(id src, id err) {
		if (!src) { fprintf(stderr, "prepare failed: %s\n", str(MSG(id, id, void *)(err, sel("description")))); exit(1); }
		id s = MSG(id, id, void *)(cls("OSLogEventStream"), sel("alloc"));
		s = MSG(id, id, void *, id)(s, sel("initWithSource:"), src);
		if (pred) MSG(void, id, void *, id)(s, sel("setFilterPredicate:"), pred);
		MSG(void, id, void *, void (^)(id))(s, sel("setEventHandler:"), ^(id e) {
			double t = MSG(double, id, void *)(MSG(id, id, void *)(e, sel("date")), sel("timeIntervalSince1970"));
			time_t sec = (time_t)t; char b[32]; strftime(b, sizeof b, "%F %T", localtime(&sec));
			printf("%s.%03d %s[%d] %s/%s: %s\n", b, (int)((t - sec) * 1000), str(MSG(id, id, void *)(e, sel("process"))),
				MSG(int, id, void *)(e, sel("processIdentifier")), str(MSG(id, id, void *)(e, sel("subsystem"))),
				str(MSG(id, id, void *)(e, sel("category"))), str(MSG(id, id, void *)(e, sel("composedMessage"))));
		});
		MSG(void, id, void *, void (^)(int, id))(s, sel("setInvalidationHandler:"), ^(int r, id x) { exit(r == 1 || r == 2 ? 0 : r); });
		MSG(void, id, void *, id, id)(s, sel("activateStreamFromDate:toDate:"), from, to);
		static id keep; keep = s;
	});
	dispatch_main();
}
