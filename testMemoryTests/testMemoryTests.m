//
//  testMemoryTests.m
//  testMemoryTests
//
//  Created by 陈宇 on 2017/10/20.
//  Copyright © 2017年 陈宇. All rights reserved.
//

#import <XCTest/XCTest.h>
// stat
#import <sys/stat.h>

// mach
#import <mach/mach.h>

@interface testMemoryTests : XCTestCase
@property (nonatomic, strong) NSMutableArray *array;
@end

@implementation testMemoryTests

- (void)setUp {
    [super setUp];
    self.array = [NSMutableArray array];
}

- (void)tearDown {
    self.array = nil;
    [self printMemory];
    [super tearDown];
}


- (void)testExample1 {
    
    for (int i = 0; i < 1000000; i++) {
        [self.array addObject:@(i)];
    }
}

- (void)testExample2 {
    for (int i = 0; i < 1000000; i++) {
        [self.array addObject:@(i)];
    }
}

- (void)testExample3 {
    for (int i = 0; i < 1000000; i++) {
        [self.array addObject:@(i)];
    }
}


- (void)printMemory {
    NSLog(@"used memory is %f", [self usedMemory]);
}

- (double)usedMemory {
    task_basic_info_data_t taskInfo;
    mach_msg_type_number_t infoCount = TASK_BASIC_INFO_COUNT;
    kern_return_t kernReturn = task_info(mach_task_self(),
                                         TASK_BASIC_INFO,
                                         (task_info_t)&taskInfo,
                                         &infoCount);
    
    if (kernReturn != KERN_SUCCESS) {
        return NSNotFound;
    }
    
    return taskInfo.resident_size / 1024.0 / 1024.0;
}

@end
