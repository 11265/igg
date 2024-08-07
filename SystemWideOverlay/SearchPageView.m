// SearchPageView.m

#import "SearchPageView.h"
#import "Utilities/LogManager.h"
#import "Crossprocess/ProcessModule.h"
#import "ProcessPageView.h"
#import "ProcessManager.h"

@interface SearchPageView () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, assign) pid_t selectedPID;  // 添加这个属性

@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *modifyAllButton;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *fuzzyButton;
@property (nonatomic, strong) UITableView *listTableView;

@end

@implementation SearchPageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupContent];
    }
    return self;
}

- (void)setupContent {
    self.backgroundColor = [UIColor clearColor];
    
    [self createCountLabel];
    [self createButtons];
    [self createTableView];
    [self setupConstraints];
    
    // 添加一些示例数据
    self.dataSource = @[@"项目1", @"项目2", @"项目3", @"项目4", @"项目5"];
    
    [self updateLayout];
    [LogManager log:@"搜索页面已创建"];
}

- (void)createCountLabel {
    self.countLabel = [[UILabel alloc] init];
    self.countLabel.text = @"名称数量: 0";
    self.countLabel.font = [UIFont systemFontOfSize:14];
    self.countLabel.textColor = [UIColor whiteColor];
    self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.countLabel];
}

- (void)createButtons {
    NSArray *buttonTitles = @[@"选择", @"清除", @"保存", @"修改所有", @"搜索", @"模糊"];
    NSArray *buttonSelectors = @[@"selectAction:", @"clearAction:", @"saveAction:", @"modifyAllAction:", @"searchAction:", @"fuzzyAction:"];
    
    for (int i = 0; i < 6; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:buttonTitles[i] forState:UIControlStateNormal];
        [button addTarget:self action:NSSelectorFromString(buttonSelectors[i]) forControlEvents:UIControlEventTouchUpInside];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:button];
        
        switch (i) {
            case 0: self.selectButton = button; break;
            case 1: self.clearButton = button; break;
            case 2: self.saveButton = button; break;
            case 3: self.modifyAllButton = button; break;
            case 4: self.searchButton = button; break;
            case 5: self.fuzzyButton = button; break;
        }
    }
}

- (void)createTableView {
    self.listTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.listTableView.delegate = self;
    self.listTableView.dataSource = self;
    [self.listTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    self.listTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.listTableView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.listTableView];
}

- (void)setupConstraints {
    NSArray *items = @[self.countLabel, self.selectButton, self.clearButton, self.saveButton, self.modifyAllButton, self.searchButton, self.fuzzyButton];
    
    // 创建一个容器视图来包含所有项目
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:containerView];
    
    [NSLayoutConstraint activateConstraints:@[
        [containerView.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
        [containerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
        [containerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
        [containerView.heightAnchor constraintEqualToConstant:44] // 设置容器高度
    ]];
    
    // 将所有项目添加到容器视图中
    for (UIView *item in items) {
        [containerView addSubview:item];
    }
    
    // 使用等宽约束平均分配空间
    [items enumerateObjectsUsingBlock:^(UIView *item, NSUInteger idx, BOOL *stop) {
        [NSLayoutConstraint activateConstraints:@[
            [item.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
            [item.leadingAnchor constraintEqualToAnchor:idx == 0 ? containerView.leadingAnchor : [items[idx-1] trailingAnchor]],
            [item.widthAnchor constraintEqualToAnchor:containerView.widthAnchor multiplier:1.0/items.count]
        ]];
        
        if (idx == items.count - 1) {
            [item.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor].active = YES;
        }
    }];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.listTableView.topAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:10],
        [self.listTableView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.listTableView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.listTableView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

- (void)updateLayout {
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}

#pragma mark - Public Methods

- (void)updateTableViewWithData:(NSArray *)data {
    self.dataSource = data;
    [self.listTableView reloadData];
    self.countLabel.text = [NSString stringWithFormat:@"名称数量: %lu", (unsigned long)data.count];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    cell.textLabel.text = self.dataSource[indexPath.row];
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = [UIColor whiteColor];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [LogManager log:[NSString stringWithFormat:@"选中了: %@", self.dataSource[indexPath.row]]];
    
    if ([self.delegate respondsToSelector:@selector(searchPageView:didSelectItemAtIndex:)]) {
        [self.delegate searchPageView:self didSelectItemAtIndex:indexPath.row];
    }
}

#pragma mark - Button Actions

- (void)selectAction:(UIButton *)sender {
    [LogManager log:@"选择按钮被点击"];
}

- (void)clearAction:(UIButton *)sender {
    [LogManager log:@"清除按钮被点击"];
}

- (void)saveAction:(UIButton *)sender {
    [LogManager log:@"保存按钮被点击"];
}

- (void)modifyAllAction:(UIButton *)sender {
    [LogManager log:@"修改所有按钮被点击"];
}

- (void)searchAction:(UIButton *)sender {
    [LogManager log:@"搜索按钮被点击"];
    [self showSearchPopup];
}

- (void)fuzzyAction:(UIButton *)sender {
    [LogManager log:@"模糊按钮被点击"];
}

#pragma mark - Search Popup

- (void)showSearchPopup {
    if (self.customAlertView) {
        [self.customAlertView removeFromSuperview];
    }

    self.customAlertView = [[UIView alloc] init];
    self.customAlertView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
    self.customAlertView.layer.cornerRadius = 5;
    self.customAlertView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.customAlertView];

    self.searchTextField = [[UITextField alloc] init];
    self.searchTextField.placeholder = @"输入搜索内容";
    self.searchTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.searchTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.customAlertView addSubview:self.searchTextField];

    NSArray *options = @[@"i32", @"i64", @"f32", @"f64"];
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:options];
    self.segmentedControl.selectedSegmentIndex = [self loadLastSelectedSegmentIndex];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.segmentedControl addTarget:self action:@selector(segmentedControlValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.customAlertView addSubview:self.segmentedControl];

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cancelButton.backgroundColor = [UIColor systemGrayColor];
    cancelButton.layer.cornerRadius = 2.5;
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [cancelButton addTarget:self action:@selector(dismissCustomAlert) forControlEvents:UIControlEventTouchUpInside];
    [self.customAlertView addSubview:cancelButton];

    UIButton *searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [searchButton setTitle:@"搜索" forState:UIControlStateNormal];
    [searchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    searchButton.backgroundColor = [UIColor systemBlueColor];
    searchButton.layer.cornerRadius = 2.5;
    searchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [searchButton addTarget:self action:@selector(performSearch) forControlEvents:UIControlEventTouchUpInside];
    [self.customAlertView addSubview:searchButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.customAlertView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.customAlertView.topAnchor constraintEqualToAnchor:self.topAnchor constant:0],
        [self.customAlertView.widthAnchor constraintEqualToConstant:225],

        [self.searchTextField.topAnchor constraintEqualToAnchor:self.customAlertView.topAnchor constant:15],
        [self.searchTextField.leadingAnchor constraintEqualToAnchor:self.customAlertView.leadingAnchor constant:15],
        [self.searchTextField.trailingAnchor constraintEqualToAnchor:self.customAlertView.trailingAnchor constant:-15],
        [self.searchTextField.heightAnchor constraintEqualToConstant:30],

        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.searchTextField.bottomAnchor constant:15],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.customAlertView.leadingAnchor constant:15],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.customAlertView.trailingAnchor constant:-15],
        [self.segmentedControl.heightAnchor constraintEqualToConstant:30],

        [cancelButton.topAnchor constraintEqualToAnchor:self.segmentedControl.bottomAnchor constant:15],
        [cancelButton.leadingAnchor constraintEqualToAnchor:self.customAlertView.leadingAnchor constant:15],
        [cancelButton.widthAnchor constraintEqualToConstant:90],
        [cancelButton.heightAnchor constraintEqualToConstant:30],

        [searchButton.topAnchor constraintEqualToAnchor:self.segmentedControl.bottomAnchor constant:15],
        [searchButton.trailingAnchor constraintEqualToAnchor:self.customAlertView.trailingAnchor constant:-15],
        [searchButton.widthAnchor constraintEqualToConstant:90],
        [searchButton.heightAnchor constraintEqualToConstant:30],

        [self.customAlertView.bottomAnchor constraintEqualToAnchor:searchButton.bottomAnchor constant:15]
    ]];
}

- (void)segmentedControlValueChanged:(UISegmentedControl *)sender {
    [self saveLastSelectedSegmentIndex:sender.selectedSegmentIndex];
}

- (void)dismissCustomAlert {
    [UIView animateWithDuration:0.3 animations:^{
        self.customAlertView.alpha = 0;
    } completion:^(BOOL finished) {
        [self.customAlertView removeFromSuperview];
        self.customAlertView = nil;
    }];
}
#define TARGET_PROCESS_NAME "pvz"//进程名称

- (void)performSearch {
    NSString *searchText = self.searchTextField.text;
    NSString *selectedOption = [self.segmentedControl titleForSegmentAtIndex:self.segmentedControl.selectedSegmentIndex];
    
    [LogManager log:[NSString stringWithFormat:@"执行搜索: 文本 - %@, 选项 - %@", searchText, selectedOption]];
    

    int32_t globalSelectedPID = [ProcessManager sharedManager].selectedPID;
    NSString *logMessage = [NSString stringWithFormat:@"globalSelectedPID: %d", globalSelectedPID];
    [LogManager log:logMessage];

    // 查找进程 PID
    pid_t target_pid = get_pid_by_name(TARGET_PROCESS_NAME);
    if (target_pid == -1) 
    {
        NSString *logMessage1 = [NSString stringWithFormat:@"未找到进程：%s\n", TARGET_PROCESS_NAME];
        [LogManager log:logMessage1];
        //return -1;
    }
    NSString *logMessage2 = [NSString stringWithFormat:@"找到进程: %s，PID: %d\n", TARGET_PROCESS_NAME, target_pid];
    [LogManager log:logMessage2];



    mach_vm_address_t address = 0x1060E1388; // 替换为你想读取的地址
    mach_vm_size_t size = sizeof(int32_t);
    unsigned char buffer[sizeof(int32_t)];

    ssize_t bytesRead = read_memory_native(target_pid, address, size, buffer);
    if (bytesRead == sizeof(int32_t)) 
    {
        int32_t value = *(int32_t*)buffer;
         [LogManager log:@"读取 int 值 0x%llX: %d", address, value];
        //[LogManager log:@"内存读取失败"];
    } else {
         [LogManager log:@"读取内存失败"];
    }
    

    
    if (bytesRead > 0) {
        // 根据选择的类型解析读取的数据
        NSString *result;
        if ([selectedOption isEqualToString:@"i32"]) {
            int32_t value = *(int32_t*)buffer;
            result = [NSString stringWithFormat:@"0x%llX: %d", address, value];
        } else if ([selectedOption isEqualToString:@"i64"]) {
            int64_t value = *(int64_t*)buffer;
            result = [NSString stringWithFormat:@"0x%llX: %lld", address, value];
        } else if ([selectedOption isEqualToString:@"f32"]) {
            float value = *(float*)buffer;
            result = [NSString stringWithFormat:@"0x%llX: %f", address, value];
        } else if ([selectedOption isEqualToString:@"f64"]) {
            double value = *(double*)buffer;
            result = [NSString stringWithFormat:@"0x%llX: %f", address, value];
        }
        
        // 将结果添加到数据源并刷新表格
        NSMutableArray *newDataSource = [NSMutableArray arrayWithArray:self.dataSource];
        [newDataSource addObject:result];
        [self updateTableViewWithData:newDataSource];
    } else {
        [LogManager log:@"内存读取失败"];
    }
    
    if ([self.delegate respondsToSelector:@selector(searchPageView:didTapSearchButtonWithText:andOption:)]) {
        [self.delegate searchPageView:self didTapSearchButtonWithText:searchText andOption:selectedOption];
    }
    
    [self dismissCustomAlert];
}

#pragma mark - Persistence

- (void)saveLastSelectedSegmentIndex:(NSInteger)index {
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"LastSelectedSegmentIndex"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSInteger)loadLastSelectedSegmentIndex {
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"LastSelectedSegmentIndex"];
}

@end