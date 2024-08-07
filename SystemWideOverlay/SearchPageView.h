// SearchPageView.h

#import <UIKit/UIKit.h>

@class SearchPageView;

@protocol SearchPageViewDelegate <NSObject>

- (void)searchPageView:(SearchPageView *)searchPageView didSelectItemAtIndex:(NSInteger)index;
- (void)searchPageView:(SearchPageView *)searchPageView didTapSearchButtonWithText:(NSString *)searchText andOption:(NSString *)option;

@end

@interface SearchPageView : UIView

@property (nonatomic, weak) id<SearchPageViewDelegate> delegate;
@property (nonatomic, strong) NSArray *dataSource;
@property (nonatomic, strong) UIView *customAlertView;
@property (nonatomic, strong) UITextField *searchTextField;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;

- (void)updateTableViewWithData:(NSArray *)data;

@end