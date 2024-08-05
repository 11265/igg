// SystemWideOverlay.m

#import "SystemWideOverlay.h"
#import "SystemWideOverlay+Layout.h"
#import "SystemWideOverlay+MenuSetup.h"
#import "Utilities/UIConstants.h"
#import "Utilities/LogManager.h"
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBApplication.h>

@interface SystemWideOverlay () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSTimer *layoutUpdateTimer;

@end

@implementation SystemWideOverlay

+ (instancetype)sharedInstance {
    static SystemWideOverlay *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    [LogManager log:@"Initializing SystemWideOverlay"];

    self.isMenuOpen = NO;
    self.menuContainerView.hidden = YES;

    [self setupWindowProperties];
    [self setupRootViewController];
    [self setupFloatingButton];
    [self setupMenuView];
    [self addSubviews];
    [self makeKeyAndVisible];
    [self registerForNotifications];

    self.desktopBounds = [self getDesktopBounds];
    [self updateLayout];
    [self setupLayoutUpdateTimer];

    [LogManager log:@"SystemWideOverlay initialization completed"];
}

- (void)setupWindowProperties {
    self.windowLevel = UIWindowLevelAlert + 1;
    self.userInteractionEnabled = YES;
    self.hidden = NO;
}

- (void)setupRootViewController {
    UIViewController *rootViewController = [UIViewController new];
    rootViewController.view.backgroundColor = [UIColor clearColor];
    self.rootViewController = rootViewController;
}

- (void)setupFloatingButton {
    CGFloat buttonSize = kFloatingButtonSize * 0.7;
    CGFloat initialX = 40;
    CGFloat initialY = 20;

    self.initialFloatingButtonPosition = CGPointMake(initialX, initialY);

    _floatingButton = [[JHDragView alloc] initWithFrame:CGRectMake(initialX, initialY, buttonSize, buttonSize)];
    _floatingButton.userInteractionEnabled = YES;
    [_floatingButton addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleMenu)]];

    _floatingButton.layer.cornerRadius = buttonSize / 2;
    _floatingButton.clipsToBounds = YES;

    [LogManager log:@"Floating button set up at (%f, %f)", initialX, initialY];
}

- (void)addSubviews {
    [self.rootViewController.view addSubview:self.floatingButton];
    [self.rootViewController.view addSubview:self.menuContainerView];
}

- (void)registerForNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [center addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [LogManager log:@"Notification observers registered"];
}

- (void)setupLayoutUpdateTimer {
    self.layoutUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:kLayoutUpdateInterval
                                                              target:self
                                                            selector:@selector(updateLayoutFromTimer)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)toggleMenu {
    if ([self isOnHomeScreen]) {
        [LogManager log:@"On home screen, menu toggle not allowed"];
        return;
    }

    self.isMenuOpen = !self.isMenuOpen;
    self.menuContainerView.hidden = !self.isMenuOpen;
    [LogManager log:@"Menu toggled - Is open: %@", self.isMenuOpen ? @"Yes" : @"No"];

    if (self.isMenuOpen) {
        [self updateLayout];
    }
}

- (void)closeMenu {
    _isMenuOpen = NO;
    self.menuContainerView.hidden = YES;
    [LogManager log:@"Menu closed"];
}

- (BOOL)isOnHomeScreen {
    // Get the frontmost application
    SBApplication *topApp = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
    // If there's no frontmost application, we're on the home screen
    BOOL isOnHomeScreen = (topApp == nil);
    [LogManager log:@"Is on home screen: %@", isOnHomeScreen ? @"Yes" : @"No"];
    return isOnHomeScreen;
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [LogManager log:@"Application will enter foreground"];
    [self checkAndCloseMenuIfNeeded];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [LogManager log:@"Application did become active"];
    [self checkAndCloseMenuIfNeeded];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [LogManager log:@"Application did enter background"];
    [self closeMenu];
    [self saveCurrentState];
    [self stopOngoingOperations];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [LogManager log:@"Application will resign active"];
}

- (void)saveCurrentState {
    [[NSUserDefaults standardUserDefaults] setInteger:self.currentPageIndex forKey:@"LastPageIndex"];
    [[NSUserDefaults standardUserDefaults] setBool:self.isMenuOpen forKey:@"WasMenuOpen"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [LogManager log:@"Current state saved: Page index %ld, Menu open: %@", (long)self.currentPageIndex, self.isMenuOpen ? @"Yes" : @"No"];
}

- (void)stopOngoingOperations {
    [self.layoutUpdateTimer invalidate];
    self.layoutUpdateTimer = nil;

    [self.floatingButton.layer removeAllAnimations];
    [self.menuContainerView.layer removeAllAnimations];

    [LogManager log:@"All ongoing operations stopped"];
}

- (void)checkAndCloseMenuIfNeeded {
    if ([self isOnHomeScreen] && self.isMenuOpen) {
        [LogManager log:@"On home screen, closing menu"];
        [self closeMenu];
    } else {
        [LogManager log:@"Not on home screen or menu already closed, no action needed"];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateLayout];
    [LogManager log:@"Layout subviews called"];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];

    if (hitView == self.rootViewController.view) {
        [LogManager log:@"Hit test on root view controller view, returning nil"];
        return nil;
    }

    if (hitView == self.floatingButton || [hitView isDescendantOfView:self.floatingButton] ||
        (!self.menuContainerView.hidden && (hitView == self.menuContainerView || [hitView isDescendantOfView:self.menuContainerView]))) {
        [LogManager log:@"Hit test on floating button or menu container"];
        return hitView;
    }

    [LogManager log:@"Hit test returned nil"];
    return nil;
}

- (void)updateLayout {
    [self performLayoutUpdate];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.layoutUpdateTimer invalidate];
    [LogManager log:@"SystemWideOverlay deallocated"];
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
