// LogManager.h

#import <Foundation/Foundation.h>

@interface LogManager : NSObject

+ (void)log:(NSString *)format, ...;

@end