//
//  Analytics.m
//  FabricOOMDetection
//
//  Created by Prakhar Gupta on 11/1/17.
//  Copyright (c) 2017 Prakhar Gupta. All rights reserved.
//

#import "Analytics.h"
#import "mach/mach.h"
#import <Crashlytics/Answers.h>
#import <Crashlytics/Crashlytics.h>
#import "ReadWriteUtil.h"

#define OOM_DATA_KEY @"oom_custom_data"
#define OOM_APP_VER_KEY @"oom_app_ver"
#define OOM_OS_VER_KEY @"oom_os_ver"
#define APP_IN_BACKGROUND_KEY @"app_background"
#define APP_TERMINATED_KEY @"app_terminated"

static BOOL crashedOnLastRun;
static double timeInAppSinceFirstAppLaunch;
static NSDate *lastForegroundDate;
static NSDate *firstLaunchDate;
static int numberOfForegrounds;

vm_size_t usedResidentMemory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0; // size in bytes
}

vm_size_t usedVirtualMemory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    return (kerr == KERN_SUCCESS) ? info.virtual_size : 0; // size in bytes
}

vm_size_t freeMemory(void) {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;
    
    host_page_size(host_port, &pagesize);
    (void) host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
    return vm_stat.free_count * pagesize;
}

float cpu_usage()
{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    
    task_basic_info_t      basic_info;
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;
    
    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;
    
    thread_basic_info_t basic_info_th;
    uint32_t stat_thread = 0; // Mach threads
    
    basic_info = (task_basic_info_t)tinfo;
    
    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (thread_count > 0)
        stat_thread += thread_count;
    
    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    int j;
    
    for (j = 0; j < thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }
        
        basic_info_th = (thread_basic_info_t)thinfo;
        
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->user_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }
        
    } // for each thread
    
    kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    assert(kr == KERN_SUCCESS);
    
    return tot_cpu;
}

@implementation Analytics

+(void)appCrashedOnLastExecution
{
    crashedOnLastRun=YES;
}

+(void)recordOutOfMemoryWarning
{
    NSMutableDictionary *customData = [[NSMutableDictionary alloc] init];
    
    [customData setValue:[NSNumber numberWithFloat: usedResidentMemory()/1024.0f] forKey:@"currentResidentMemory"];
    [customData setValue:[NSNumber numberWithFloat: usedVirtualMemory()/1024.0f] forKey:@"currentVirtualMemory"];
    [customData setValue:[NSNumber numberWithFloat:freeMemory()/1024.0f] forKey:@"freeMemory"];
    [customData setValue:[NSNumber numberWithFloat:cpu_usage()] forKey:@"cpuUsage"];
    [customData setValue:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceDate:firstLaunchDate]/3600.0f] forKey:@"hoursSinceLaunch"];
    double totalTimeInAppSinceLaunch = timeInAppSinceFirstAppLaunch + [[NSDate date] timeIntervalSinceDate:lastForegroundDate];
    [customData setValue:[NSNumber numberWithDouble:totalTimeInAppSinceLaunch] forKey:@"secondsInAppSinceLaunch"];
    [customData setValue:[NSNumber numberWithInt:numberOfForegrounds] forKey:@"cameToForegroundCount"];
    
    [ReadWriteUtil cacheOnDisk:customData usingKey:OOM_DATA_KEY];
    [ReadWriteUtil cacheOnDisk:[Analytics OSVersion] usingKey:OOM_OS_VER_KEY];
    [ReadWriteUtil cacheOnDisk:[Analytics AppVersion] usingKey:OOM_APP_VER_KEY];
    
    [Answers logCustomEventWithName:@"OutOfMemoryWarning" customAttributes:customData];
    NSError *err = [[NSError alloc] initWithDomain:@"OutOfMemoryWarning" code:666 userInfo:customData];
    [CrashlyticsKit recordError:err];
}

+(void)sendOutOfMemoryEvent
{
    NSMutableDictionary *customData = [ReadWriteUtil getFromDiskUsingKey:OOM_DATA_KEY];
    if(customData)
    {
        NSString *prevOsVer = [ReadWriteUtil getFromDiskUsingKey:OOM_OS_VER_KEY];
        NSString *prevAppVer = [ReadWriteUtil getFromDiskUsingKey:OOM_APP_VER_KEY];
        BOOL appInBackgroundLastTime = [[ReadWriteUtil getFromDiskUsingKey:APP_IN_BACKGROUND_KEY] boolValue];
        BOOL appWasTerminatedLastTime = [[ReadWriteUtil getFromDiskUsingKey:APP_TERMINATED_KEY] boolValue];
        
        if([prevOsVer isEqualToString:[Analytics OSVersion]] && [prevAppVer isEqualToString:[Analytics AppVersion]] &&
           crashedOnLastRun==NO && appInBackgroundLastTime==NO && appWasTerminatedLastTime==NO)
        {
            [Answers logCustomEventWithName:@"OutOfMemoryEvent" customAttributes:customData];
            NSError *err = [[NSError alloc] initWithDomain:@"OutOfMemoryEvent" code:999 userInfo:customData];
            [CrashlyticsKit recordError:err];
        }
    }
    [ReadWriteUtil deleteDataFromDiskUsingKey:OOM_APP_VER_KEY];
    [ReadWriteUtil deleteDataFromDiskUsingKey:OOM_OS_VER_KEY];
    [ReadWriteUtil deleteDataFromDiskUsingKey:OOM_DATA_KEY];
    [ReadWriteUtil deleteDataFromDiskUsingKey:APP_TERMINATED_KEY];
    [ReadWriteUtil deleteDataFromDiskUsingKey:APP_IN_BACKGROUND_KEY];
}

+(void)appStarted
{
    [Analytics sendOutOfMemoryEvent];
    [Analytics appCameToForeground];
    firstLaunchDate = [NSDate date];
}

+(void)appTerminated
{
    [ReadWriteUtil cacheOnDisk:[NSNumber numberWithBool:YES] usingKey:APP_TERMINATED_KEY];
}

+(void)appCameToForeground
{
    lastForegroundDate = [NSDate date];
    numberOfForegrounds +=1;
    [ReadWriteUtil deleteDataFromDiskUsingKey:APP_IN_BACKGROUND_KEY];
}

+(void)appWentToBackground
{
    timeInAppSinceFirstAppLaunch += [[NSDate date] timeIntervalSinceDate:lastForegroundDate];
    [ReadWriteUtil cacheOnDisk:[NSNumber numberWithBool:YES] usingKey:APP_IN_BACKGROUND_KEY];
}

+ (NSString *)AppVersion
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+ (NSString *)OSVersion
{
    return [[UIDevice currentDevice] systemVersion];
}
@end
