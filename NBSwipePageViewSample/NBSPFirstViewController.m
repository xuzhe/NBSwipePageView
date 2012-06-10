//
//  NBSPFirstViewController.m
//  NBSwipePageViewSample
//
//  Created by 徐 哲 on 5/15/12.
//  Copyright (c) 2012 ラクラクテクノロジーズ株式会社 Rakuraku Technologies, Inc. All rights reserved.
//

#import "NBSPFirstViewController.h"
#import "NBSwipePageViewSheet.h"

@interface NBSPFirstViewController ()

@end

@implementation NBSPFirstViewController
@synthesize swipePageView = _swipePageView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"First", @"First");
        self.tabBarItem.image = [UIImage imageNamed:@"first"];
    }
    return self;
}
							
- (void)viewDidLoad {
    [super viewDidLoad];
    _swipePageView.visibleViewEffectBlock = ^(id obj, NSUInteger idx, BOOL *stop) {
        *stop = YES;
        NBSwipePageViewSheet *page = (NBSwipePageViewSheet *)obj;
        CGFloat delta = floorf(_swipePageView.contentOffset.x - page.frame.origin.x + page.margin);

        CGFloat step = page.frame.size.width + page.margin * 2.0f;
        //NSLog(@"delta: %f, step: %f", delta, step);
        CGFloat scale = 1.0f - 0.2f * fabs(delta/step);
        page.contentView.transform = CGAffineTransformMakeScale(scale, scale);
        //NSLog(@"scale: %f", scale);
    };
    [_swipePageView reloadData];
}

- (void)viewDidUnload
{
    _swipePageView.visibleViewEffectBlock = nil;
    [self setSwipePageView:nil];
    
    [super viewDidUnload];
}

- (void)dealloc {
    _swipePageView.visibleViewEffectBlock = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (NSUInteger)numberOfPagesInSwipePageView:(NBSwipePageView *)swipePageView {
    return 10;
}

- (NBSwipePageViewSheet *)swipePageView:(NBSwipePageView *)swipePageView sheetForPageAtIndex:(NSUInteger)index {
    static NSString *identifier = @"abc";
    NBSwipePageViewSheet *page = [swipePageView dequeueReusableCellWithIdentifier:identifier];
    UILabel *label = nil;
    if (!page) {
        page = [[NBSwipePageViewSheet alloc] initWithFrame:self.view.bounds reuseIdentifier:identifier];
        label = [[UILabel alloc] initWithFrame:page.bounds];
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor yellowColor];
        [page.contentView addSubview:label];
        page.clipsToBounds = NO;
        label.center = page.contentView.center;
    }
    if (!label) {
        label = [[page.contentView subviews] objectAtIndex:0];
    }
    label.text = [NSString stringWithFormat:@"page: %d", index];
    return page;
}

@end
