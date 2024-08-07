// SystemWideOverlay+MenuSetup.m

#import "SystemWideOverlay+MenuSetup.h" // 导入头文件
#import "Utilities/UIConstants.h" // 导入UI常量
#import "Utilities/LogManager.h" // 导入日志管理器
#import "Crossprocess/ProcessModule.h" // 导入进程模块

#import "ProcessPageView.h"
#import "SearchPageView.h"
#import "LogPageView.h"
#import "MemoryPageView.h"
#import "SettingsPageView.h"

@implementation SystemWideOverlay (MenuSetup) // 实现SystemWideOverlay的MenuSetup分类

- (void)setupMenuView { // 设置菜单视图
    CGRect screenBounds = [UIScreen mainScreen].bounds; // 获取屏幕边界
    
    self.menuContainerView = [[UIView alloc] initWithFrame:screenBounds]; // 创建菜单容器视图
    self.menuContainerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9]; // 设置背景颜色
    self.menuContainerView.hidden = YES; // 初始时隐藏菜单
    
    [self setupTopBar:screenBounds]; // 设置顶部栏
    [self setupContentView:screenBounds]; // 设置内容视图
    
    [LogManager log:@"Menu view setup completed"]; // 记录日志
}

- (void)setupTopBar:(CGRect)screenBounds { // 设置顶部栏
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenBounds.size.width, kTopBarHeight)]; // 创建顶部栏视图
    topBar.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0]; // 设置背景颜色
    [self.menuContainerView addSubview:topBar]; // 添加到菜单容器
    
    [self setupTopBarButtons:topBar]; // 设置顶部栏按钮
}

- (void)setupTopBarButtons:(UIView *)topBar { // 设置顶部栏按钮
    NSArray *titles = @[@"进程", @"搜索", @"记录", @"内存", @"配置", @"X"]; // 按钮标题数组
    CGFloat buttonWidth = topBar.bounds.size.width / titles.count; // 计算按钮宽度

    for (NSInteger i = 0; i < titles.count; i++) { // 遍历创建按钮
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom]; // 创建自定义按钮
        [button setTitle:titles[i] forState:UIControlStateNormal]; // 设置按钮标题
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; // 设置标题颜色
        button.titleLabel.font = [UIFont systemFontOfSize:14]; // 设置字体
        button.frame = CGRectMake(i * buttonWidth, 0, buttonWidth, kTopBarHeight); // 设置按钮位置和大小
        [button addTarget:self action:@selector(topBarButtonTapped:) forControlEvents:UIControlEventTouchUpInside]; // 添加点击事件
        button.tag = i; // 设置按钮标签
        [topBar addSubview:button]; // 添加按钮到顶部栏
    }
}


- (void)setupContentView:(CGRect)screenBounds { // 设置内容视图
    CGRect contentFrame = CGRectMake(0, kTopBarHeight, screenBounds.size.width, screenBounds.size.height - kTopBarHeight); // 计算内容视图框架
    self.contentView = [[UIView alloc] initWithFrame:contentFrame]; // 创建内容视图
    [self.menuContainerView addSubview:self.contentView]; // 添加到菜单容器
    
    [self setupPageViews]; // 设置页面视图
}

- (void)setupPageViews {
    self.pageViews = @[
        [[ProcessPageView alloc] initWithFrame:self.contentView.bounds],
        [[SearchPageView alloc] initWithFrame:self.contentView.bounds],
        [[LogPageView alloc] initWithFrame:self.contentView.bounds],
        [[MemoryPageView alloc] initWithFrame:self.contentView.bounds],
        [[SettingsPageView alloc] initWithFrame:self.contentView.bounds]
    ];

    for (UIView *pageView in self.pageViews) {
        [self.contentView addSubview:pageView];
    }

    self.currentPageIndex = 0;
    [self updatePageVisibility];
    [self updateTopBarButtonsAppearance];
}

- (void)updatePageVisibility { // 更新页面可见性
    for (NSUInteger i = 0; i < self.pageViews.count; i++) {
        self.pageViews[i].hidden = (i != self.currentPageIndex); // 隐藏非当前页面
    }
    [LogManager log:@"Updated page visibility for index %ld", (long)self.currentPageIndex]; // 记录日志
}

- (void)updateTopBarButtonsAppearance { // 更新顶部栏按钮外观
    UIView *topBar = self.menuContainerView.subviews.firstObject; // 获取顶部栏视图
    for (UIButton *button in topBar.subviews) {
        if ([button isKindOfClass:[UIButton class]]) {
            BOOL isSelected = (button.tag == self.currentPageIndex); // 判断是否为当前选中按钮
            [button setTitleColor:isSelected ? [UIColor yellowColor] : [UIColor whiteColor] forState:UIControlStateNormal]; // 设置标题颜色
            button.titleLabel.font = isSelected ? [UIFont boldSystemFontOfSize:16] : [UIFont systemFontOfSize:16]; // 设置字体
        }
    }
    [LogManager log:@"Updated top bar buttons appearance"]; // 记录日志
}

- (void)topBarButtonTapped:(UIButton *)sender {
    [LogManager log:@"Top bar button tapped with tag: %ld", (long)sender.tag];
    if (sender.tag == 5) { // "X" 按钮的标签
        [self closeMenuFromCategory];
    } else {
        self.currentPageIndex = sender.tag;
        [self updatePageVisibility];
        [self updateTopBarButtonsAppearance];
    }
}

- (void)closeMenuFromCategory {
    // 关闭菜单的动画
    [UIView animateWithDuration:0.3 animations:^{
        self.menuContainerView.alpha = 0;
    } completion:^(BOOL finished) {
        self.menuContainerView.hidden = YES;
        self.menuContainerView.alpha = 1;
        [self removeFromSuperview];
        self.isMenuOpen = NO;  // 使用属性访问器
    }];
    [LogManager log:@"Menu closed from category, is open: %@", self.isMenuOpen ? @"Yes" : @"No"];
}

@end

