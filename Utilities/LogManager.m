// LogManager.m

#import "LogManager.h"

@implementation LogManager

+ (void)log:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64 = [data base64EncodedStringWithOptions:0];
    NSLog(@"[igg] iggxx %@", base64);
}

@end