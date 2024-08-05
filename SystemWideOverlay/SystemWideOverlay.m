// SystemWideOverlay.m

#import "SystemWideOverlay.h"
#import "SystemWideOverlay+Layout.h"
#import "SystemWideOverlay+MenuSetup.h"
#import "Utilities/UIConstants.h"
#import "Utilities/LogManager.h"
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBApplication.h>

@interface SystemWideOverlay ()

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

@end