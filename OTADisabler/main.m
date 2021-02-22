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
//#import "AppDelegate.h"
#include <sys/stat.h>

//int main(int argc, char * argv[]) {
//    NSString * appDelegateClassName;
//    @autoreleasepool {
//        // Setup code that might create autoreleased objects goes here.
//        appDelegateClassName = NSStringFromClass([AppDelegate class]);
//    }
//    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
//}

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
/*
int execute(const char *prog, const char *arg);

int execute(const char *prog, const char *arg)
{
  pid_t childpid;
  int status;
  char cmd[30];

  snprintf(cmd, sizeof(cmd), "./%s", prog);

  childpid = fork();
  if (childpid == (pid_t) -1) {
    return(-2);
  } else if (childpid == 0) {
    if (execl(cmd, prog, arg, NULL) == -1) {
        exit(-2);
    }
    return(-2);    // Never reached
  } else {
    wait(&status);
  }

  return(WEXITSTATUS(status));
}

char* permissions(char *file){
    struct stat st;
    char *modeval = malloc(sizeof(char) * 9 + 1);
    if(stat(file, &st) == 0){
        mode_t perm = st.st_mode;
        modeval[0] = (perm & S_IRUSR) ? 'r' : '-';
        modeval[1] = (perm & S_IWUSR) ? 'w' : '-';
        modeval[2] = (perm & S_IXUSR) ? 'x' : '-';
        modeval[3] = (perm & S_IRGRP) ? 'r' : '-';
        modeval[4] = (perm & S_IWGRP) ? 'w' : '-';
        modeval[5] = (perm & S_IXGRP) ? 'x' : '-';
        modeval[6] = (perm & S_IROTH) ? 'r' : '-';
        modeval[7] = (perm & S_IWOTH) ? 'w' : '-';
        modeval[8] = (perm & S_IXOTH) ? 'x' : '-';
        modeval[9] = '\0';
        return modeval;
    }
    else{
        return strerror(errno);
    }
}*/

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

                /*sleep(2);
                printf("Copy files...\n");
                NSURL *currentURL = [[[NSBundle mainBundle] bundleURL] URLByDeletingLastPathComponent];
                NSString *currentStr = [currentURL absoluteString];
                NSString *realPath = [currentStr stringByReplacingOccurrencesOfString:@"file://" withString:@""];

                NSString *appPath = [realPath stringByAppendingString:@"OTADisabler.app"];

                //NSString *bashStr = [appPath stringByAppendingString:@"/bash"];
                NSString *cmdStr = [appPath stringByAppendingString:@"/dimentio"];
                sleep(2);
                NSFileManager *manager = [NSFileManager defaultManager];
                if ([manager fileExistsAtPath:@"/var/root/dimentio"]) {
                    Log(log_info, "remove /var/root/dimentio");
                    [manager removeItemAtPath:@"/var/root/dimentio" error:nil];
                }
                [manager copyItemAtPath:cmdStr toPath:@"/var/root/dimentio" error:nil];
                printf("Copy files Done!\n");

                if ([manager fileExistsAtPath:@"/var/root/dimentio"]) {
                    printf("Change files Permission...\n");
                    //system("chmod 2755 setgid");
                    //if (execute("setgid", "06755") != 1) exit(0);
                    //sleep(2);
                    //system("chmod 4755 setuid");
                    //if (execute("setuid", "06755") != 1) exit(0);
                    //sleep(2);
                    setuid(0);
                    if ((chdir("/")) < 0) {
                        printf("Not root!\n");
                    }
                    [manager setAttributes:@{NSFilePosixPermissions:@0755}
                              ofItemAtPath:@"/var/root/dimentio" error:nil];

                    //[manager setAttributes:@{NSFilePosixPermissions:@04755}
                    //          ofItemAtPath:@"/var/bash" error:nil];

                    //system("chmod g+s /var/bash");
                    //system("chmod g+s /var/dimentio");
                    //chmod("/tmp/bash", 4755);
                    //chmod("/tmp/dimentio", 4755);
                    //if (execute("/tmp/dimentio", "04755") != 1 || execute("/tmp/bash", "04755") != 1) {
                    //    printf("Change files Permission faild\n");
                    //}
                    sleep(2);
                    //NSLog(@"/var/dimentio:%s",permissions("/var/dimentio"));
                    //chown("/var/bash", 0, 0);
                    chown("/var/root/dimentio", 0, 0);

                    printf("Change files Permission Done!\n");

                    system("/var/root/dimentio 0x1111111111111111");
                    Log(log_info, "run dimentio 0x1111111111111111");
                }*/

                free(redeem_racers);
                [alert dismissViewControllerAnimated:YES completion:^{}];
            });
        }];
    });
}
