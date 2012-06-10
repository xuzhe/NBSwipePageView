//
//  NBSPFirstViewController.h
//  NBSwipePageViewSample
//
//  Created by 徐 哲 on 5/15/12.
//  Copyright (c) 2012 ラクラクテクノロジーズ株式会社 Rakuraku Technologies, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NBSwipePageView.h"

@interface NBSPFirstViewController : UIViewController <NBSwipePageViewDelegate, NBSwipePageViewDataSource>

@property (strong, nonatomic) IBOutlet NBSwipePageView *swipePageView;
@end
