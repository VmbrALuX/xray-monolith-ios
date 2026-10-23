// Milestone 1 shell: a NATIVE UIKit placeholder. It is NOT rendered by the Monolith engine.
#import <UIKit/UIKit.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/utsname.h>

static NSString *DocsDir(void) {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}
static NSString *GameDir(void) { return [DocsDir() stringByAppendingPathComponent:@"Anomaly"]; }
static NSString *LogPath(void) { return [GameDir() stringByAppendingPathComponent:@"logs/launch.log"]; }

static void Log(NSString *line) {
    NSLog(@"[AnomalyiOS] %@", line);
    NSString *stamped = [NSString stringWithFormat:@"%@  %@\n", [NSDate date], line];
    NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:LogPath()];
    if (!h) {
        [stamped writeToFile:LogPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [h seekToEndOfFile];
    [h writeData:[stamped dataUsingEncoding:NSUTF8StringEncoding]];
    [h closeFile];
}

static BOOL DirExists(NSString *path) {
    BOOL isDir = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir;
}

// Indicative only: checks whether the OS allows a writable+executable (JIT-style) mapping.
// It does not execute any generated code.
static NSString *JitProbe(void) {
    void *p = mmap(NULL, 16384, PROT_READ | PROT_WRITE | PROT_EXEC,
                   MAP_PRIVATE | MAP_ANON | MAP_JIT, -1, 0);
    if (p == MAP_FAILED) return [NSString stringWithFormat:@"DENIED (errno %d)", errno];
    munmap(p, 16384);
    return @"ALLOWED";
}

static NSString *BuildReport(BOOL *found) {
    NSString *root = GameDir();
    BOOL hasGamedata = DirExists([root stringByAppendingPathComponent:@"gamedata"]);
    BOOL hasDb = DirExists([root stringByAppendingPathComponent:@"db"]);
    *found = hasGamedata && hasDb;

    struct utsname u;
    uname(&u);
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"STALKER ANOMALY\niOS port - Milestone 1 shell\n\n"];
    [s appendString:@"NATIVE PLACEHOLDER SCREEN\nDrawn by UIKit. This is NOT rendered by the Monolith engine.\n\n"];
    if (*found) {
        [s appendString:@"Game files: FOUND (gamedata + db)\nEngine is not linked yet, so nothing can launch.\n\n"];
    } else {
        [s appendString:@"Game files not found.\n\nCopy your Anomaly folder CONTENTS into:\n"
                        @"Files app > On My iPhone > Anomaly iOS > Anomaly\n"
                        @"It must contain the folders 'db' and 'gamedata'.\n\n"];
        [s appendFormat:@"gamedata: %@\ndb: %@\n\n", hasGamedata ? @"yes" : @"missing", hasDb ? @"yes" : @"missing"];
    }
    [s appendFormat:@"Device: %s\niOS: %@\nRAM: %.1f GB\nRWX mapping: %@\n\n",
        u.machine, UIDevice.currentDevice.systemVersion,
        NSProcessInfo.processInfo.physicalMemory / 1073741824.0, JitProbe()];
    [s appendFormat:@"Data path:\n%@\nLog: Anomaly/logs/launch.log\n", root];
    return s;
}

@interface RootVC : UIViewController
@end
@implementation RootVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
    BOOL found = NO;
    NSString *report = BuildReport(&found);
    Log(report);
    UITextView *tv = [[UITextView alloc] initWithFrame:self.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.editable = NO;
    tv.backgroundColor = UIColor.clearColor;
    tv.textColor = found ? [UIColor colorWithRed:0.5 green:1 blue:0.5 alpha:1] : [UIColor colorWithRed:1 green:0.85 blue:0.4 alpha:1];
    tv.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    tv.textContainerInset = UIEdgeInsetsMake(60, 16, 24, 16);
    tv.text = report;
    [self.view addSubview:tv];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [[NSFileManager defaultManager] createDirectoryAtPath:[GameDir() stringByAppendingPathComponent:@"logs"]
                              withIntermediateDirectories:YES attributes:nil error:nil];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [RootVC new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
