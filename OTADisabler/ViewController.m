//
//  ViewController.m
//  OTADisabler
//
//  Created by ichitaso on 2021/02/18.
//

#import "ViewController.h"
#include <dlfcn.h>
#import "MobileGestalt.h"
#import "iokit.h"
#include <mach/mach.h>
#include "kairos/newpatch.h"

#define VERSION @"v0.0.2~beta"
#define PROFILE1 "/var/mobile/Library/Preferences/com.apple.MobileAsset.plist"
#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

kern_return_t set_generator(const char *new_generator);
const char *get_generator(void);
struct iboot64_img iboot_in;

uint64_t iodtnvram_obj = 0x0;
uint64_t original_vtab = 0x0;

kern_return_t set_generator(const char *new_generator) {
    kern_return_t ret = KERN_SUCCESS;

    const char *current_generator = get_generator();
    NSLog(@"got current generator: %s", current_generator);

    if (current_generator != NULL) {
        if (strcmp(current_generator, new_generator) == 0) {
            NSLog(@"not setting new generator -- generator is already set");
            free((void *)current_generator);
            return KERN_SUCCESS;
        }
        free((void *)current_generator);
    }

    CFStringRef str = CFStringCreateWithCStringNoCopy(NULL, new_generator, kCFStringEncodingUTF8, kCFAllocatorNull);
    if (str == NULL) {
        NSLog(@"failed to allocate new CFStringRef");
        return KERN_FAILURE;
    }

    CFMutableDictionaryRef dict = CFDictionaryCreateMutable(NULL, 0, &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (dict == NULL) {
        NSLog(@"failed to allocate new CFMutableDictionaryRef");
        return KERN_FAILURE;
    }

    CFDictionarySetValue(dict, CFSTR("com.apple.System.boot-nonce"), str);
    CFRelease(str);

    io_service_t nvram = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODTNVRAM"));
    if (!MACH_PORT_VALID(nvram)) {
        NSLog(@"failed to open IODTNVRAM service");
        return KERN_FAILURE;
    }

    ret = IORegistryEntrySetCFProperties(nvram, dict);

    return ret;
}

const char *get_generator() {
    kern_return_t ret = KERN_SUCCESS;

    io_service_t nvram = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODTNVRAM"));
    if (!MACH_PORT_VALID(nvram)) {
        NSLog(@"failed to open IODTNVRAM service");
        return NULL;
    }

    io_string_t buffer;
    unsigned int len = 256;
    ret = IORegistryEntryGetProperty(nvram, "com.apple.System.boot-nonce", buffer, &len);
    if (ret != KERN_SUCCESS) {
        // Nonce is not set
        NSLog(@"nonce is not currently set");
        return NULL;
    }

    return strdup(buffer);
}

@interface ViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *system;
@property (weak, nonatomic) IBOutlet UILabel *status;
@property (weak, nonatomic) IBOutlet UIButton *btn;
@property (weak, nonatomic) IBOutlet UILabel *nonce;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UILabel *ecid;
@property (weak, nonatomic) IBOutlet UILabel *model;
@property (nonatomic, copy) NSString *valueStr;

@end

@interface UIDeviceHardware : NSObject
- (NSString *)platform;
@end

@implementation UIDeviceHardware
- (NSString *)platform {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}
@end

static CFStringRef (*$MGCopyAnswer)(CFStringRef);

bool vaildGenerator(NSString *generator) {
    if ([generator length] != 18 || [generator characterAtIndex:0] != '0' || [generator characterAtIndex:1] != 'x') {
        return false;
    }
    for (int i = 2; i <= 17; i++) {
        if (!isxdigit([generator characterAtIndex:i])) {
            return false;
        }
    }
    return true;
}

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    // System info
    NSString *systemStr = [NSString stringWithFormat:@"%@ %@ %@ - %@",[[UIDeviceHardware alloc] platform],[[UIDevice currentDevice] systemName],[[UIDevice currentDevice] systemVersion],VERSION];


    void *gestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_GLOBAL | RTLD_LAZY);
    $MGCopyAnswer = dlsym(gestalt, "MGCopyAnswer");

    // System Info
    self.system.text = systemStr;

    if (self.view.tag == 143) {
        self.textField.delegate = self;

        uint32_t uid = getuid();
        printf("getuid() returns %u\n", uid);
        printf("whoami: %s\n", uid == 0 ? "root" : "mobile");
        NSString *whoami = [NSString stringWithUTF8String:((void)(@"%s"), uid == 0 ? "root" : "mobile")];
        if ([whoami isEqualToString:@"mobile"]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"You can not set Nonce"
                                                                           message:[@"Status:" stringByAppendingString:whoami]
                                                                    preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *action) {}]];

            [self presentViewController:alert animated:YES completion:nil];
        }
        // Nonce Info
        self.nonce.text = [self getGenerator];
    } else if (self.view.tag == 999) {
        // ECID Section
        self.ecid.text = [NSString stringWithFormat:@"ECID: %@", [self ecidHexValue]];
        self.model.text = [NSString stringWithFormat:@"Device Model: %@", [self modelValue]];
    } else {
        if (access(PROFILE1, F_OK != 0)) {
            self.status.text = @"OTA: Enabled";
            [self.btn setTitle:@"Disable" forState:UIControlStateNormal];
        } else if (access(PROFILE1, F_OK == 0)) {
            self.status.text = @"OTA: Disabled";
            [self.btn setTitle:@"Enable" forState:UIControlStateNormal];
        }
    }
}

- (void)enable {
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:@PROFILE1]) {
        [manager removeItemAtPath:@PROFILE1 error:nil];

        sleep(2);

        UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"OTA Enabled"
                                            message:@"Please reboot device"
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {}]];

        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)disable {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@PROFILE1];
    NSMutableDictionary *mutableDict = dict ? [dict mutableCopy] : [NSMutableDictionary dictionary];

    [mutableDict setObject:@"https://mesu.apple.com/assets/tvOS14DeveloperSeed" forKey:@"MobileAssetServerURL-com.apple.MobileAsset.MobileSoftwareUpdate.UpdateBrain"];
    [mutableDict setObject:@NO forKey:@"MobileAssetSUAllowOSVersionChange"];
    [mutableDict setObject:@NO forKey:@"MobileAssetSUAllowSameVersionFullReplacement"];
    [mutableDict setObject:@"https://mesu.apple.com/assets/tvOS14DeveloperSeed" forKey:@"MobileAssetServerURL-com.apple.MobileAsset.RecoveryOSUpdate"];
    [mutableDict setObject:@"https://mesu.apple.com/assets/tvOS14DeveloperSeed" forKey:@"MobileAssetServerURL-com.apple.MobileAsset.RecoveryOSUpdateBrain"];
    [mutableDict setObject:@"https://mesu.apple.com/assets/tvOS14DeveloperSeed" forKey:@"MobileAssetServerURL-com.apple.MobileAsset.SoftwareUpdate"];
    [mutableDict setObject:@"65254ac3-f331-4c19-8559-cbe22f5bc1a6" forKey:@"MobileAssetAssetAudience"];

    [mutableDict writeToFile:@PROFILE1 atomically:YES];

    sleep(2);

    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:@PROFILE1]) {
        UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"OTA Disabled"
                                            message:@"Please reboot device"
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {}]];

        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (IBAction)tappedBtn:(UIButton *)sender {
    if ([sender.currentTitle isEqualToString:@"Enable"]) {
        NSLog(@"starting enable OTA...");

        [self performSelectorOnMainThread:@selector(enable) withObject:nil waitUntilDone:YES];

        if (access(PROFILE1, F_OK != 0)) {
            self.status.text = @"OTA: Enabled";
            [sender setTitle:@"Disable" forState:UIControlStateNormal];
        } else {
            [sender setTitle:@"Failed" forState:UIControlStateNormal];
        }
    } else if ([sender.currentTitle isEqualToString:@"Disable"]) {
        NSLog(@"starting disable OTA...");

        [self performSelectorOnMainThread:@selector(disable) withObject:nil waitUntilDone:YES];

        if (access(PROFILE1, F_OK == 0)) {
            self.status.text = @"OTA: Disabled";
            [sender setTitle:@"Enable" forState:UIControlStateNormal];
        } else {
            [sender setTitle:@"Failed" forState:UIControlStateNormal];
        }
    }
}

- (IBAction)textChanged:(UITextField *)textfield {
    CGFloat maxLength = 18;
    NSString *toBeString = textfield.text;

    UITextRange *selectedRange = [textfield markedTextRange];
    UITextPosition *position = [textfield positionFromPosition:selectedRange.start offset:0];
    if (!position || !selectedRange) {
        if (toBeString.length > maxLength) {
            NSRange rangeIndex = [toBeString rangeOfComposedCharacterSequenceAtIndex:maxLength];
            if (rangeIndex.length == 1) {
                textfield.text = [toBeString substringToIndex:maxLength];
            } else {
                NSRange rangeRange = [toBeString rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, maxLength)];
                textfield.text = [toBeString substringWithRange:rangeRange];
            }
        }
    }
    NSLog(@"textfield data:%@",textfield.text);
    self.valueStr = textfield.text;
}

- (NSString *)getGenerator {
    uint32_t gid = getgid();
    NSLog(@"getgid() returns %u\n", gid);
    uint32_t uid = getuid();
    NSLog(@"getuid() returns %u\n", uid);

    if (uid != 0 && gid != 0) return @"Status: Not root";

    NSString *generator = nil;

    if (get_generator()) {
        generator = [NSString stringWithCString:get_generator() encoding:NSUTF8StringEncoding];
    }

    return generator ? [NSString stringWithFormat:@"Nonce: %@", generator] : @"Nonce: Not Set Nonce";
}

- (void)setValue {
    NSString *value = nil;
    if (!self.valueStr || [self.valueStr isEqualToString:@""]) {
        value = @"0x1111111111111111";
    } else {
        value = self.valueStr;
    }

    self.valueStr = value;

    [self.view endEditing:YES];

    if (!vaildGenerator(value)) {
        UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"Wrong Value"
                                            message:[NSString stringWithFormat:@"\"%@\"\nFormat error!", value]
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {}]];

        [self presentViewController:alertController animated:YES completion:nil];
        // return
        return;
    } else {
        UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"Set Generator"
                                            message:value
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
            [self setgenerator];
        }]];

        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)setgenerator {
    if (getuid() != 0) {
        setuid(0);
    }

    if (getuid() != 0) {
        UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"You can not set nonce"
                                            message:@"Status: mobile"
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {}]];

        [self presentViewController:alertController animated:YES completion:nil];
        // return
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        unlock_nvram(&iboot_in);

        char *setnonce = (char *)[self.valueStr UTF8String];

        set_generator(setnonce);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Nonce Info change
            self.nonce.text = [self getGenerator];
        });
    });
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    [self setValue];
    return YES;
}


- (IBAction)setGenerator:(UIButton *)sender {
    [self setValue];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [self becomeFirstResponder];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (IBAction)copyEcidValue:(id)sender {
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:@"Copy ECID Value"
                                        message:[self ecidHexValue]
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Copy (Hex)"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = [self ecidHexValue];
    }]];

    if ([self.ecid.text isEqualToString:@"ECID: Secret"]) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Show ECID"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
            self.ecid.text = [NSString stringWithFormat:@"ECID: %@", [self ecidHexValue]];
        }]];
    } else {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Hide ECID"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
            self.ecid.text = @"ECID: Secret";
        }]];
    }

    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {}]];

    [self presentViewController:alertController animated:YES completion:nil];
}

- (NSString *)ecidValue {
    CFStringRef ecid = (CFStringRef)$MGCopyAnswer(CFSTR("UniqueChipID"));
    if ([[[UIDeviceHardware alloc] platform] isEqualToString:@"x86_64"]) {
        return @"ecidvalue";
    } else {
        return [NSString stringWithFormat:@"%@", (__bridge NSString *)ecid];
    }
}
- (NSString *)ecidHexValue {
    return [NSString stringWithFormat:@"%lX", (unsigned long)[[self ecidValue] integerValue]];
}

- (NSString *)modelValue {
    CFStringRef boardId = (CFStringRef)$MGCopyAnswer(CFSTR("HWModelStr"));
    if (!boardId) return @"NULL";
    return [NSString stringWithFormat:@"%@", (__bridge NSString *)boardId];;
}

- (IBAction)openSafari:(UIButton *)sender {
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Useful Site"
                                          message:nil
                                          preferredStyle:UIAlertControllerStyleActionSheet];

    [alertController addAction:[UIAlertAction actionWithTitle:@"SHSH Host" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:@"https://shsh.host/"];
        });
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"TSS Saver" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:@"https://tsssaver.1conan.com/v2/"];
        });
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"The iPhone Wiki" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:@"https://www.theiphonewiki.com/"];
        });
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"My Repo" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:@"https://cydia.ichitaso.com"];
        });
    }]];

    // Fix Crash for iPad
    if (IS_PAD) {
        CGRect rect = self.view.frame;
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(rect)-60,rect.size.height-50, 120,50);
        alertController.popoverPresentationController.permittedArrowDirections = 0;
    } else {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}]];
    }

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)openURLInBrowser:(NSString *)url {
    SFSafariViewControllerConfiguration *config = [[SFSafariViewControllerConfiguration alloc] init];
    config.barCollapsingEnabled = NO;
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:url] configuration:config];
    [self presentViewController:safari animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
