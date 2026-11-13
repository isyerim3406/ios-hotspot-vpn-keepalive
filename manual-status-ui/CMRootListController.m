#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString *const kPrefs = @"/var/mobile/Library/Preferences/com.chatin.classicmanual.plist";
static NSString *const kStatus = @"/var/mobile/classic-manual-status.plist";

@interface CMRootListController : PSListController
@property (nonatomic, strong) NSTimer *statusTimer;
@end

@implementation CMRootListController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
    [self.statusTimer invalidate];
    self.statusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                 selector:@selector(refreshStatus) userInfo:nil repeats:YES];
}
- (void)viewWillDisappear:(BOOL)animated {
    [self.statusTimer invalidate];
    self.statusTimer = nil;
    [super viewWillDisappear:animated];
}
- (void)refreshStatus { [self reloadSpecifiers]; }
- (NSDictionary *)preferences {
    return [NSDictionary dictionaryWithContentsOfFile:kPrefs] ?: @{};
}
- (NSDictionary *)runtimeStatus {
    return [NSDictionary dictionaryWithContentsOfFile:kStatus] ?: @{};
}
- (id)readSwitch:(PSSpecifier *)specifier {
    id value = [self preferences][@"enabled"];
    return [value isKindOfClass:[NSNumber class]] ? value : @YES;
}
- (void)setSwitch:(id)value specifier:(PSSpecifier *)specifier {
    NSDictionary *prefs = @{@"enabled": @([value boolValue]),
            @"revision": [[NSUUID UUID] UUIDString]};
    [[NSFileManager defaultManager] createDirectoryAtPath:
       [kPrefs stringByDeletingLastPathComponent] withIntermediateDirectories:YES
       attributes:nil error:nil];
    if (![prefs writeToFile:kPrefs atomically:YES]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"İşlem uygulanamadı"
          message:@"Ayar kaydedilemedi. Classic durumu değişmemiş olabilir."
          preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Tamam"
           style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
             CFSTR("com.chatin.classicmanual/preferences.changed"), NULL, NULL, true);
    }
    [self reloadSpecifiers];
}
- (BOOL)isFresh:(NSDictionary *)status {
    NSString *expected = [self preferences][@"revision"] ?: @"";
    NSString *reported = status[@"revision"] ?: @"";
    NSNumber *requested = status[@"requested"];
    return [expected isEqualToString:reported] && requested &&
      [requested boolValue] == [[self readSwitch:nil] boolValue];
}
- (id)readResult:(PSSpecifier *)specifier {
    NSDictionary *s = [self runtimeStatus];
    if (![self isFresh:s]) return @"Kontrol ediliyor…";
    if ([s[@"phase"] isEqualToString:@"applying"]) return @"Uygulanıyor…";
    if ([s[@"verified"] boolValue])
        return [s[@"requested"] boolValue] ? @"Açık — doğrulandı" : @"Kapalı — doğrulandı";
    return @"Doğrulanamadı";
}
- (NSString *)labelForJob:(NSString *)value {
    if ([value isEqualToString:@"running"]) return @"Çalışıyor";
    if ([value isEqualToString:@"loaded"]) return @"Yüklü, çalışmıyor";
    if ([value isEqualToString:@"stopped"]) return @"Durduruldu";
    return @"Bilinmiyor";
}
- (id)readEngine:(PSSpecifier *)specifier {
    NSDictionary *s = [self runtimeStatus];
    if (![self isFresh:s] || [s[@"phase"] isEqualToString:@"applying"]) return @"Kontrol ediliyor…";
    return [self labelForJob:s[@"engine"]];
}
- (id)readPanel:(PSSpecifier *)specifier {
    NSDictionary *s = [self runtimeStatus];
    if (![self isFresh:s] || [s[@"phase"] isEqualToString:@"applying"]) return @"Kontrol ediliyor…";
    return [self labelForJob:s[@"panel"]];
}
- (id)readProcesses:(PSSpecifier *)specifier {
    NSDictionary *s = [self runtimeStatus];
    if (![self isFresh:s] || [s[@"phase"] isEqualToString:@"applying"]) return @"Kontrol ediliyor…";
    NSNumber *n = s[@"pythonCount"];
    return [n isKindOfClass:[NSNumber class]] ?
        [NSString stringWithFormat:@"%@ süreç", n] : @"Doğrulanamadı";
}
- (id)readDetail:(PSSpecifier *)specifier {
    NSDictionary *s = [self runtimeStatus];
    if (![self isFresh:s] || [s[@"phase"] isEqualToString:@"applying"]) return @"Durum bekleniyor";
    NSString *message = s[@"message"];
    return message.length ? message : @"—";
}
@end
