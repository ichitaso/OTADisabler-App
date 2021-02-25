//  main.m
//
//  OTADisabler
//
//  Created by ichitaso on 2021/02/15.
//

#include <stdio.h>
#include "main.h"
#include "support.h"
#include <UIKit/UIKit.h>
#include "fishhook/fishhook.h"
#include "PatchDebugging/BypassAntiDebugging.h"
#include "exploit/cicuta_virosa.h"
#include "postexploit/rootless.h"
#include <sys/stat.h>
#import <dlfcn.h>

@implementation PatchEntry

+ (void)load {
    disable_pt_deny_attach();
    disable_sysctl_debugger_checking();

    #if TESTS_BYPASS
    test_aniti_debugger();
    #endif
}

void error_popup(NSString *messgae_popup, BOOL fatal) {
    if (fatal) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Fatal Error" message:messgae_popup preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Exit" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
                exit(0);
            }]];
            UIViewController *controller = UIApplication.sharedApplication.windows.firstObject.rootViewController;
            while (controller.presentedViewController) {
                controller = controller.presentedViewController;
            }
            [controller presentViewController:alertController animated:YES completion:NULL];
        });
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:messgae_popup preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:NULL]];
            UIViewController *controller = UIApplication.sharedApplication.windows.firstObject.rootViewController;
            while (controller.presentedViewController) {
                controller = controller.presentedViewController;
            }
            [controller presentViewController:alertController animated:YES completion:NULL];
        });
    }
}

int start() {
    Log(log_info, "Start exploitation to gain tfp0.");
    if (SYSTEM_VERSION_LESS_THAN(@"13.0") || SYSTEM_VERSION_GREATER_THAN(@"14.3")) {
        Log(log_error, "Incorrect version");
        error_popup(@"Unsupported iOS version", true);
    } else {
        if(SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(@"14.3")){
            jailbreak(nil);
        }
    }
    return 0;
}
@end

__attribute__((constructor))
static void initializer(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *main =  UIApplication.sharedApplication.windows.firstObject.rootViewController;
        while (main.presentedViewController != NULL && ![main.presentedViewController isKindOfClass: [UIAlertController class]]) {
            main = main.presentedViewController;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Exploiting"
                                                                       message:@"This will take some time..."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [main presentViewController:alert animated:YES completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                setgid(0);
                uint32_t gid = getgid();
                NSLog(@"getgid() returns %u\n", gid);
                setuid(0);
                uint32_t uid = getuid();
                NSLog(@"getuid() returns %u\n", uid);
                if (uid != 0 && gid != 0) {
                    start();
                }
                free(redeem_racers);
                [alert dismissViewControllerAnimated:YES completion:^{}];
            });
        }];
    });
}
