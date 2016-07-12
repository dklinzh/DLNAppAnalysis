//
//  DLNRunLoopObserver.h
//  DLNAppAnalysis
//
//  Created by Linzh on 5/20/16.
//  Copyright © 2016 Daniel Lin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DLNRunLoopObserver : NSObject
@property (nonatomic, assign) int timeoutMax;
@property (nonatomic, assign) int timeoutNPM;

+ (instancetype)sharedInstance;

- (void)startObserving;
- (void)stopObserving;
@end
