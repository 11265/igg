#import "悬浮菜单内存页.h"
#import <mach/mach.h>

#import "日记输出/日记.h"
#include <Foundation/Foundation.h>
#include <dlfcn.h>
#include <errno.h>
#include <mach-o/dyld_images.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach/vm_region.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/queue.h>
#include <sys/sysctl.h>
#import "读写进程/内存搜索.h" 


@interface MemoryItem : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, assign) BOOL isFirstRead; // 添加标志位
- (instancetype)initWithAddress:(uint64_t)address value:(NSString *)value;
@end

@implementation MemoryItem
- (instancetype)initWithAddress:(uint64_t)address value:(NSString *)value {
    self = [super init];
    if (self) {
        _address = address;
        _value = value;
        _isFirstRead = YES; // 初始化为第一次读取
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[MemoryItem class]]) return NO;
    return self.address == ((MemoryItem *)object).address;
}

- (NSUInteger)hash {
    return (NSUInteger)self.address;
}

@end

@interface MemoryTableViewCell : UITableViewCell

@property (nonatomic, strong) NSMutableArray<UILabel *> *valueLabels;
@property (nonatomic, strong) NSMutableArray<UIView *> *highlightViews;
@property (nonatomic, strong) NSMutableArray<NSString *> *previousValues;

- (void)setupWithValues:(NSArray<NSString *> *)values isHexMode:(BOOL)isHexMode;

@end

@implementation MemoryTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.valueLabels = [NSMutableArray array];
        self.previousValues = [NSMutableArray arrayWithCapacity:4];
        
        for (int i = 0; i < 4; i++) {
            UILabel *valueLabel = [[UILabel alloc] init];
            valueLabel.font = [UIFont systemFontOfSize:12];
            valueLabel.textAlignment = NSTextAlignmentCenter;
            valueLabel.layer.cornerRadius = 4;
            valueLabel.clipsToBounds = YES;
            [self.contentView addSubview:valueLabel];
            [self.valueLabels addObject:valueLabel];
            [self.previousValues addObject:@""];
        }
        
        // 确保单元格本身的背景是清晰的
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setupWithValues:(NSArray<NSString *> *)values isHexMode:(BOOL)isHexMode {
    for (NSUInteger i = 0; i < self.valueLabels.count; i++) {
        UILabel *valueLabel = self.valueLabels[i];
        NSString *newValue = i < values.count ? values[i] : @"";
        
        if (isHexMode) {
            long long decimalValue = [newValue longLongValue];
            newValue = [NSString stringWithFormat:@"0x%llX", decimalValue];
        }
        
        if (i < self.previousValues.count && ![newValue isEqualToString:self.previousValues[i]]) {
            // 值发生变化，改变背景色
            valueLabel.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:1.0 alpha:1.0]; // 浅蓝色背景
            
            // 更新 previousValues
            self.previousValues[i] = newValue;
            
            // 使用 GCD 延迟恢复背景色
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.5 animations:^{
                    valueLabel.backgroundColor = [UIColor clearColor];
                }];
            });
        } else {
            valueLabel.backgroundColor = [UIColor clearColor];
        }
        
        valueLabel.textColor = [UIColor blackColor]; // 文本颜色始终保持黑色
        valueLabel.text = newValue;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat leftMargin = 0; // 添加15点的左边距
    CGFloat width = self.contentView.bounds.size.width - leftMargin;
    CGFloat height = self.contentView.bounds.size.height;
    CGFloat valueWidth = width / 4;
    CGFloat padding = 0; // 添加一些内边距
    
    for (NSUInteger i = 0; i < self.valueLabels.count; i++) {
        UILabel *valueLabel = self.valueLabels[i];
        CGRect frame = CGRectMake(leftMargin + (CGFloat)i * valueWidth + padding, padding, valueWidth - 2 * padding, height - 2 * padding);
        valueLabel.frame = frame;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    // 覆盖默认的选中行为
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    // 覆盖默认的高亮行为
}


@end

@interface 悬浮菜单内存页 () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISwitch *compactModeSwitch;
@property (nonatomic, assign) BOOL isCompactMode;
@property (nonatomic, strong) NSMutableArray<MemoryItem *> *memoryItems;
@property (nonatomic, assign, readwrite) uint64_t currentAddress;
@property (nonatomic, assign) NSInteger itemsToLoad;
@property (nonatomic, strong) UISegmentedControl *typeSegmentedControl;
@property (nonatomic, strong) UITextField *addressInputField;
@property (nonatomic, assign) BOOL isUpdating;
@property (nonatomic, strong) dispatch_source_t updateTimer;
@property (nonatomic, assign) NSTimeInterval updateInterval;
@property (nonatomic, assign) CGFloat lastKnownWidth;
@property (nonatomic, assign) BOOL isLoadingMore;
@end

@implementation 悬浮菜单内存页

- (instancetype)init {
    self = [super init];
    if (self) {
        self.itemsToLoad = 100;
        self.memoryItems = [NSMutableArray arrayWithCapacity:(NSUInteger)self.itemsToLoad];
        self.updateInterval = 1.0; // 默认为1秒
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.updateInterval = 1.0; // 设置默认更新间隔为1秒
    [self setupUI];
    [self.tableView registerClass:[MemoryTableViewCell class] forCellReuseIdentifier:@"MemoryCell"];
    
    // 记录初始宽度
    self.lastKnownWidth = CGRectGetWidth(self.view.bounds);
    self.isLoadingMore = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startUpdatingMemory]; // 自动开始更新内存
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopUpdatingMemory]; // 自动停止更新内存
}

- (void)setupUI {
    // 移除所有子视图
    for (UIView *subview in self.view.subviews) {
        [subview removeFromSuperview];
    }
    
    // 重新添加和布局所有 UI 元素
    self.view.backgroundColor = [UIColor whiteColor];
    
    CGFloat margin = 10;
    CGFloat controlHeight = 30; // 固定行高为30
    CGFloat switchWidth = 51;
    CGFloat buttonWidth = 60;
    CGFloat inputFieldWidth = 200; // 定输入框长度
    CGFloat segmentedControlWidth = 200; // 固定滑动选择框长度
    CGFloat currentY = margin;
    CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
    
    // 第一行：输入框和搜索按钮
    self.addressInputField = [[UITextField alloc] initWithFrame:CGRectMake(margin, currentY, inputFieldWidth, controlHeight)];
    self.addressInputField.placeholder = @"输入内存地址";
    self.addressInputField.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:self.addressInputField];
    
    UIButton *searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    searchButton.frame = CGRectMake(CGRectGetMaxX(self.addressInputField.frame) + margin, currentY, buttonWidth, controlHeight);
    [searchButton setTitle:@"搜索" forState:UIControlStateNormal];
    [searchButton addTarget:self action:@selector(searchButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:searchButton];
    
    currentY += controlHeight + margin;
    
    // 第二行：滑动选择框和紧凑模式开关
    self.typeSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"i32", @"i64", @"f32", @"f64"]];
    self.typeSegmentedControl.frame = CGRectMake(margin, currentY, segmentedControlWidth, controlHeight);
    self.typeSegmentedControl.selectedSegmentIndex = 0;
    [self.typeSegmentedControl addTarget:self action:@selector(typeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.typeSegmentedControl];
    
    self.compactModeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.typeSegmentedControl.frame) + margin, currentY, switchWidth, controlHeight)];
    [self.compactModeSwitch addTarget:self action:@selector(compactModeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.compactModeSwitch];
    
    currentY += controlHeight + margin;
    
    // 设置 tableView
    CGRect tableViewFrame = CGRectMake(0, currentY, viewWidth, CGRectGetHeight(self.view.bounds) - currentY);
    self.tableView = [[UITableView alloc] initWithFrame:tableViewFrame style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 30; // 设置默认行高为30
    [self.view addSubview:self.tableView];
    
    // 重新注册 cell
    [self.tableView registerClass:[MemoryTableViewCell class] forCellReuseIdentifier:@"MemoryCell"];
}

- (void)compactModeSwitchChanged:(UISwitch *)sender {
    self.isCompactMode = sender.isOn;
    
    // 获取输入框中的地址
    uint64_t inputAddress = [self getAddressFromInputField];
    
    if (inputAddress == 0 && self.memoryItems.count > 0) {
        // 如果输入为空或无效，使用当前显示的第一个地
        inputAddress = self.memoryItems.firstObject.address;
    }
    
    if (inputAddress != 0) {
        [self loadInitialMemoryContentAtAddress:inputAddress];
        [self.tableView reloadData];
        [self updateTableViewFrame];
        [self scrollToAddress:inputAddress];
        [self updateAddressInputField:inputAddress];
    } else {
        [self showAlertWithMessage:@"无效的地址"];
    }
}

- (uint64_t)getAddressFromInputField {
    NSString *address = self.addressInputField.text;
    if ([self isValidHex:address]) {
        if ([address hasPrefix:@"0x"] || [address hasPrefix:@"0X"]) {
            return strtoull([address UTF8String] + 2, NULL, 16);
        } else {
            return strtoull([address UTF8String], NULL, 16);
        }
    }
    return 0; // 返回0表示无效地址
}

- (void)updateAddressInputField:(uint64_t)address {
    self.addressInputField.text = [NSString stringWithFormat:@"0x%llX", address];
}

- (void)startUpdatingMemory {
    if (self.updateTimer) return;
    
    NSLog(@"开始自动更新内存");
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    self.updateTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    dispatch_source_set_timer(self.updateTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.updateInterval * NSEC_PER_SEC)), 
                              (uint64_t)(self.updateInterval * NSEC_PER_SEC), 
                              (uint64_t)(0.1 * self.updateInterval * NSEC_PER_SEC));
    dispatch_source_set_event_handler(self.updateTimer, ^{
        NSLog(@"定时器触发，刷新内存内容");
        [self refreshMemoryContent];
    });
    
    dispatch_resume(self.updateTimer);
}

- (void)stopUpdatingMemory {
    if (!self.updateTimer) return;
    
    NSLog(@"停止自动更新内存");
    
    dispatch_source_cancel(self.updateTimer);
    self.updateTimer = nil;
}

- (void)searchButtonTapped:(UIButton *)sender {
    NSString *address = self.addressInputField.text;
    if ([self isValidHex:address]) {
        uint64_t addressValue;
        if ([address hasPrefix:@"0x"] || [address hasPrefix:@"0X"]) {
            addressValue = strtoull([address UTF8String] + 2, NULL, 16);
        } else {
            addressValue = strtoull([address UTF8String], NULL, 16);
        }
        
        if (addressValue == 0 && errno == EINVAL) {
            [self showAlertWithMessage:@"无效的地址格式"];
        } else {
            self.currentAddress = addressValue; // 更新 currentAddress
            [self loadInitialMemoryContentAtAddress:addressValue];
            [self scrollToAddress:addressValue];
        }
    } else {
        [self showAlertWithMessage:@"请输入有效的十六进制内存地址"];
    }
}

- (BOOL)isValidHex:(NSString *)hexString {
    if ([hexString hasPrefix:@"0x"] || [hexString hasPrefix:@"0X"]) {
        hexString = [hexString substringFromIndex:2];
    }
    
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
    NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:hexString.uppercaseString];
    
    return [hexSet isSupersetOfSet:inStringSet] && hexString.length > 0 && hexString.length <= 16; // 限制最大长度为 16（64位地址）
}

- (void)scrollToAddress:(uint64_t)address {
    if (self.memoryItems.count == 0) {
        return;
    }
    
    NSInteger targetIndex = (NSInteger)[self.memoryItems indexOfObjectPassingTest:^BOOL(MemoryItem * _Nonnull obj, NSUInteger __unused idx, BOOL * _Nonnull __unused stop) {
        return obj.address >= address;
    }];
    
    if (targetIndex == NSNotFound) {
        targetIndex = 0;
    }
    
    NSInteger row = self.isCompactMode ? targetIndex / 4 : targetIndex;
    if (row >= [self.tableView numberOfRowsInSection:0]) {
        row = [self.tableView numberOfRowsInSection:0] - 1;
    }
    
    if (row >= 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
}

- (void)typeChanged:(UISegmentedControl *)sender {
    if (self.addressInputField.text.length == 0) {
        NSLog(@"无内存地址");
        return;
    }
    [self loadInitialMemoryContentAtAddress:self.currentAddress];
}

- (NSInteger)bytesForSelectedType {
    switch (self.typeSegmentedControl.selectedSegmentIndex) {
        case 0: // i32
        case 2: // f32
            return 4;
        case 1: // i64
        case 3: // f64
            return 8;
        default:
            return 4;
    }
}

- (MemoryItem *)loadMemoryItemAtAddress:(uint64_t)address {
    mach_vm_size_t size = (mach_vm_size_t)[self bytesForSelectedType];
    uint64_t value = read_memory_via_registerc(address);
    
    NSString *formattedValue;
    switch (size) {
        case 4:
            formattedValue = [self formatValueFromBuffer:&value size:sizeof(uint32_t)];
            break;
        case 8:
            formattedValue = [self formatValueFromBuffer:&value size:sizeof(uint64_t)];
            break;
        default:
            formattedValue = @"未知大小";
            break;
    }
    
    return [[MemoryItem alloc] initWithAddress:address value:formattedValue];
}

- (NSString *)formatValueFromBuffer:(void *)buffer size:(size_t)size {
    if (!buffer) {
        return @"无效数据";
    }
    
    switch (self.typeSegmentedControl.selectedSegmentIndex) {
        case 0: return [NSString stringWithFormat:@"%d", *(int32_t *)buffer];
        case 1: return [NSString stringWithFormat:@"%lld", *(int64_t *)buffer];
        case 2: return [NSString stringWithFormat:@"%.6f", *(float *)buffer];
        case 3: return [NSString stringWithFormat:@"%.6f", *(double *)buffer];
        default: return @"未知类型";
    }
}

- (void)showAlertWithMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull __unused action) {
        // ... existing code ...
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)setupInView:(UIView *)view {
    self.view.frame = view.bounds;
    [view addSubview:self.view];
}

- (void)refreshMemoryContent {
    NSLog(@"刷新内存内容");
    CGPoint contentOffset = self.tableView.contentOffset;
    NSIndexPath *topVisibleIndexPath = [[self.tableView indexPathsForVisibleRows] firstObject];
    
    NSArray<NSIndexPath *> *visibleIndexPaths = [self.tableView indexPathsForVisibleRows];
    
    for (NSIndexPath *indexPath in visibleIndexPaths) {
        NSInteger startIndex = self.isCompactMode ? indexPath.row * 4 : indexPath.row;
        NSInteger endIndex;
        if (self.isCompactMode) {
            endIndex = (startIndex + 4 < (NSInteger)self.memoryItems.count) ? startIndex + 4 : (NSInteger)self.memoryItems.count;
        } else {
            endIndex = startIndex + 1;
        }
        
        for (NSUInteger i = (NSUInteger)startIndex; i < (NSUInteger)endIndex; i++) {
            MemoryItem *item = self.memoryItems[i];
            MemoryItem *updatedItem = [self loadMemoryItemAtAddress:item.address];
            // 只有当值发生变化时才更新
            if (![item.value isEqualToString:updatedItem.value]) {
                updatedItem.isFirstRead = NO; // 更新标志位
                self.memoryItems[i] = updatedItem;
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadRowsAtIndexPaths:visibleIndexPaths withRowAnimation:UITableViewRowAnimationNone];
        
        if (topVisibleIndexPath) {
            [self.tableView scrollToRowAtIndexPath:topVisibleIndexPath 
                                  atScrollPosition:UITableViewScrollPositionTop 
                                          animated:NO];
            self.tableView.contentOffset = contentOffset;
        }
    });
}

- (void)updateVisibleMemoryContent {
    NSArray *visibleCells = [self.tableView visibleCells];
    NSMutableArray *updatedItems = [NSMutableArray array];
    
    for (NSUInteger i = 0; i < visibleCells.count; i++) {
        UITableViewCell *cell = visibleCells[i];
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        MemoryItem *item = self.memoryItems[(NSUInteger)indexPath.row];
        MemoryItem *updatedItem = [self loadMemoryItemAtAddress:item.address];
        [updatedItems addObject:updatedItem];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSUInteger i = 0; i < visibleCells.count; i++) {
            UITableViewCell *cell = visibleCells[i];
            MemoryItem *updatedItem = updatedItems[i];
            cell.detailTextLabel.text = updatedItem.value;
            
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
            self.memoryItems[(NSUInteger)indexPath.row] = updatedItem;
        }
    });
}

- (void)setUpdateInterval:(NSTimeInterval)interval {
    _updateInterval = interval;
    if (self.updateTimer) {
        [self stopUpdatingMemory];
        [self startUpdatingMemory];
    }
}

- (void)loadInitialMemoryContentAtAddress:(uint64_t)address {
    self.currentAddress = address;
    BOOL success = [self loadMemoryItemsAroundAddress:self.currentAddress];
    if (!success) {
        [self showAlertWithMessage:@"无法读取指定地址的内存"];
        return;
    }
    [self.tableView reloadData];
}

- (BOOL)loadMemoryItemsAroundAddress:(uint64_t)address {
    [self.memoryItems removeAllObjects];
    
    NSInteger itemsToLoad = self.itemsToLoad * 4; // 总是加载4倍的项目，以确保紧凑模式下有足够的数据
    NSInteger itemsAbove = itemsToLoad / 2;
    NSInteger itemsBelow = itemsToLoad - itemsAbove - 1;
    
    BOOL anySuccessfulRead = NO;
    NSMutableSet *loadedAddresses = [NSMutableSet set];
    
    for (NSInteger i = -itemsAbove; i <= itemsBelow; i++) {
        uint64_t currentAddress = address + (uint64_t)(i * [self bytesForSelectedType]);
        
        if ([loadedAddresses containsObject:@(currentAddress)]) {
            continue;
        }
        
        MemoryItem *item = [self loadMemoryItemAtAddress:currentAddress];
        if (item) {
            [self.memoryItems addObject:item];
            [loadedAddresses addObject:@(currentAddress)];
            
            if (![item.value isEqualToString:@"读取失败"]) {
                anySuccessfulRead = YES;
            }
        }
    }
    
    return anySuccessfulRead;
}

- (void)addUniqueMemoryItem:(MemoryItem *)item {
    if (![self.memoryItems containsObject:item]) {
        [self.memoryItems addObject:item];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView && !self.isLoadingMore) {
        CGFloat offsetY = scrollView.contentOffset.y;
        CGFloat contentHeight = scrollView.contentSize.height;
        CGFloat frameHeight = scrollView.frame.size.height;
        
        if (offsetY < frameHeight * 0.2) {
            [self loadMoreItemsAtTop];
        } else if (offsetY > contentHeight - frameHeight * 1.2) {
            [self loadMoreItemsAtBottom];
        }
    }
}

- (void)loadMoreItemsAtTop {
    self.isLoadingMore = YES;
    NSInteger itemsToAdd = 20;
    NSMutableArray *newItems = [NSMutableArray arrayWithCapacity:(NSUInteger)itemsToAdd];
    
    uint64_t currentAddress = self.memoryItems.firstObject.address - (uint64_t)[self bytesForSelectedType];
    
    for (NSInteger i = 0; i < itemsToAdd; i++) {
        MemoryItem *item = [self loadMemoryItemAtAddress:currentAddress];
        if (![self.memoryItems containsObject:item]) {
            [newItems insertObject:item atIndex:0];
        }
        currentAddress -= (uint64_t)[self bytesForSelectedType];
    }
    
    [self.memoryItems insertObjects:newItems atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newItems.count)]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CGPoint contentOffset = self.tableView.contentOffset;
        [self.tableView beginUpdates];
        NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:newItems.count];
        for (NSUInteger i = 0; i < (self.isCompactMode ? newItems.count / 4 : newItems.count); i++) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:(NSInteger)i inSection:0]];
        }
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
        
        // 调整内容偏移以保持相对位置
        CGFloat heightAdded = (self.isCompactMode ? (CGFloat)newItems.count / 4.0 : (CGFloat)newItems.count) * self.tableView.rowHeight;
        self.tableView.contentOffset = CGPointMake(contentOffset.x, contentOffset.y + heightAdded);
        
        self.isLoadingMore = NO;
    });
}

- (void)loadMoreItemsAtBottom {
    self.isLoadingMore = YES;
    NSInteger itemsToAdd = 20;
    NSMutableArray *newItems = [NSMutableArray arrayWithCapacity:(NSUInteger)itemsToAdd];
    
    uint64_t currentAddress = self.memoryItems.lastObject.address + (uint64_t)[self bytesForSelectedType];
    
    for (NSInteger i = 0; i < itemsToAdd; i++) {
        MemoryItem *item = [self loadMemoryItemAtAddress:currentAddress];
        if (![self.memoryItems containsObject:item]) {
            [newItems addObject:item];
        }
        currentAddress += (uint64_t)[self bytesForSelectedType];
    }
    
    NSUInteger startIndex = self.memoryItems.count;
    [self.memoryItems addObjectsFromArray:newItems];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView beginUpdates];
        NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:newItems.count];
        for (NSUInteger i = 0; i < (self.isCompactMode ? newItems.count / 4 : newItems.count); i++) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:(NSInteger)(startIndex / (self.isCompactMode ? 4 : 1) + i) inSection:0]];
        }
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
        self.isLoadingMore = NO;
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.isCompactMode ? (NSInteger)((self.memoryItems.count + 3) / 4) : (NSInteger)self.memoryItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isCompactMode) {
        static NSString *cellIdentifier = @"CompactMemoryCell";
        MemoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[MemoryTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }
        
        NSInteger startIndex = indexPath.row * 4;
        NSMutableArray *values = [NSMutableArray arrayWithCapacity:4];
        
        for (NSUInteger i = 0; i < 4 && (startIndex + (NSInteger)i) < (NSInteger)self.memoryItems.count; i++) {
            MemoryItem *item = self.memoryItems[(NSUInteger)((NSUInteger)startIndex + i)];
            [values addObject:item.value];
        }
        
        [cell setupWithValues:values isHexMode:NO];
        
        return cell;
    } else {
        static NSString *cellIdentifier = @"SimpleMemoryCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
        }
        
        if (indexPath.row < (NSInteger)self.memoryItems.count) {
            MemoryItem *item = self.memoryItems[(NSUInteger)indexPath.row];
            cell.textLabel.text = [NSString stringWithFormat:@"0x%llX", item.address];
            cell.detailTextLabel.text = item.value;
        } else {
            cell.textLabel.text = @"";
            cell.detailTextLabel.text = @"";
        }
        
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.isCompactMode ? 40 : 30; // 紧凑模式下每个单元格显示4个值，高度调整为40
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        (void)context; // Explicitly ignore the unused parameter
        [self updateViewForNewOrientation:size];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        (void)context; // Explicitly ignore the unused parameter
        // 在转换完成后，重新加载数据以确保内容正确显示
        //[self.tableView reloadData];
    }];
}

- (void)updateViewForNewOrientation:(CGSize)size {
    CGFloat margin = 10;
    CGFloat controlHeight = 30; // 固定行高为30
    CGFloat switchWidth = 51;
    CGFloat buttonWidth = 60;
    CGFloat inputFieldWidth = 200; // 固定输入框长度
    CGFloat segmentedControlWidth = 200; // 固定滑动选择框长度
    CGFloat currentY = margin;
    CGFloat viewWidth = size.width;
    
    // 更新第一行：输入框和两个按钮
    self.addressInputField.frame = CGRectMake(margin, currentY, inputFieldWidth, controlHeight);
    UIButton *searchButton = [self.view viewWithTag:1001]; // 假设我们给搜索按钮设置了tag 1001
    searchButton.frame = CGRectMake(CGRectGetMaxX(self.addressInputField.frame) + margin, currentY, buttonWidth, controlHeight);
    
    currentY += controlHeight + margin;
    
    // 更新第二行：滑动选择框和紧凑模式开关
    self.typeSegmentedControl.frame = CGRectMake(margin, currentY, segmentedControlWidth, controlHeight);
    self.compactModeSwitch.frame = CGRectMake(CGRectGetMaxX(self.typeSegmentedControl.frame) + margin, currentY, switchWidth, controlHeight);
    
    currentY += controlHeight + margin;
    
    // 更新 tableView
    self.tableView.frame = CGRectMake(0, currentY, viewWidth, size.height - currentY);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateTableViewFrame];
}

- (void)updateTableViewFrame {
    CGFloat topMargin = CGRectGetMaxY(self.compactModeSwitch.frame) + 10;
    CGRect tableViewFrame = CGRectMake(0, topMargin, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) - topMargin);
    self.tableView.frame = tableViewFrame;
}

- (void)dealloc {
    [self stopUpdatingMemory];
}

// 添加用于调试的方法
- (void)logMemoryItems {
    [日记 log:@"Memory Items:"];
    for (NSInteger i = 0; i < (NSInteger)self.memoryItems.count; i++) {
        MemoryItem *item = self.memoryItems[(NSUInteger)i];
        [日记 log:@"Index: %ld, Address: 0x%llX, Value: %@", (long)i, item.address, item.value];
    }
}

- (uint64_t)addressForIndexPath:(NSIndexPath *)indexPath {
    NSInteger index = self.isCompactMode ? indexPath.row * 4 : indexPath.row;
    if (index < (NSInteger)self.memoryItems.count) {
        return self.memoryItems[(NSUInteger)index].address;
    }
    return 0;
}

- (void)displayModeSwitchChanged:(UISwitch *)sender {
    self.isHexMode = sender.isOn;
    [self refreshMemoryContent];
}

- (void)loadAndDisplayMemoryContentForAddress:(uint64_t)address {
    self.currentAddress = address;
    [self loadInitialMemoryContentAtAddress:address];
    [self.tableView reloadData];
    [self scrollToAddress:address];
    [self updateAddressInputField:address];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.isCompactMode) {
        // 在紧凑模式下，我们需要显示一个选择器来让用户选择要编辑的值
        [self showCompactModeEditSelectorForIndexPath:indexPath];
    } else {
        uint64_t address = [self addressForIndexPath:indexPath];
        NSString *currentValue = [self.memoryItems[(NSUInteger)indexPath.row] value];
        [self showEditAlertForAddress:address currentValue:currentValue];
    }
}

- (void)showEditAlertForAddress:(uint64_t)address currentValue:(NSString *)currentValue {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    // 创建一个容器视图来包含自定义内容
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [alertController.view addSubview:containerView];
    
    // 添加自定义的当前值标签
    UILabel *currentValueLabel = [[UILabel alloc] init];
    currentValueLabel.text = [NSString stringWithFormat:@"当前值: %@", currentValue];
    currentValueLabel.textAlignment = NSTextAlignmentCenter;
    currentValueLabel.font = [UIFont systemFontOfSize:14];
    currentValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:currentValueLabel];
    
    // 添加滑动选择框
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"i32", @"i64", @"f32", @"f64"]];
    segmentedControl.selectedSegmentIndex = self.typeSegmentedControl.selectedSegmentIndex; // 使用当前选择的类型
    segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:segmentedControl];
    
    // 设置容器视图的约束
    [NSLayoutConstraint activateConstraints:@[
        [containerView.topAnchor constraintEqualToAnchor:alertController.view.topAnchor constant:20],
        [containerView.leadingAnchor constraintEqualToAnchor:alertController.view.leadingAnchor constant:20],
        [containerView.trailingAnchor constraintEqualToAnchor:alertController.view.trailingAnchor constant:-20],
        [containerView.bottomAnchor constraintEqualToAnchor:alertController.view.bottomAnchor constant:-64] // 为按钮留出空间
    ]];
    
    // 设置自定义视图的约束
    [NSLayoutConstraint activateConstraints:@[
        [currentValueLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [currentValueLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [currentValueLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        
        [segmentedControl.topAnchor constraintEqualToAnchor:currentValueLabel.bottomAnchor constant:10],
        [segmentedControl.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [segmentedControl.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [segmentedControl.heightAnchor constraintEqualToConstant:30],
        [segmentedControl.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-30] // 确保 segmentedControl 的底部与容器视图的底部对齐
    ]];
    
    // 添加输入框
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"输入新值";
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull __unused action) {
        NSString *newValueString = alertController.textFields.firstObject.text;
        uint64_t newValue = (uint64_t)[newValueString longLongValue];
        write_memory_via_registervc(address, newValue);
        [self refreshMemoryContent]; // 修改内存值后刷新视图内容
    }];
    
    [alertController addAction:cancelAction];
    [alertController addAction:confirmAction];
    
    // 增加弹框的高度以容纳自定义视图
    CGFloat alertHeight = 200;
    alertController.view.bounds = CGRectMake(0, 0, alertController.view.bounds.size.width, alertHeight);
    
    [self presentViewController:alertController animated:YES completion:nil];
}


- (void)writeMemoryValue:(NSString *)valueString toAddress:(uint64_t)address withType:(NSInteger)type {
    uint64_t value = 0;
    
    switch (type) {
        case 0: { // i32
            int32_t intValue = [valueString intValue];
            value = (uint64_t)intValue;
            break;
        }
        case 1: { // i64
            int64_t longValue = [valueString longLongValue];
            value = (uint64_t)longValue;
            break;
        }
        case 2: { // f32
            float floatValue = [valueString floatValue];
            memcpy(&value, &floatValue, sizeof(float));
            break;
        }
        case 3: { // f64
            double doubleValue = [valueString doubleValue];
            memcpy(&value, &doubleValue, sizeof(double));
            break;
        }
    }
    
    write_memory_via_registervc(address, value);
    
    [日记 log:@"成功修改内存地址 0x%llX 的值为 %@", address, valueString];
    
    // 刷新表视图以显示更新后的值
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}


// 添加新方法来处理紧凑模式下的编辑选择
- (void)showCompactModeEditSelectorForIndexPath:(NSIndexPath *)indexPath {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"选择要编辑的值"
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSInteger startIndex = indexPath.row * 4;
    for (NSUInteger i = 0; i < 4 && ((NSUInteger)startIndex + i) < self.memoryItems.count; i++) {
        MemoryItem *item = self.memoryItems[(NSUInteger)((NSUInteger)startIndex + i)];
        NSString *title = [NSString stringWithFormat:@"地址: 0x%llX, 值: %@", item.address, item.value];
        [alertController addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull __unused action) {
            [self showEditAlertForAddress:item.address currentValue:item.value];
        }]];
    }
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}


@end

