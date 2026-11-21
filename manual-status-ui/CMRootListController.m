#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>

static NSString *const CMPreferencesPath = @"/var/mobile/Library/Preferences/com.chatin.classicmanual.plist";
static NSString *const CMStatusPath = @"/var/mobile/Library/Preferences/com.chatin.classicmanual.status.plist";
static NSString *const CMStatusFallbackPath = @"/var/mobile/classic-manual-status.plist";

@interface CMRootListController : PSListController
@property (nonatomic, retain) NSTimer *cmStatusTimer;
@end

@implementation CMRootListController

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *items = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
    [group setProperty:@"Orijinal Classic motoru değiştirilmez. Anahtara dokununca servislerin gerçek durumu kontrol edilir." forKey:@"footerText"];
    [items addObject:group];
    PSSpecifier *toggle = [PSSpecifier preferenceSpecifierNamed:@"Classic Aç / Kapat"
        target:self set:@selector(cmSetEnabled:specifier:)
        get:@selector(cmGetEnabled:) detail:nil
        cell:[PSTableCell cellTypeFromString:@"PSSwitchCell"] edit:nil];
    [toggle setProperty:@YES forKey:@"default"];
    [items addObject:toggle];

    PSSpecifier *findMyGroup = [PSSpecifier emptyGroupSpecifier];
    [findMyGroup setProperty:@"Bu anahtar iOS Ayarlarındaki Bul özelliğini kapatmaz; yalnızca ilgili launchd servislerini kontrol eder. Kapalı durumda kayıp cihazın bulunması engellenebilir. Varsayılan: Açık." forKey:@"footerText"];
    [items addObject:findMyGroup];
    PSSpecifier *findMyToggle = [PSSpecifier preferenceSpecifierNamed:@"Find My daemonları aktif" target:self set:@selector(cmSetFindMy:specifier:) get:@selector(cmGetFindMy:) detail:nil cell:[PSTableCell cellTypeFromString:@"PSSwitchCell"] edit:nil];
    [findMyToggle setProperty:@YES forKey:@"default"];
    [items addObject:findMyToggle];
    PSSpecifier *findMyStatus = [PSSpecifier preferenceSpecifierNamed:@"Find My servis sonucu" target:self set:nil get:@selector(cmGetFindMyStatus:) detail:nil cell:[PSTableCell cellTypeFromString:@"PSTitleValueCell"] edit:nil];
    [items addObject:findMyStatus];

    PSSpecifier *statusGroup = [PSSpecifier emptyGroupSpecifier];
    [statusGroup setProperty:@"Durum anahtar değerinden değil, root servisinin launchctl ve süreç kontrolünden okunur. Bilinmeyen durum doğrulanmış sayılmaz." forKey:@"footerText"];
    [items addObject:statusGroup];

    NSArray *names = @[@"Sonuç", @"Classic motoru", @"Classic paneli", @"Python süreçleri", @"Kontrol ayrıntısı"];
    NSArray *selectors = @[@"cmGetResult:", @"cmGetEngine:", @"cmGetPanel:", @"cmGetProcesses:", @"cmGetDetails:"];
    for (NSUInteger i = 0; i < names.count; ++i) {
        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:names[i]
            target:self set:nil get:NSSelectorFromString(selectors[i])
            detail:nil cell:[PSTableCell cellTypeFromString:@"PSTitleValueCell"] edit:nil];
        [items addObject:spec];
    }
    _specifiers = [items mutableCopy];
    return _specifiers;
}

- (void)viewDidLoad { [super viewDidLoad]; self.title = @"Classic Keepawake"; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.cmStatusTimer invalidate];
    self.cmStatusTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
        target:self selector:@selector(cmRefresh:) userInfo:nil repeats:YES];
}
- (void)viewWillDisappear:(BOOL)animated {
    [self.cmStatusTimer invalidate];
    self.cmStatusTimer = nil;
    [super viewWillDisappear:animated];
}
- (void)dealloc { [self.cmStatusTimer invalidate]; }

- (void)cmRefresh:(NSTimer *)timer { [self reloadSpecifiers]; }

- (NSDictionary *)cmPreferences {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:CMPreferencesPath];
    return [prefs isKindOfClass:[NSDictionary class]] ? prefs : @{};
}
- (NSDictionary *)cmStatus {
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:CMStatusPath];
    if (![state isKindOfClass:[NSDictionary class]]) {
        state = [NSDictionary dictionaryWithContentsOfFile:CMStatusFallbackPath];
    }
    return [state isKindOfClass:[NSDictionary class]] ? state : @{};
}
- (BOOL)cmEnabled {
    NSNumber *n = [self cmPreferences][@"enabled"];
    return [n isKindOfClass:NSNumber.class] ? n.boolValue : YES;
}
- (id)cmGetEnabled:(PSSpecifier *)specifier { return @([self cmEnabled]); }

- (void)cmSetEnabled:(id)value specifier:(PSSpecifier *)specifier {
    BOOL enabled = [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
    NSMutableDictionary *prefs = [[self cmPreferences] mutableCopy];
    prefs[@"enabled"] = @(enabled);
    prefs[@"revision"] = [[NSUUID UUID] UUIDString];
    if (![prefs writeToFile:CMPreferencesPath atomically:YES]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ayar kaydedilemedi"
            message:@"Classic durumunu değiştiremedim. Anahtarı yeniden dene."
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Tamam"
            style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadSpecifiers];
        return;
    }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.chatin.classicmanual/preferences.changed"), NULL, NULL, true);
    [self reloadSpecifiers];
}

- (id)cmGetFindMy:(PSSpecifier *)specifier {
    id value = [self cmPreferences][@"findmy_daemons"];
    return @(![value isKindOfClass:[NSNumber class]] || [value boolValue]);
}
- (void)cmSetFindMy:(id)value specifier:(PSSpecifier *)specifier {
    BOOL desired = [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : YES;
    NSMutableDictionary *prefs = [[self cmPreferences] mutableCopy];
    prefs[@"findmy_daemons"] = @(desired);
    prefs[@"revision"] = [[NSUUID UUID] UUIDString];
    if (![prefs writeToFile:CMPreferencesPath atomically:YES]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ayar kaydedilemedi"
            message:@"Find My servisleri değiştirilmedi." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.chatin.classicmanual/preferences.changed"), NULL, NULL, true);
    }
    [self reloadSpecifiers];
}
- (id)cmGetFindMyStatus:(PSSpecifier *)specifier {
    NSDictionary *prefs = [self cmPreferences];
    NSDictionary *state = [self cmStatus];
    BOOL desired = ![prefs[@"findmy_daemons"] isKindOfClass:[NSNumber class]] || [prefs[@"findmy_daemons"] boolValue];
    NSNumber *observed = state[@"findmyRequested"];
    if (![observed isKindOfClass:[NSNumber class]] || [observed boolValue] != desired)
        return [self cmRecentlyChanged] ? @"Kontrol ediliyor…" : @"Doğrulanamadı";
    id text = state[@"findmyStatus"];
    return [text isKindOfClass:[NSString class]] ? text : @"Bilinmiyor";
}

- (BOOL)cmCurrent:(NSDictionary *)status {
    NSDictionary *prefs = [self cmPreferences];
    id expected = prefs[@"revision"];
    id actual = status[@"revision"];
    id requested = status[@"requested"];
    return [expected isKindOfClass:NSString.class] &&
       [actual isKindOfClass:NSString.class] &&
       [expected isEqualToString:actual] &&
       [requested isKindOfClass:NSNumber.class] &&
       [requested boolValue] == [self cmEnabled];
}
- (BOOL)cmRecentlyChanged {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:CMPreferencesPath error:NULL];
    NSDate *modified = attributes[NSFileModificationDate];
    if (![modified isKindOfClass:[NSDate class]]) return NO;
    return [[NSDate date] timeIntervalSinceDate:modified] < 12.0;
}
- (BOOL)cmUnconfirmed:(NSDictionary *)s {
    return ![self cmCurrent:s] || [s[@"phase"] isEqualToString:@"applying"];
}
- (BOOL)cmWaiting:(NSDictionary *)s {
    if (![self cmUnconfirmed:s]) return NO;
    if ([self cmRecentlyChanged]) return YES;
    id stamp = s[@"updated"];
    return [stamp isKindOfClass:[NSNumber class]] &&
        ([[NSDate date] timeIntervalSince1970] - [stamp doubleValue] < 12.0);
}
- (NSString *)cmJob:(id)value {
    if (![value isKindOfClass:NSString.class]) return @"Bilinmiyor";
    if ([value isEqualToString:@"running"]) return @"Çalışıyor";
    if ([value isEqualToString:@"loaded"]) return @"Yüklü (PID yok)";
    if ([value isEqualToString:@"stopped"]) return @"Durduruldu";
    return @"Bilinmiyor";
}
- (id)cmGetResult:(PSSpecifier *)specifier {
    NSDictionary *s = [self cmStatus];
    if ([self cmWaiting:s]) return @"Kontrol ediliyor…";
    if ([self cmUnconfirmed:s]) return @"Durum alınamadı";
    if ([s[@"verified"] boolValue])
        return [self cmEnabled] ? @"Açık — doğrulandı" : @"Kapalı — doğrulandı";
    return @"Doğrulanamadı";
}
- (id)cmGetEngine:(PSSpecifier *)specifier {
    NSDictionary *s = [self cmStatus];
    if ([self cmWaiting:s]) return @"Kontrol ediliyor…";
    return [self cmUnconfirmed:s] ? @"Bilinmiyor" : [self cmJob:s[@"engine"]];
}
- (id)cmGetPanel:(PSSpecifier *)specifier {
    NSDictionary *s = [self cmStatus];
    if ([self cmWaiting:s]) return @"Kontrol ediliyor…";
    return [self cmUnconfirmed:s] ? @"Bilinmiyor" : [self cmJob:s[@"panel"]];
}
- (id)cmGetProcesses:(PSSpecifier *)specifier {
    NSDictionary *s = [self cmStatus];
    if ([self cmWaiting:s]) return @"Kontrol ediliyor…";
    if ([self cmUnconfirmed:s]) return @"Bilinmiyor";
    id n = s[@"pythonCount"];
    return [n isKindOfClass:NSNumber.class] ?
        [NSString stringWithFormat:@"%@ süreç", n] : @"Bilinmiyor";
}
- (id)cmGetDetails:(PSSpecifier *)specifier {
    NSDictionary *s = [self cmStatus];
    if ([self cmWaiting:s]) return @"Durum bekleniyor";
    if ([self cmUnconfirmed:s]) return @"Kontrol sonucu okunamadı";
    id message = s[@"message"];
    return [message isKindOfClass:NSString.class] ? message : @"Bilinmiyor";
}
@end
