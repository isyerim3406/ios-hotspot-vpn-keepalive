#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
static NSString *const Pref=@"/var/mobile/Library/Preferences/com.chatin.classicmanual.plist";
static NSString *const State=@"/var/mobile/classic-manual-status.plist";
@interface CMRootListController : UITableViewController
@property (nonatomic,strong) NSTimer *timer;
@end
@implementation CMRootListController
- (instancetype)init { return [super initWithStyle:UITableViewStyleGrouped]; }
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"Classic Keepawake"; }
- (NSDictionary *)prefs { return [NSDictionary dictionaryWithContentsOfFile:Pref] ?: @{}; }
- (NSDictionary *)state { return [NSDictionary dictionaryWithContentsOfFile:State] ?: @{}; }
- (BOOL)enabled { id v=[self prefs][@"enabled"]; return [v isKindOfClass:NSNumber.class] ? [v boolValue] : YES; }
- (BOOL)current:(NSDictionary *)s {
 NSDictionary *p=[self prefs]; id r=p[@"revision"], sr=s[@"revision"], v=s[@"requested"];
 return [r isKindOfClass:NSString.class] && [sr isKindOfClass:NSString.class] &&
 [r isEqualToString:sr] && [v isKindOfClass:NSNumber.class] && [v boolValue]==[self enabled];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self.tableView reloadData];
 [self.timer invalidate]; self.timer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refresh:) userInfo:nil repeats:YES]; }
- (void)viewWillDisappear:(BOOL)a { [self.timer invalidate]; self.timer=nil; [super viewWillDisappear:a]; }
- (void)refresh:(NSTimer *)t { [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone]; }
- (void)toggle:(UISwitch *)s {
 NSDictionary *d=@{@"enabled":@(s.on),@"revision":[[NSUUID UUID] UUIDString]};
 if (![d writeToFile:Pref atomically:YES]) { s.on=!s.on;
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Kaydetme hatası" message:@"Anahtar kaydedilemedi." preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:a animated:YES completion:nil]; return; }
 CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.chatin.classicmanual/preferences.changed"),NULL,NULL,true);
 [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 2; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return s==0?1:5; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return s==0?@"MANUEL KONTROL":@"GERÇEK ÇALIŞMA DURUMU"; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s {
 return s==0?@"Orijinal Classic değişmez. Respring gerekmez.":@"Sonuç root servis denetiminden okunur, anahtar değerinden tahmin edilmez."; }
- (NSString *)job:(id)v { if (![v isKindOfClass:NSString.class])return @"Bilinmiyor";
 if([v isEqualToString:@"running"])return @"Çalışıyor"; if([v isEqualToString:@"loaded"])return @"Yüklü";
 if([v isEqualToString:@"stopped"])return @"Durduruldu";return @"Bilinmiyor"; }
- (NSString *)value:(NSInteger)n { NSDictionary *s=[self state];
 if(![self current:s])return @"Kontrol ediliyor…";
 if([s[@"phase"] isEqualToString:@"applying"])return @"Uygulanıyor…";
 switch(n) {
 case 0:return [s[@"verified"] boolValue]?([self enabled]?@"Açık — doğrulandı":@"Kapalı — doğrulandı"):@"Doğrulanamadı";
 case 1:return [self job:s[@"engine"]];case 2:return [self job:s[@"panel"]];
 case 3:{id v=s[@"pythonCount"];return [v isKindOfClass:NSNumber.class]?[NSString stringWithFormat:@"%@ süreç",v]:@"Bilinmiyor";}
 case 4:{id v=s[@"message"];return [v isKindOfClass:NSString.class]&&[v length]?v:@"—";}
 }return @"—"; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
 UITableViewCell *c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
 c.selectionStyle=UITableViewCellSelectionStyleNone;
 if(p.section==0){c.textLabel.text=@"Classic Aç / Kapat";UISwitch *sw=[[UISwitch alloc]initWithFrame:CGRectZero];
 sw.on=[self enabled];[sw addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];c.accessoryView=sw;
 }else{NSArray *a=@[@"Sonuç",@"Classic motoru",@"Classic paneli",@"Python süreçleri",@"Kontrol ayrıntısı"];
 c.textLabel.text=a[p.row];c.detailTextLabel.text=[self value:p.row];
 c.detailTextLabel.adjustsFontSizeToFitWidth=YES;c.detailTextLabel.minimumScaleFactor=0.65;}
 return c;
}
@end
