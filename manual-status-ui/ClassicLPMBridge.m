#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>

static NSString *const RequestPath = @"/var/mobile/Library/Preferences/com.chatin.classiclpm.request.plist";
static NSString *const AckPath = @"/var/mobile/Library/Preferences/com.chatin.classiclpm.ack.plist";
static NSString *const NotifyName = @"com.chatin.classiclpm/request";

static id CLPowerManager(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dlopen("/System/Library/PrivateFrameworks/LowPowerMode.framework/LowPowerMode", RTLD_NOW | RTLD_LOCAL);
    });
    Class cls = NSClassFromString(@"_PMLowPowerMode");
    if (!cls || ![cls respondsToSelector:@selector(sharedInstance)]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(cls, @selector(sharedInstance));
}
static NSInteger CLActualMode(void) {
    id manager = CLPowerManager();
    if (!manager || ![manager respondsToSelector:@selector(getPowerMode)]) return -1;
    NSInteger state = ((NSInteger (*)(id, SEL))objc_msgSend)(manager, @selector(getPowerMode));
    return (state == 0 || state == 1) ? state : -1;
}
static NSDictionary *CLReadRequest(void) {
    NSDictionary *request = [NSDictionary dictionaryWithContentsOfFile:RequestPath];
    return [request isKindOfClass:[NSDictionary class]] ? request : nil;
}
static void CLReply(NSString *nonce, NSInteger wanted, NSInteger actual, NSString *reason) {
    NSDictionary *latest = CLReadRequest();
    if (![latest[@"nonce"] isEqualToString:nonce]) return;
    BOOL success = actual == wanted;
    NSDictionary *response = @{
        @"nonce": nonce, @"wanted": @(wanted), @"actual": @(actual),
        @"ok": @(success),
        @"reason": reason ?: (success ? @"verified" : @"power-mode-not-changed"),
        @"time": @([[NSDate date] timeIntervalSince1970])
    };
    [response writeToFile:AckPath atomically:YES];
}
static void CLCheck(NSString *nonce, NSInteger wanted, NSUInteger remaining) {
    NSDictionary *latest = CLReadRequest();
    if (![latest[@"nonce"] isEqualToString:nonce]) return;
    NSInteger actual = CLActualMode();
    if (actual == wanted) {
        CLReply(nonce, wanted, actual, @"verified-in-SpringBoard");
        return;
    }
    if (!remaining) {
        CLReply(nonce, wanted, actual, @"SpringBoard-power-call-not-applied");
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ CLCheck(nonce, wanted, remaining - 1); });
}
static void CLHandle(void) {
    NSDictionary *request = CLReadRequest();
    NSString *nonce = request[@"nonce"];
    NSNumber *value = request[@"wanted"];
    NSNumber *issued = request[@"issued"];
    if (![nonce isKindOfClass:[NSString class]] || nonce.length < 16 || nonce.length > 64 ||
        ![value isKindOfClass:[NSNumber class]] || ![issued isKindOfClass:[NSNumber class]]) return;
    NSInteger wanted = [value integerValue];
    if (wanted != 0 && wanted != 1) return;
    NSTimeInterval age = [[NSDate date] timeIntervalSince1970] - [issued doubleValue];
    if (age < -5 || age > 30) return;
    NSInteger actual = CLActualMode();
    if (actual < 0) {
        CLReply(nonce, wanted, -1, @"LowPowerMode-framework-unavailable");
        return;
    }
    if (actual != wanted) {
        id manager = CLPowerManager();
        SEL selector = @selector(setPowerMode:fromSource:);
        if (!manager || ![manager respondsToSelector:selector]) {
            CLReply(nonce, wanted, actual, @"LowPowerMode-setter-unavailable");
            return;
        }
        ((void (*)(id, SEL, NSInteger, id))objc_msgSend)(manager, selector, wanted, @"SpringBoard");
    }
    CLCheck(nonce, wanted, 8);
}
static void CLNotification(CFNotificationCenterRef center, void *observer,
                           CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ CLHandle(); });
}
__attribute__((constructor)) static void CLLPMInit(void) {
    @autoreleasepool {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, CLNotification, (__bridge CFStringRef)NotifyName,
            NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        dispatch_async(dispatch_get_main_queue(), ^{ CLHandle(); });
    }
}
