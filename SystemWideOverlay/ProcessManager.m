// ProcessManager.m
#import "ProcessManager.h"

@implementation ProcessManager

+ (instancetype)sharedManager {
    static ProcessManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

@end