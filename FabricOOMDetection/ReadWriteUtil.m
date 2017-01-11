//
//  ReadWriteUtil.m
//  FabricOOMDetection
//
//  Created by Prakhar Gupta on 11/1/17.
//  Copyright (c) 2017 Prakhar Gupta. All rights reserved.
//

#import "ReadWriteUtil.h"

@implementation ReadWriteUtil

+(void) cacheOnDisk:(id) data usingKey:(NSString *)key
{
    if(data==nil)
    {
        [ReadWriteUtil deleteDataFromDiskUsingKey:key];
    }
    else
    {
        NSData *archivedData=[NSKeyedArchiver archivedDataWithRootObject:data];
        [[NSUserDefaults standardUserDefaults] setObject:archivedData forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+(id) getFromDiskUsingKey: (NSString *)key
{
    NSData *savedData = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (savedData!=nil)
    {
        id returnData = [NSKeyedUnarchiver unarchiveObjectWithData:savedData];
        return returnData;
    }
    else
    {
        return nil;
    }
}
+(void) deleteDataFromDiskUsingKey:(NSString *)key
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end
