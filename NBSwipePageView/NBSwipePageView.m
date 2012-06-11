//
//  NBSwipePageView.m
//  NBSwipePageView
//
//  Created by 徐 哲 on 4/25/12.
//  Copyright (c) 2012 ラクラクテクノロジーズ株式会社 Rakuraku Technologies, Inc. All rights reserved.
//

#import "NBSwipePageView.h"

#define kMaxVisiblePageLength           3

@interface NBSwipePageTouchView : UIView

@property (unsafe_unretained, nonatomic) UIView *touchHandlerView;
@end

@implementation NBSwipePageTouchView
@synthesize touchHandlerView = _touchHandlerView;

- (void)initCodes {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundColor = [UIColor clearColor];
}

- (id)init {
    self = [super init];
    if (self) {
        [self initCodes];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self initCodes];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initCodes];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	if (_touchHandlerView && [self pointInside:point withEvent:event]) {
		return _touchHandlerView;
	}
	return nil;
}

@end

// ======================= NBSwipePageView =======================
@interface NBSwipePageView (PrivateMethod) <UIScrollViewDelegate, UIGestureRecognizerDelegate>

@end

@implementation NBSwipePageView {
    UIScrollView *_scrollView;
    NBSwipePageTouchView *_touchView;
    NBSwipePageViewSheet *_currentPage;
    NSMutableArray *_visiblePages;
    NSMutableDictionary *_reusablePages;
    NSUInteger _cachedNumberOfPages;
    NSRange _visibleRange;
    BOOL _isPendingScrolledPageUpdateNotification;
    CGFloat _cachedScaleRate;
    NSUInteger _selectedPageIndex;
}

@synthesize delegate = _delegate;
@synthesize dataSource = _dataSource;
@synthesize currentPageIndex = _currentPageIndex;
@synthesize pageViewMode = _pageViewMode;
@synthesize pageHeaderView = _pageHeaderView;
@synthesize pageTailView = _pageTailView;
@synthesize pageTitleView = _pageTitleView;
@synthesize backgroundView = _backgroundView;
@synthesize allowsSelection = _allowsSelection;
@synthesize disableScrollInFullSizeMode = _disableScrollInFullSizeMode;
@synthesize visibleViewEffectBlock = _visibleViewEffectBlock;

#pragma mark - Init Codes
- (void)initCodes {
    // init settings
    _currentPageIndex = NSNotFound;
    _selectedPageIndex = NSNotFound;
    _pageViewMode = NBSwipePageViewModePageSize;
    _allowsSelection = NO;
    _disableScrollInFullSizeMode = NO;  // defult is do NOT disable scroll in full size mode
    _isPendingScrolledPageUpdateNotification = NO;
    
    // init views
    _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scrollView.delegate = self;
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.backgroundColor = [UIColor clearColor];
    _scrollView.pagingEnabled = YES;
    _scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    _scrollView.clipsToBounds = NO;
    _scrollView.delaysContentTouches = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.showsHorizontalScrollIndicator = NO;
    [self addSubview:_scrollView];
    
    _touchView = [[NBSwipePageTouchView alloc] initWithFrame:self.bounds];
    _touchView.touchHandlerView = _scrollView;
    _touchView.autoresizingMask = _scrollView.autoresizingMask;
    [self addSubview:_touchView];
    
    // set tap gesture recognizer for page selection
	UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureHandler:)];
	[_scrollView addGestureRecognizer:tapRecognizer];
	tapRecognizer.delegate = self;
    
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureHandler:)];
    [_scrollView addGestureRecognizer:longPressRecognizer];
    longPressRecognizer.delegate = self;

    // init caches
    _cachedNumberOfPages = 0;
    _visiblePages = [NSMutableArray arrayWithCapacity:4];
    _reusablePages = [NSMutableDictionary dictionary];
    
    _visibleRange.location = 0;
    _visibleRange.length = 0;
}

- (id)init {
    self = [super init];
    if (self) {
        [self initCodes];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self initCodes];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initCodes];
    }
    return self;
}

//- (void)dealloc {
//    NSLog(@"Just for release check.");
//}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
	_scrollView.contentSize = CGSizeMake((CGFloat)_cachedNumberOfPages * _scrollView.bounds.size.width, _scrollView.bounds.size.height);
}

#pragma mark - Delegate Sender
- (void)delegateDidScrollToPageAtIndex:(NSUInteger)index animated:(BOOL)animated {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:didScrollToPageAtIndex:animated:)]) {
        [_delegate swipePageView:self didScrollToPageAtIndex:index animated:animated];
    }
}

- (void)delegateWillScrollToPageAtIndex:(NSUInteger)index animated:(BOOL)animated {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:willScrollToPageAtIndex:animated:)]) {
        [_delegate swipePageView:self willScrollToPageAtIndex:index animated:animated];
    }
}

- (void)delegateDidCancelScrollFromPageAtIndex:(NSUInteger)index {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:didCancelScrollFromPageAtIndex:)]) {
        [_delegate swipePageView:self didCancelScrollFromPageAtIndex:index];
    }
}

- (void)delegateDidScroll {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageViewDidScroll:)]) {
        [_delegate swipePageViewDidScroll:self];
    }
}

- (CGFloat)delegateScaleOfSmallViewMode {
    if (_delegate && [_delegate respondsToSelector:@selector(scaleOfSmallViewModeForSwipePageView:)]) {
        return [_delegate scaleOfSmallViewModeForSwipePageView:self];
    }
    return 0.6; // default is 60%
}

- (NSUInteger)delegateWillSelectPageAtIndex:(NSUInteger)index {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:willSelectPageAtIndex:)]) {
        return [_delegate swipePageView:self willSelectPageAtIndex:index];
    }
    return index;
}

- (void)delegateDidSelectPageAtIndex:(NSUInteger)index {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:didSelectPageAtIndex:)]) {
        [_delegate swipePageView:self didSelectPageAtIndex:index];
    }
}

- (NSUInteger)delegateWillDeselectPageAtIndex:(NSUInteger)index {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:willDeselectPageAtIndex:)]) {
        [_delegate swipePageView:self willDeselectPageAtIndex:index];
    }
    return index;
}

- (void)delegateDidDeselectPageAtIndex:(NSUInteger)index {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:didDeselectPageAtIndex:)]) {
        [_delegate swipePageView:self didDeselectPageAtIndex:index];
    }
}

// TODO: Action Menu Support
- (BOOL)delegateShouldShowMenuForPageAtIndex:(NSUInteger)index {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:shouldShowMenuForPageAtIndex:)]) {
        return [_delegate swipePageView:self shouldShowMenuForPageAtIndex:index];
    }
    return NO;
}

- (BOOL)delegateCanPerformAction:(SEL)action forPageAtIndex:(NSUInteger)index withSender:(id)sender {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:canPerformAction:forPageAtIndex:withSender:)]) {
        return [_delegate swipePageView:self canPerformAction:action forPageAtIndex:index withSender:sender];
    }
    return NO;
}

- (void)delegatePerformAction:(SEL)action forPageAtIndex:(NSUInteger)index withSender:(id)sender {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:performAction:forPageAtIndex:withSender:)]) {
        [_delegate swipePageView:self performAction:action forPageAtIndex:index withSender:sender];
    }
}

// TODO: Editing Page View Support
- (void)delegateWillBeginEditingPageAtIndex:(NSUInteger)index {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:willBeginEditingPageAtIndex:)]) {
        [_delegate swipePageView:self willBeginEditingPageAtIndex:index];
    }
}

- (void)delegateDidEndEditingPageAtIndex:(NSUInteger)index {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:didEndEditingPageAtIndex:)]) {
        [_delegate swipePageView:self didEndEditingPageAtIndex:index];
    }
}

- (void)delegateEditingStyleForPageAtIndex:(NSUInteger)index {
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageView:editingStyleForPageAtIndex:)]) {
        [_delegate swipePageView:self editingStyleForPageAtIndex:index];
    }
}

#pragma mark - Datasource Sender
// Required Datasource
- (NSUInteger)dataSourceLoadNumberOfPages {
    NSUInteger pages = [_dataSource numberOfPagesInSwipePageView:self];
    if (_cachedNumberOfPages == pages) {
        return pages;
    }
    _cachedNumberOfPages = pages;
    _scrollView.contentSize = CGSizeMake(_scrollView.bounds.size.width * (CGFloat)pages, _scrollView.bounds.size.height);
    return pages;
}

- (NBSwipePageViewSheet *)dataSourceSheetForPageAtIndex:(NSUInteger)index {
    return [_dataSource swipePageView:self sheetForPageAtIndex:index];
}

// Option Datasource
// TODO: Editing page views
- (BOOL)dataSourceCanEditPageAtIndex:(NSUInteger)index {
    if (_dataSource && [_dataSource respondsToSelector:@selector(swipePageView:canEditPageAtIndex:)]) {
        return [_dataSource swipePageView:self canEditPageAtIndex:index];
    }
    return NO;
}

- (void)dataSourceCommitEditingStyle:(NBSwipePageViewSheetEditingStyle)editingStyle forPagetAtIndex:(NSUInteger)index {
    if (_dataSource && [_dataSource respondsToSelector:@selector(swipePageView:commitEditingStyle:forPagetAtIndex:)]) {
        [_dataSource swipePageView:self commitEditingStyle:editingStyle forPagetAtIndex:index];
    }
}

// TODO: Reording page views
- (BOOL)dataSourceCanMovePageAtIndex:(NSUInteger)index {
    if (_dataSource && [_dataSource respondsToSelector:@selector(swipePageView:canMovePageAtIndex:)]) {
        return [_dataSource swipePageView:self canMovePageAtIndex:index];
    }
    return NO;
}

- (void)dataSourceMovePageAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
    if (_dataSource && [_dataSource respondsToSelector:@selector(swipePageView:movePageAtIndex:toIndex:)]) {
        [_dataSource swipePageView:self movePageAtIndex:fromIndex toIndex:toIndex];
    }
}

#pragma mark - Private Logic Methods

- (void)setFrameForPage:(NBSwipePageViewSheet *)page atIndex:(NSInteger)index {
    page.transform = CGAffineTransformMakeScale(_cachedScaleRate, _cachedScaleRate);
	CGFloat contentOffset = (CGFloat)index * _scrollView.frame.size.width;
	CGFloat margin = floorf((_scrollView.frame.size.width - page.frame.size.width) * 0.5f); 
	CGRect frame = page.frame;
	frame.origin.x = floorf(contentOffset + margin);
	frame.origin.y = 0.0f;
	page.frame = frame;
    page.margin = margin;
}

- (void)shiftPage:(UIView*)page withOffset:(CGFloat)offset {
    CGRect frame = page.frame;
    frame.origin.x += offset;
    page.frame = frame;
}

- (NBSwipePageViewSheet *)loadPageAtIndex:(NSInteger)index insertIntoVisibleIndex:(NSInteger)visibleIndex {
	NBSwipePageViewSheet *visiblePage = [self dataSourceSheetForPageAtIndex:index];
	
	// add the page to the visible pages array
	[_visiblePages insertObject:visiblePage atIndex:visibleIndex];
    
    return visiblePage;
}

- (CGPoint)contentOffsetOfIndex:(NSUInteger)index {
    return CGPointMake(_scrollView.bounds.size.width * (CGFloat)index, 0.0f);
}

- (NSUInteger)indexOfCurrentContentOffset {
    CGFloat pageWidth = _scrollView.bounds.size.width;
    return floor((_scrollView.contentOffset.x - pageWidth * 0.5f) / pageWidth) + 1.0f;
}

- (void)preparePage:(NBSwipePageViewSheet *)page forMode:(NBSwipePageViewMode)mode {
    // When a page is presented in NBSwipePageViewMode mode, it is scaled up and is moved to a different superview. 
    // As it captures the full screen, it may be cropped to fit inside its new superview's frame. 
    // So when moving it back to NBSwipePageViewMode, we restore the page's proportions to prepare it to Deck mode.  
	if (mode == NBSwipePageViewModePageSize && 
        CGAffineTransformEqualToTransform(page.transform, CGAffineTransformIdentity)) {
        // TODO: 
//        page.frame = page.identityFrame;
	}
}

// add a page to the scroll view at a given index. No adjustments are made to existing pages offsets. 
- (void)addPageToScrollView:(NBSwipePageViewSheet *)page atIndex:(NSInteger)index {
    // inserting a page into the scroll view is in HGPageScrollViewModeDeck by definition (the scroll is the "deck")
    [self preparePage:page forMode:NBSwipePageViewModePageSize];
    
	// configure the page frame
    [self setFrameForPage:page atIndex:index];
    
    // add the page to the scroller
	[_scrollView insertSubview:page atIndex:0];
}

- (void)addToReusablePages:(NBSwipePageViewSheet *)page {
    NSMutableSet *set = [_reusablePages objectForKey:page.reuseIdentifier];
    if (set) {
        // if already have one reusable page, do not add another one.
        if ([set count] == 0) {
            [set addObject:page];
        }
    } else {
        set = [NSMutableSet setWithObject:page];
        [_reusablePages setObject:set forKey:page.reuseIdentifier];
    }
}

// Update Visible Pages
- (void)updateVisiblePages {
    CGFloat pageWidth = _scrollView.bounds.size.width;
    
	//get x origin of left- and right-most pages in _scrollView's superview coordinate space (i.e. self)  
	CGFloat leftViewOriginX = _scrollView.frame.origin.x - _scrollView.contentOffset.x + (_visibleRange.location * pageWidth);
	CGFloat rightViewOriginX = _scrollView.frame.origin.x - _scrollView.contentOffset.x + (_visibleRange.location + _visibleRange.length - 1.0) * pageWidth;
	
	if (leftViewOriginX > 0) {
		//new page is entering the visible range from the left
		if (_visibleRange.location > 0) { //is it not the first page?
			_visibleRange.length += 1;
			_visibleRange.location -= 1;
			NBSwipePageViewSheet *page = [self loadPageAtIndex:_visibleRange.location insertIntoVisibleIndex:0];
            // add the page to the scroll view (to make it actually visible)
            [self addPageToScrollView:page atIndex:_visibleRange.location ];
		}
	} else if (leftViewOriginX < - pageWidth) {
		//left page is exiting the visible range
		NBSwipePageViewSheet *page = [_visiblePages objectAtIndex:0];
        [_visiblePages removeObject:page];
        [page removeFromSuperview]; //remove from the scroll view
        [self addToReusablePages:page];
		_visibleRange.location += 1;
		_visibleRange.length -= 1;
	}
	if (rightViewOriginX > self.frame.size.width) {
		//right page is exiting the visible range
		NBSwipePageViewSheet *page = [_visiblePages lastObject];
        [_visiblePages removeObject:page];
        [page removeFromSuperview]; //remove from the scroll view
        [self addToReusablePages:page];
		_visibleRange.length -= 1;
	} else if (rightViewOriginX + pageWidth < self.frame.size.width) {
		//new page is entering the visible range from the right
		if (_visibleRange.location + _visibleRange.length < _cachedNumberOfPages) { //is is not the last page?
			_visibleRange.length += 1;
            NSInteger index = _visibleRange.location+_visibleRange.length-1;
			NBSwipePageViewSheet *page = [self loadPageAtIndex:index insertIntoVisibleIndex:_visibleRange.length-1];
            [self addPageToScrollView:page atIndex:index];
		}
	}
}

- (void)updateScrolledPage:(NBSwipePageViewSheet *)page index:(NSUInteger)index {
    if (page) {
        // notify delegate
        [self delegateWillScrollToPageAtIndex:index animated:NO];   // TODO:
                
        // set the page selector (page control)
        _currentPageIndex = index;
        
        // set selected page
        _currentPage = page;
        
        //	NSLog(@"selectedPage: 0x%x (index %d)", page, index );
        
        if (_scrollView.dragging || _scrollView.decelerating) {
            _isPendingScrolledPageUpdateNotification = YES;
        } else {
            [self delegateDidScrollToPageAtIndex:_currentPageIndex animated:NO];
            _isPendingScrolledPageUpdateNotification = NO;
        }
    }
}

- (NSUInteger)indexForVisiblePage:(NBSwipePageViewSheet *)page {
	NSUInteger index = [_visiblePages indexOfObject:page];
	if (index != NSNotFound) {
        return _visibleRange.location + index;
    }
    return NSNotFound;
}

#pragma mark - Set Views
- (void)setBackgroundView:(UIView *)backgroundView {
    if ([backgroundView isEqual:_backgroundView]) {
        return;
    }
    if (_backgroundView) {
        [_backgroundView removeFromSuperview];
    }
    _backgroundView = backgroundView;
    if (backgroundView) {
        backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;   // should always autoresize background view
        [self insertSubview:backgroundView atIndex:0];
    }
}

- (void)setPageHeaderView:(UIView *)pageHeaderView {
    if ([pageHeaderView isEqual:_pageHeaderView]) {
        return;
    }
    if (_pageHeaderView) {
        [_pageHeaderView removeFromSuperview];
    }
    _pageHeaderView = pageHeaderView;
    if (pageHeaderView && _currentPageIndex == 0) {
        [_scrollView addSubview:pageHeaderView];
        CGRect frame = pageHeaderView.frame;
        frame.origin.x = -frame.size.width;
        pageHeaderView.frame = frame;
    }
}

- (void)setPageTailView:(UIView *)pageTailView {
    if ([pageTailView isEqual:_pageTailView]) {
        return;
    }
    if (_pageTailView) {
        [_pageTailView removeFromSuperview];
    }
    _pageTailView = pageTailView;
    if (pageTailView && _currentPageIndex == _cachedNumberOfPages - 1) {
        [_scrollView addSubview:pageTailView];
        CGRect frame = pageTailView.frame;
        frame.origin.x = _scrollView.contentSize.width + frame.size.width;
        pageTailView.frame = frame;
    }
}

- (void)setPageTitleView:(UIView *)pageTitleView {
    if ([pageTitleView isEqual:_pageTitleView]) {
        return;
    }
    if (_pageTitleView) {
        [_pageTitleView removeFromSuperview];
    }
    _pageTitleView = pageTitleView;
    if (pageTitleView) {
        [self addSubview:pageTitleView];
    }
}

#pragma mark - Set Propertys
- (void)setPageViewMode:(NBSwipePageViewMode)pageViewMode {
    [self setPageViewMode:pageViewMode animated:NO];
}

#pragma mark - Public Methods
- (NBSwipePageViewSheet *)dequeueReusableCellWithIdentifier:(NSString *)reuseIdentifier {
    NSMutableSet *reusableSet = [_reusablePages objectForKey:reuseIdentifier];
    NBSwipePageViewSheet *reusableSheet = [reusableSet anyObject];
    if (reusableSheet) {
        [reusableSheet prepareForReuse];
        [reusableSet removeObject:reusableSheet];
        return reusableSheet;
    }
    return nil;
}

- (void)updateVisibleRange:(NSUInteger)currentIndex {
    if (currentIndex == NSNotFound || currentIndex == 0) {
        _currentPageIndex = 0;
        _visibleRange.length = MIN(kMaxVisiblePageLength - 1, _cachedNumberOfPages);
        _visibleRange.location = 0;
    } else if (currentIndex >= _cachedNumberOfPages) {
        _currentPageIndex = _cachedNumberOfPages - 1;
        _visibleRange.length = MIN(kMaxVisiblePageLength - 1, _cachedNumberOfPages);
        _visibleRange.location = MIN(_currentPageIndex - 1, _cachedNumberOfPages - 1);
    } else {
        _visibleRange.length = MIN(kMaxVisiblePageLength, _cachedNumberOfPages);
        _visibleRange.location = _currentPageIndex - 1;
    }
}

- (void)reloadData {    
    [_visiblePages removeAllObjects];
    [[_scrollView subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [obj removeFromSuperview];
        *stop = NO;
    }];

    if (_pageViewMode == NBSwipePageViewModePageSize) {
        _cachedScaleRate = [self delegateScaleOfSmallViewMode];
        CGRect frame = _scrollView.frame;
        CGFloat width = self.bounds.size.width * _cachedScaleRate;
        width += (self.bounds.size.width - width) * 0.25;
        frame.size.width = ceilf(width);
        frame.size.height = ceilf(self.bounds.size.height * _cachedScaleRate);
        frame.origin.x = floorf((self.bounds.size.width - frame.size.width) * 0.5);
        frame.origin.y = floorf((self.bounds.size.height - frame.size.height) * 0.5);
        _scrollView.frame = frame;
    } else {
        _cachedScaleRate = 1.0f;
        CGRect frame = _scrollView.frame;
        CGFloat width = self.bounds.size.width * _cachedScaleRate;
        width += (self.bounds.size.width - width) * 0.25;
        frame.size.width = ceilf(width);
        frame.size.height = ceilf(self.bounds.size.height * _cachedScaleRate);
        frame.origin.x = floorf((self.bounds.size.width - frame.size.width) * 0.5);
        frame.origin.y = floorf((self.bounds.size.height - frame.size.height) * 0.5);
        _scrollView.frame = frame;
    }

    [self dataSourceLoadNumberOfPages];
    _selectedPageIndex = NSNotFound;
    if (_cachedNumberOfPages == 0 || _cachedNumberOfPages == NSNotFound) {
        _currentPage = nil;
        _currentPageIndex = NSNotFound;
        return;
    }
    
    [self updateVisibleRange:_currentPageIndex];
    
    // reload visible pages
    for (NSUInteger i = 0; i <_visibleRange.length; i++) {
        NBSwipePageViewSheet *page = [self loadPageAtIndex:_visibleRange.location + i insertIntoVisibleIndex:i];
        [self addPageToScrollView:page atIndex:_visibleRange.location + i];
    }
    
    // this will load any additional views which become visible  
    [self updateVisiblePages];

    // refresh the page at the selected index (it might have changed after reloading the visible pages) 
    _currentPage = [_visiblePages objectAtIndex:_currentPageIndex];
    
    // reloading the data implicitely resets the viewMode to UIPageScrollViewModeDeck. 
    // here we restore the view mode in case this is not the first time reloadData is called (i.e. if there if a _selectedPage).   
//    if (_selectedPage && _viewMode==HGPageScrollViewModePage) { 
//        _viewMode = HGPageScrollViewModeDeck;
//        [self setViewMode:HGPageScrollViewModePage animated:NO];
//    }
    if (_visibleViewEffectBlock) {
        [_visiblePages enumerateObjectsUsingBlock:_visibleViewEffectBlock];
    }
}

- (void)scrollToPageAtIndex:(NSUInteger)index animated:(BOOL)animated {
    
}

- (NBSwipePageViewSheet *)swipePageViewSheetAtIndex:(NSUInteger)index {
    if (NSLocationInRange(index, _visibleRange)) {
        return [_visiblePages objectAtIndex:index - _visibleRange.location];
    }
    return [self dataSourceSheetForPageAtIndex:index];
}

- (void)setPageViewMode:(NBSwipePageViewMode)pageViewMode animated:(BOOL)animated {
    _pageViewMode = pageViewMode;
    // TODO: add animated support
}

- (BOOL)selectPageAtIndex:(NSUInteger)index animated:(BOOL)animated scrollToMiddle:(BOOL)scrollToMiddle {
    if (![self deselectPageAtIndex:_selectedPageIndex animated:animated]) {
        return NO;
    }
    NSUInteger shouldSelectIndex = [self delegateWillSelectPageAtIndex:index];
    if (shouldSelectIndex == NSNotFound) {
        return NO;
    } else if (shouldSelectIndex != _currentPageIndex) {
        [_scrollView setContentOffset:[self contentOffsetOfIndex:shouldSelectIndex] animated:animated];
    }
    [self delegateDidSelectPageAtIndex:shouldSelectIndex];
    _selectedPageIndex = shouldSelectIndex;
    return YES;
}

- (BOOL)deselectPageAtIndex:(NSUInteger)index animated:(BOOL)animated {
    if (index == NSNotFound) {
        return YES;
    }
    NSUInteger shouldDeselectIndex = [self delegateWillDeselectPageAtIndex:_selectedPageIndex];
    if (shouldDeselectIndex == NSNotFound) {
        return NO;
    }
    [self delegateDidDeselectPageAtIndex:_selectedPageIndex];
    _selectedPageIndex = NSNotFound;
    return YES;
}

// TODO: Edit the page view
- (void)beginUpdates {
    
}

- (void)endUpdates {
    
}

- (void)insertPagesAtIndexes:(NSIndexSet *)indexes withPageAnimation:(NBSwipePageViewPageAnimation)animated {
    
}

- (void)deletePagesAtIndexes:(NSIndexSet *)indexes withPageAnimation:(NBSwipePageViewPageAnimation)animated {
    
}

- (void)movePageAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
    
}

#pragma mark - UIScrollViewDelegate

- (void)setCurrentPageIndexOfScrollView:(UIScrollView *)scrollView {
    _currentPageIndex = [self indexOfCurrentContentOffset];
    if (_delegate) {
        CGFloat delta = scrollView.contentOffset.x - _currentPage.frame.origin.x;
        BOOL toggleNextItem = (fabs(delta) > scrollView.frame.size.width * 0.5);
        if (toggleNextItem && [_visiblePages count] > 1) {
            
            NSInteger selectedIndex = [_visiblePages indexOfObject:_currentPage];
            BOOL neighborExists = ((delta < 0 && selectedIndex > 0) || (delta > 0 && selectedIndex < [_visiblePages count]-1));
            
            if (neighborExists) {
                
                NSInteger neighborPageVisibleIndex = [_visiblePages indexOfObject:_currentPage] + (delta > 0 ? 1 : -1);
                NBSwipePageViewSheet *neighborPage = [_visiblePages objectAtIndex:neighborPageVisibleIndex];
                NSInteger neighborIndex = _visibleRange.location + neighborPageVisibleIndex;
                
                [self updateScrolledPage:neighborPage index:neighborIndex];
            }            
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateVisiblePages];
    
    if (_visibleViewEffectBlock) {
        [_visiblePages enumerateObjectsUsingBlock:_visibleViewEffectBlock];
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(swipePageViewDidScroll:)]) {
        [_delegate swipePageViewDidScroll:self];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self setCurrentPageIndexOfScrollView:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self setCurrentPageIndexOfScrollView:scrollView];
        if (_isPendingScrolledPageUpdateNotification) {
            [self delegateDidScrollToPageAtIndex:_currentPageIndex animated:NO];
            _isPendingScrolledPageUpdateNotification = NO;
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
        [self setCurrentPageIndexOfScrollView:scrollView];
    [self delegateDidScrollToPageAtIndex:_currentPageIndex animated:NO];
    _isPendingScrolledPageUpdateNotification = NO;
}

#pragma make - Get some propeties of UIScrollView
- (CGPoint)contentOffset {
    return _scrollView.contentOffset;
}

- (CGSize)contentSize {
    return _scrollView.contentSize;
}

- (BOOL)dragging {
    return _scrollView.dragging;
}

- (BOOL)tracking {
    return _scrollView.tracking;
}

- (BOOL)decelerating {
    return _scrollView.decelerating;
}


#pragma mark -
#pragma mark Handling Touches


- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
	if (_pageViewMode == NBSwipePageViewModePageSize && !_scrollView.decelerating && !_scrollView.dragging) {
		return YES;	
	}
	return NO;	
}


- (void)tapGestureHandler:(UITapGestureRecognizer *)recognizer  {
    if (_currentPageIndex == NSNotFound) {
        return;
    }
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self deselectPageAtIndex:_selectedPageIndex animated:YES];
    } else if (recognizer.state == UIGestureRecognizerStateRecognized) {
        for (NBSwipePageViewSheet *page in _visiblePages) {
            if ([page pointInside:[recognizer locationInView:page] withEvent:nil]) {
                [self selectPageAtIndex:[self indexForVisiblePage:page] animated:YES scrollToMiddle:YES];
                return;
            }
        }
    }
}

@end
