// ProcessPageView.h

#import <UIKit/UIKit.h>

@interface ProcessPageView : UIView

@property (nonatomic, assign) mach_port_t selectedTaskPort;
@property (nonatomic, assign) pid_t selectedPID;
- (instancetype)initWithFrame:(CGRect)frame;
- (int32_t)getSelectedPID;

@end