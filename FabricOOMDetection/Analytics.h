//
//  Analytics.h
//  FabricOOMDetection
//
//  Created by Prakhar Gupta on 11/1/17.
//  Copyright (c) 2017 Prakhar Gupta. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Analytics : NSObject
+(void)appTerminated;
+(void)appStarted;
+(void)appCrashedOnLastExecution;
+(void)appCameToForeground;
+(void)appWentToBackground;
+(void)recordOutOfMemoryWarning;
+(void)sendOutOfMemoryEvent;
+(NSString *)AppVersion;
+(NSString *)OSVersion;
@end
