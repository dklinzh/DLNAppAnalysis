//
//  DLNRunLoopObserver.m
//  DLNAppAnalysis
//
//  Created by Linzh on 5/20/16.
//  Copyright © 2016 Daniel Lin. All rights reserved.
//

#import "DLNRunLoopObserver.h"
#import <CrashReporter/CrashReporter.h>

#define DEFAULT_TIMEOUT_MAX 5
#define DEFAULT_TIMEOUT_NSEC_PER_MSEC 50

@interface DLNRunLoopObserver ()
{
    CFRunLoopObserverRef observer;
    CFRunLoopActivity activity;
    dispatch_semaphore_t semaphore;
    
    int timeoutCount;
}
@end

@implementation DLNRunLoopObserver
static DLNRunLoopObserver *sharedInstance = nil;

#pragma mark - Override
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        sharedInstance = [super allocWithZone:zone];
    });
    return sharedInstance;
}

#pragma mark - Public
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!sharedInstance) {
            sharedInstance = [[self alloc] init];
        }
    });
    return sharedInstance;
}

- (void)startObserving {
    if (observer) {
        return;
    }
    
    semaphore = dispatch_semaphore_create(0);
    CFRunLoopObserverContext context = {0, (__bridge void*)self, NULL, NULL};
    observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                       kCFRunLoopAllActivities,
                                       YES,
                                       0,
                                       &runLoopObserverCallBack,
                                       &context);
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (YES) {
            long st = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC));
            if (st != 0) {
                if (!observer) {
                    timeoutCount = 0;
                    semaphore = 0;
                    activity = 0;
                    return;
                }
                
                if (activity == kCFRunLoopBeforeSources || activity == kCFRunLoopAfterWaiting) {
                    if (++timeoutCount < self.timeoutMax) {
                        continue;
                    }
                    
                    //https://github.com/plausiblelabs/plcrashreporter
                    PLCrashReporterConfig *reporterConfig = [[PLCrashReporterConfig alloc] initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeBSD symbolicationStrategy:PLCrashReporterSymbolicationStrategyAll];
                    PLCrashReporter *crashReporter = [[PLCrashReporter alloc] initWithConfiguration:reporterConfig];
                    PLCrashReport *report = [[PLCrashReport alloc] initWithData:[crashReporter generateLiveReport] error:NULL];
                    NSString *reportText = [PLCrashReportTextFormatter stringValueForCrashReport:report withTextFormat:PLCrashReportTextFormatiOS];
                    NSLog(@"---DULL---DULL---DULL---");
                    NSLog(@"%@", reportText);
                    NSLog(@"---DULL---DULL---DULL---");
                }
            }
            timeoutCount = 0;
        }
    });
}

- (void)stopObserving {
    if (!observer) {
        return;
    }
    
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    CFRelease(observer);
    observer = NULL;
}

#pragma mark - Private
static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    DLNRunLoopObserver *dlnObserver = (__bridge DLNRunLoopObserver *)info;
    dlnObserver->activity = activity;
    
    dispatch_semaphore_t semaphore = dlnObserver->semaphore;
    dispatch_semaphore_signal(semaphore);
}

#pragma mark - G/S
- (int)timeoutMax {
    if (_timeoutMax) {
        return _timeoutMax;
    }
    return DEFAULT_TIMEOUT_MAX;
}

- (int)timeoutNPM {
    if (_timeoutNPM) {
        return _timeoutNPM;
    }
    return DEFAULT_TIMEOUT_NSEC_PER_MSEC;
}
@end
