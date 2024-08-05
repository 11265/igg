// SystemWideOverlay+MenuSetup.m

#import "SystemWideOverlay+MenuSetup.h"
#import "Utilities/UIConstants.h"
#import "Utilities/LogManager.h"
#import "Crossprocess/ProcessModule.h"

@implementation SystemWideOverlay (MenuSetup)

- (void)setupMenuView {
    CGRect screenBounds = [UIScreen mainScreen].bounds;

    self.menuContainerView = [[UIView alloc] initWithFrame:screenBounds];
    self.menuContainerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    self.menuContainerView.hidden = YES;

    [self setupTopBar:screenBounds];
    [self setupContentView:screenBounds];

    [LogManager log:@"Menu view setup completed"];
}

- (void)setupTopBar:(CGRect)screenBounds {
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenBounds.size.width, kTopBarHeight)];
    topBar.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    [self.menuContainerView addSubview:topBar];

    [self setupTopBarButtons:topBar];
}

- (void)setupTopBarButtons:(UIView *)topBar {
    NSArray *titles = @[@"进程", @"搜索", @"记录", @"内存", @"配置", @"x"];
    CGFloat buttonWidth = topBar.bounds.size.width / titles.count;

    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14];
        button.frame = CGRectMake(i * buttonWidth, 0, buttonWidth, kTopBarHeight);
        [button addTarget:self action:@selector(topBarButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        button.tag = i;
        [topBar addSubview:button];
    }
}

- (void)setupContentView:(CGRect)screenBounds {
    CGRect contentFrame = CGRectMake(0, kTopBarHeight, screenBounds.size.width, screenBounds.size.height - kTopBarHeight);
    self.contentView = [[UIView alloc] initWithFrame:contentFrame];
    [self.menuContainerView addSubview:self.contentView];

    [self setupPageViews];
}

- (void)setupPageViews {
    self.pageViews = @[
        [self createPageViewWithFrame:self.contentView.bounds title:@"进程"],
        [self createPageViewWithFrame:self.contentView.bounds title:@"搜索"],
        [self createPageViewWithFrame:self.contentView.bounds title:@"记录"],
        [self createPageViewWithFrame:self.contentView.bounds title:@"内存"],
        [self createPageViewWithFrame:self.contentView.bounds title:@"配置"]
    ];

    for (UIView *pageView in self.pageViews) {
        [self.contentView addSubview:pageView];
    }

    self.currentPageIndex = 0;
    [self updatePageVisibility];
    [self updateTopBarButtonsAppearance];
}

- (void)updatePageVisibility {
    for (NSUInteger i = 0; i < self.pageViews.count; i++) {
        self.pageViews[i].hidden = (i != self.currentPageIndex);
    }
    [LogManager log:@"Updated page visibility for index %ld", (long)self.currentPageIndex];
}

- (void)updateTopBarButtonsAppearance {
    UIView *topBar = self.menuContainerView.subviews.firstObject;
    for (UIButton *button in topBar.subviews) {
        if ([button isKindOfClass:[UIButton class]]) {
            BOOL isSelected = (button.tag == self.currentPageIndex);
            button.backgroundColor = isSelected ? [UIColor colorWithRed:0.455 green:0.792 blue:0.933 alpha:1.0] : [UIColor clearColor]; // #74CAEC
            [button setTitleColor:isSelected ? [UIColor whiteColor] : [UIColor whiteColor] forState:UIControlStateNormal];
            button.titleLabel.font = isSelected ? [UIFont boldSystemFontOfSize:16] : [UIFont systemFontOfSize:16];
        }
    }
    [LogManager log:@"Updated top bar buttons appearance"];
}

- (UIView *)createPageViewWithFrame:(CGRect)frame title:(NSString *)title {
    UIView *pageView = [[UIView alloc] initWithFrame:frame];
    pageView.backgroundColor = [UIColor clearColor];
    pageView.accessibilityIdentifier = title; // 设置访问标识符

    if ([title isEqualToString:@"配置"]) {
        [self addSettingsContent:pageView];
    } else if ([title isEqualToString:@"搜索"]) {
        [self addSearchContent:pageView];
    } else if ([title isEqualToString:@"进程"]) {
        [self addProcessContent:pageView];
    }

    return pageView;
}

- (void)addSettingsContent:(UIView *)pageView {
    NSArray *settingTitles = @[@"选项 1", @"选项 2", @"选项 3"];
    for (NSInteger i = 0; i < settingTitles.count; i++) {
        UILabel *settingLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 70 + i * 40, 150, 30)];
        settingLabel.text = settingTitles[i];
        settingLabel.textColor = [UIColor whiteColor];
        [pageView addSubview:settingLabel];

        UISwitch *settingSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, 70 + i * 40, 51, 31)];
        [pageView addSubview:settingSwitch];
    }
}

- (void)addSearchContent:(UIView *)pageView {
    for (UIView *subview in pageView.subviews) {
        [subview removeFromSuperview];
    }

    UIView *buttonContainer = [[UIView alloc] init];
    buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [pageView addSubview:buttonContainer];

    [NSLayoutConstraint activateConstraints:@[
        [buttonContainer.topAnchor constraintEqualToAnchor:pageView.topAnchor],
        [buttonContainer.leadingAnchor constraintEqualToAnchor:pageView.leadingAnchor],
        [buttonContainer.trailingAnchor constraintEqualToAnchor:pageView.trailingAnchor],
        [buttonContainer.heightAnchor constraintEqualToConstant:40]
    ]];

    NSMutableArray *buttons = [NSMutableArray array];
    for (int i = 0; i < 6; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setTitle:[NSString stringWithFormat:@"%d", i + 1] forState:UIControlStateNormal];
        button.backgroundColor = [UIColor colorWithRed:0.392 green:0.647 blue:0.812 alpha:1.0]; // #64A5CF
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.layer.cornerRadius = 8;
        button.clipsToBounds = YES;
        button.tag = i + 1;
        [button addTarget:self action:@selector(searchButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        [buttonContainer addSubview:button];
        [buttons addObject:button];
    }

    UIButton *previousButton = nil;
    for (UIButton *button in buttons) {
        [NSLayoutConstraint activateConstraints:@[
            [button.topAnchor constraintEqualToAnchor:buttonContainer.topAnchor constant:2],
            [button.bottomAnchor constraintEqualToAnchor:buttonContainer.bottomAnchor constant:-2]
        ]];

        if (previousButton) {
            [button.widthAnchor constraintEqualToAnchor:previousButton.widthAnchor].active = YES;
            [button.leadingAnchor constraintEqualToAnchor:previousButton.trailingAnchor constant:5].active = YES;
        } else {
            [button.leadingAnchor constraintEqualToAnchor:buttonContainer.leadingAnchor constant:5].active = YES;
        }

        if (button == buttons.lastObject) {
            [button.trailingAnchor constraintEqualToAnchor:buttonContainer.trailingAnchor constant:-5].active = YES;
        }

        previousButton = button;
    }

    UITableView *tableView = [[UITableView alloc] init];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.backgroundColor = [UIColor clearColor];
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.rowHeight = 33;
    [pageView addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:buttonContainer.bottomAnchor constant:10],
        [tableView.leadingAnchor constraintEqualToAnchor:pageView.leadingAnchor constant:10],
        [tableView.trailingAnchor constraintEqualToAnchor:pageView.trailingAnchor constant:-10],
        [tableView.bottomAnchor constraintEqualToAnchor:pageView.bottomAnchor constant:-10]
    ]];

    tableView.dataSource = self;
    tableView.delegate = self;

    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SearchCell"];

    // 添加长按手势识别器
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPressGesture.minimumPressDuration = 0.5; // 设置长按时间为0.5秒
    [tableView addGestureRecognizer:longPressGesture];
}

- (void)addProcessContent:(UIView *)pageView {
    // 清除页面中的所有子视图
    for (UIView *subview in pageView.subviews) {
        [subview removeFromSuperview];
    }

    // 创建方形按钮
    UIButton *squareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    squareButton.frame = CGRectMake(50, 50, 100, 100); // 设置按钮的位置和大小
    squareButton.backgroundColor = [UIColor blueColor]; // 设置按钮的背景颜色
    [squareButton setTitle:@"方形按钮" forState:UIControlStateNormal]; // 设置按钮的标题
    [squareButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; // 设置按钮标题的颜色
    squareButton.layer.cornerRadius = 8; // 设置按钮的圆角半径
    squareButton.clipsToBounds = YES; // 确保按钮的圆角效果
    [squareButton addTarget:self action:@selector(squareButtonTapped:) forControlEvents:UIControlEventTouchUpInside]; // 设置按钮的点击事件

    // 将按钮添加到页面视图中
    [pageView addSubview:squareButton];
}

- (UIView *)createCustomAlertViewWithTitle:(NSString *)title message:(NSString *)message {
    UIView *alertView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 150)];
    alertView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
    alertView.layer.cornerRadius = 10;
    alertView.userInteractionEnabled = YES;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 230, 30)];
    titleLabel.text = title;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [alertView addSubview:titleLabel];

    UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 230, 50)];
    messageLabel.text = message;
    messageLabel.textColor = [UIColor whiteColor];
    messageLabel.textAlignment = NSTextAlignmentCenter;
    messageLabel.numberOfLines = 0;
    [alertView addSubview:messageLabel];

    UIButton *okButton = [UIButton buttonWithType:UIButtonTypeSystem];
    okButton.frame = CGRectMake(75, 110, 100, 30);
    [okButton setTitle:@"确定" forState:UIControlStateNormal];
    [okButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [okButton addTarget:self action:@selector(dismissCustomAlert:) forControlEvents:UIControlEventTouchUpInside];
    [alertView addSubview:okButton];

    return alertView;
}

- (void)topBarButtonTapped:(UIButton *)sender {
    [LogManager log:@"Top bar button tapped with tag: %ld", (long)sender.tag];
    if (sender.tag == 5) {
        [self closeMenuFromCategory];
    } else {
        self.currentPageIndex = sender.tag;
        [self updatePageVisibility];
        [self updateTopBarButtonsAppearance];
    }
}

- (void)dismissCustomAlert:(UIButton *)sender {
    [sender.superview removeFromSuperview];
}

- (void)searchButtonTapped:(UIButton *)sender {
    [LogManager log:@"搜索按钮被点击: %ld", (long)sender.tag];
}

- (void)squareButtonTapped:(UIButton *)sender {
    [LogManager log:@"方形按钮被点击"];
    // 在这里添加按钮点击事件的处理逻辑
}

- (void)closeMenuFromCategory {
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

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 20;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SearchCell" forIndexPath:indexPath];

    cell.textLabel.text = [NSString stringWithFormat:@"搜索结果 %ld", (long)indexPath.row + 1];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Remove the default selection style
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    // Set the background color of the cell
    cell.backgroundColor = [UIColor clearColor];

    // Update the text color and font size
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont systemFontOfSize:14]; // Increased font size for better readability

    // Add a custom selected background view
    UIView *selectedBackgroundView = [[UIView alloc] init];
    selectedBackgroundView.backgroundColor = [UIColor colorWithRed:0.455 green:0.792 blue:0.933 alpha:1.0]; // #74CAEC
    cell.selectedBackgroundView = selectedBackgroundView;
}

- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.contentView.backgroundColor = [UIColor colorWithRed:0.455 green:0.792 blue:0.933 alpha:1.0]; // #74CAEC
    cell.textLabel.textColor = [UIColor whiteColor]; // 确保文字在高亮状态下仍然可见
}

- (void)tableView:(UITableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = [UIColor whiteColor];
}

// 新添加的长按手势处理方法
- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gestureRecognizer locationInView:gestureRecognizer.view];
        NSIndexPath *indexPath = [(UITableView *)gestureRecognizer.view indexPathForRowAtPoint:point];

        if (indexPath) {
            [LogManager log:@"长按了搜索结果 %ld", (long)indexPath.row + 1];

            UIView *alertView = [self createCustomAlertViewWithTitle:@"搜索结果"
                                                             message:[NSString stringWithFormat:@"你长按了搜索结果 %ld", (long)indexPath.row + 1]];

            alertView.center = self.menuContainerView.center;
            [self.menuContainerView addSubview:alertView];

            // 确保 menuContainerView 可以接收用户交互
            self.menuContainerView.userInteractionEnabled = YES;
        }
    }
}

@end
