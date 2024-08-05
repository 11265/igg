// SystemWideOverlay+MenuSetup.h

#import "SystemWideOverlay.h"

@interface SystemWideOverlay (MenuSetup)

- (void)setupMenuView;
- (void)setupTopBar:(CGRect)screenBounds;
- (void)setupTopBarButtons:(UIView *)topBar;
- (void)setupContentView:(CGRect)screenBounds;
- (void)setupPageViews;
- (void)updatePageVisibility;
- (void)updateTopBarButtonsAppearance;
- (UIView *)createPageViewWithFrame:(CGRect)frame title:(NSString *)title;
- (void)addSettingsContent:(UIView *)pageView;
- (void)addSearchContent:(UIView *)pageView;
- (void)addProcessContent:(UIView *)pageView; // 添加这一行
- (UIView *)createCustomAlertViewWithTitle:(NSString *)title message:(NSString *)message;
- (void)topBarButtonTapped:(UIButton *)sender;
- (void)dismissCustomAlert:(UIButton *)sender;
- (void)searchButtonTapped:(UIButton *)sender;
- (void)squareButtonTapped:(UIButton *)sender;
- (void)closeMenuFromCategory;

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer;

@end
