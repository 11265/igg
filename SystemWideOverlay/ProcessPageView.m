// ProcessPageView.m

#import "ProcessPageView.h"
#import "Utilities/LogManager.h"
#import "Crossprocess/ProcessModule.h"
#import "ProcessManager.h"
#import <objc/runtime.h>
#import <sys/types.h>

@interface UITextField (DisableAutomaticKeyboardDismissal)
@end

@implementation UITextField (DisableAutomaticKeyboardDismissal)

- (BOOL)enablesReturnKeyAutomatically {
    return NO;
}

@end

@interface ProcessPageView () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UITextField *searchTextField;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, strong) NSMutableArray *processDataSource;
@property (nonatomic, strong) NSMutableArray *filteredProcessDataSource;

@end

@implementation ProcessPageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupContent];
    }
    return self;
}

- (void)setupContent {
    self.backgroundColor = [UIColor clearColor];
    [LogManager log:@"进程页面已创建"];
    
    self.selectedIndexPath = nil;
    self.processDataSource = [NSMutableArray array];
    self.filteredProcessDataSource = [NSMutableArray array];
    self.selectedPID = 0;
    
    [self setupTopControls];
    [self setupTableView];
    [self loadProcesses];
}

- (void)setupTopControls {
    // 创建容器视图
    UIView *topControlsContainer = [[UIView alloc] init];
    topControlsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:topControlsContainer];

    // 创建标签
    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.infoLabel.textColor = [UIColor whiteColor];
    self.infoLabel.text = @"";
    [topControlsContainer addSubview:self.infoLabel];
    
    // 创建搜索输入框
    self.searchTextField = [[UITextField alloc] init];
    self.searchTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchTextField.placeholder = @"搜索进程";
    self.searchTextField.textColor = [UIColor whiteColor];
    self.searchTextField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    self.searchTextField.layer.cornerRadius = 5.0;
    self.searchTextField.layer.borderWidth = 1.0;
    self.searchTextField.layer.borderColor = [UIColor whiteColor].CGColor;
    self.searchTextField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 30)];
    self.searchTextField.leftViewMode = UITextFieldViewModeAlways;
    self.searchTextField.delegate = self;
    [self.searchTextField addTarget:self action:@selector(searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    
    // 禁用自动更正和自动大写
    self.searchTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    
    // 设置键盘类型和返回键类型
    self.searchTextField.keyboardType = UIKeyboardTypeDefault;
    self.searchTextField.returnKeyType = UIReturnKeyDone;
    
    [topControlsContainer addSubview:self.searchTextField];
    
    // 创建刷新按钮
    self.refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.refreshButton setTitle:@"刷新" forState:UIControlStateNormal];
    [self.refreshButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.refreshButton addTarget:self action:@selector(refreshButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [topControlsContainer addSubview:self.refreshButton];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // 容器视图约束
        [topControlsContainer.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
        [topControlsContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
        [topControlsContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
        [topControlsContainer.heightAnchor constraintEqualToConstant:30],

        // 标签约束
        [self.infoLabel.leadingAnchor constraintEqualToAnchor:topControlsContainer.leadingAnchor],
        [self.infoLabel.centerYAnchor constraintEqualToAnchor:topControlsContainer.centerYAnchor],
        [self.infoLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.searchTextField.leadingAnchor constant:-10],
        
        // 搜索输入框约束
        [self.searchTextField.trailingAnchor constraintEqualToAnchor:self.refreshButton.leadingAnchor constant:-10],
        [self.searchTextField.centerYAnchor constraintEqualToAnchor:topControlsContainer.centerYAnchor],
        [self.searchTextField.heightAnchor constraintEqualToConstant:30],
        [self.searchTextField.widthAnchor constraintEqualToConstant:150],
        
        // 刷新按钮约束
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:topControlsContainer.trailingAnchor],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:topControlsContainer.centerYAnchor],
        [self.refreshButton.widthAnchor constraintEqualToConstant:60]
    ]];
}

- (void)setupTableView {
    // 创建列表框
    self.tableView = [[UITableView alloc] init];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ProcessCell"];
    [self addSubview:self.tableView];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchTextField.bottomAnchor constant:10],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

- (void)refreshButtonTapped {
    [LogManager log:@"刷新按钮被点击"];
    self.infoLabel.text = @"正在刷新...";
    [self loadProcesses];
}

- (void)loadProcesses {
    size_t count = 0;
    ProcessInfo *processInfoArray = enumprocess_native(&count);
    
    if (processInfoArray) {
        [self.processDataSource removeAllObjects];
        
        for (size_t i = 0; i < count; i++) {
            NSString *processInfo = [NSString stringWithFormat:@"PID: %d - %s", 
                                     processInfoArray[i].pid, 
                                     processInfoArray[i].processname];
            [self.processDataSource addObject:processInfo];
            
            free((void *)processInfoArray[i].processname);
        }
        
        free(processInfoArray);
        
        self.selectedIndexPath = nil;
        self.selectedPID = 0;
        [ProcessManager sharedManager].selectedPID = 0;
        self.filteredProcessDataSource = [self.processDataSource mutableCopy];
        [self.tableView reloadData];
        
        self.infoLabel.text = [NSString stringWithFormat:@"获取到 %lu 个进程", (unsigned long)self.processDataSource.count];
    } else {
        [LogManager log:@"枚举进程失败"];
        self.infoLabel.text = @"刷新失败";
    }
}

- (void)searchTextChanged:(UITextField *)textField {
    NSString *searchText = textField.text;
    if (searchText.length == 0) {
        self.filteredProcessDataSource = [self.processDataSource mutableCopy];
    } else {
        self.filteredProcessDataSource = [[self.processDataSource filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *processInfo, NSDictionary *bindings) {
            return [processInfo localizedCaseInsensitiveContainsString:searchText];
        }]] mutableCopy];
    }
    [self.tableView reloadData];
    
    self.infoLabel.text = [NSString stringWithFormat:@"显示 %lu 个进程", (unsigned long)self.filteredProcessDataSource.count];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredProcessDataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ProcessCell" forIndexPath:indexPath];
    
    cell.textLabel.text = self.filteredProcessDataSource[indexPath.row];
    cell.textLabel.textColor = [UIColor whiteColor];
    
    if ([indexPath isEqual:self.selectedIndexPath]) {
        cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.backgroundColor = [UIColor clearColor];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSIndexPath *oldIndexPath = self.selectedIndexPath;

    if ([indexPath isEqual:self.selectedIndexPath]) {
        self.selectedIndexPath = nil;
        self.selectedPID = 0;
        [ProcessManager sharedManager].selectedPID = 0;
        self.infoLabel.text = [NSString stringWithFormat:@"显示 %lu 个进程", (unsigned long)self.filteredProcessDataSource.count];
    } else {
        self.selectedIndexPath = indexPath;
        NSString *selectedProcessInfo = self.filteredProcessDataSource[indexPath.row];
        self.infoLabel.text = selectedProcessInfo;
        
        // 从选中的进程信息中提取 PID
        NSScanner *scanner = [NSScanner scannerWithString:selectedProcessInfo];
        [scanner scanString:@"PID: " intoString:nil];
        int pid;
        if ([scanner scanInt:&pid]) {
            self.selectedPID = (pid_t)pid;
            [ProcessManager sharedManager].selectedPID = (int32_t)pid;
        }
    }

    NSMutableArray *indexPathsToReload = [NSMutableArray array];
    if (oldIndexPath) {
        [indexPathsToReload addObject:oldIndexPath];
    }
    if (self.selectedIndexPath) {
        [indexPathsToReload addObject:self.selectedIndexPath];
    }

    [tableView reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationFade];

    if (self.selectedIndexPath) {
        [LogManager log:@"选中了进程: %@, PID: %d", self.filteredProcessDataSource[self.selectedIndexPath.row], self.selectedPID];
    } else {
        [LogManager log:@"取消了选中"];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

// 确保视图保持在当前方向
- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    if (newWindow) {
        UIViewController *viewController = [self findViewController];
        if (viewController) {
            viewController.modalPresentationStyle = UIModalPresentationFullScreen;
            viewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        }
    }
}

- (UIViewController *)findViewController {
    UIResponder *responder = self;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

- (int32_t)getSelectedPID {
    return (int32_t)self.selectedPID;
}

@end