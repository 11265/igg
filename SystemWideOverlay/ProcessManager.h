// ProcessManager.h
#import <Foundation/Foundation.h>

@interface ProcessManager : NSObject

@property (nonatomic, assign) int32_t selectedPID;

+ (instancetype)sharedManager;

@end