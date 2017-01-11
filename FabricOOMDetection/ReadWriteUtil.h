//
//  ReadWriteUtil.h
//  FabricOOMDetection
//
//  Created by Prakhar Gupta on 11/1/17.
//  Copyright (c) 2017 Prakhar Gupta. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ReadWriteUtil : NSObject

+(void) cacheOnDisk:(id)data usingKey:(NSString *)key;

+(id) getFromDiskUsingKey: (NSString *)key;

+(void) deleteDataFromDiskUsingKey:(NSString *)key;
@end
