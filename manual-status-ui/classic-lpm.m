#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/message.h>

static id manager(void) {
    dlopen("/System/Library/PrivateFrameworks/LowPowerMode.framework/LowPowerMode", RTLD_NOW | RTLD_LOCAL);
    Class cls = NSClassFromString(@"_PMLowPowerMode");
    if (!cls || ![cls respondsToSelector:@selector(sharedInstance)]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(cls,@selector(sharedInstance));
}
static NSInteger currentMode(id m) {
    SEL get = @selector(getPowerMode);
    if (!m || ![m respondsToSelector:get]) return -1;
    return ((NSInteger (*)(id,SEL))objc_msgSend)(m,get);
}
int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 2 && argc != 3) return 64;
        NSString *cmd = [NSString stringWithUTF8String:argv[1]];
        id m = manager();
        NSInteger old = currentMode(m);
        if (old < 0) { fprintf(stderr,"LPM unavailable\n"); return 69; }
        if ([cmd isEqualToString:@"get"] && argc == 2) {
            printf("%ld\n",(long)old);
            return old == 0 || old == 1 ? 0 : 69;
        }
        if (![cmd isEqualToString:@"set"] || argc != 3) return 64;
        if (strcmp(argv[2],"0") && strcmp(argv[2],"1")) return 64;
        NSInteger wanted=atoi(argv[2]);
        SEL setter=@selector(setPowerMode:fromSource:);
        if (![m respondsToSelector:setter]) return 69;
        if (old != wanted) {
            ((void (*)(id,SEL,NSInteger,id))objc_msgSend)(m,setter,wanted,@"SpringBoard");
        }
        for (int i=0;i<10;i++) {
            NSInteger now=currentMode(m);
            if (now == wanted) { printf("%ld\n",(long)now);return 0; }
            [NSThread sleepForTimeInterval:0.15];
        }
        fprintf(stderr,"LPM state did not reach requested value\n");
        return 1;
    }
}
