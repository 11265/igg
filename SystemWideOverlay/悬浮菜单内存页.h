#import <UIKit/UIKit.h>

@interface 悬浮菜单内存页 : UIViewController

@property (nonatomic, assign, readonly) uint64_t currentAddress; // 修改为 readonly
@property (nonatomic, assign) BOOL isHexMode;

- (void)loadInitialMemoryContentAtAddress:(uint64_t)address;
- (void)setupInView:(UIView *)view;
- (void)refreshMemoryContent;
- (void)loadAndDisplayMemoryContentForAddress:(uint64_t)address;

@end
