//
//  ViewController.m
//  OTADisabler
//
//  Created by ichitaso on 2021/02/15.
//

#import "ViewController.h"
#import <spawn.h>

#define VERSION @"v0.0.1beta"
#define PROFILE1 "/var/mobile/Library/Preferences/com.apple.MobileAsset.plist"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *system;
@property (weak, nonatomic) IBOutlet UILabel *status;
@property (weak, nonatomic) IBOutlet UIButton *btn;

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

@implementation ViewController

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
        }
        else {
            [sender setTitle:@"Failed" forState:UIControlStateNormal];
        }
    }
    else if ([sender.currentTitle isEqualToString:@"Disable"]) {
        NSLog(@"starting disable OTA...");

        [self performSelectorOnMainThread:@selector(disable) withObject:nil waitUntilDone:YES];
        
        if (access(PROFILE1, F_OK == 0)) {
            self.status.text = @"OTA: Disabled";
            [sender setTitle:@"Enable" forState:UIControlStateNormal];
        }
        else {
            [sender setTitle:@"Failed" forState:UIControlStateNormal];
        }
    }    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if (access(PROFILE1, F_OK != 0)) {
        self.status.text = @"OTA: Enabled";
        [self.btn setTitle:@"Disable" forState:UIControlStateNormal];
    } else if (access(PROFILE1, F_OK == 0)) {
        self.status.text = @"OTA: Disabled";
        [self.btn setTitle:@"Enable" forState:UIControlStateNormal];
    }
    // System info
    NSString *systemStr = [NSString stringWithFormat:@"%@ %@ %@ - %@",[[UIDeviceHardware alloc] platform],[[UIDevice currentDevice] systemName],[[UIDevice currentDevice] systemVersion],VERSION];
    self.system.text = systemStr;
}

@end
