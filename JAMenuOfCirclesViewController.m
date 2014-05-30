
#import "JAMenuOfCirclesViewController.h"
#import "JALayout.h"

@interface JAMenuOfCirclesViewController ()
{
    int _selectedIndex;
    CGPoint _prevButtonPosition;    // save prev button position for later restoration
    CGFloat _navHeight;             // height of the psuedo nav bar at top
    CGFloat _buttonVerticalGap;     // distance between edges of buttons in menu
    CGSize  _buttonSizeInitial;     // size of button in menu
    CGSize  _buttonSizeSmaller;     // size of shrunk button and close button
    CGFloat _buttonInset;           // distance from edge of button to edge of view, on left and right
    CGFloat _firstButtonInsetY;     // distance from top of view to top of first button
    
    CGFloat _buttonInsetSmaller;    // derived, distance from edge of smaller button to edge of view, on left and right
    CGPoint _topRight;              // derived, from _navHeight, _buttonSizeSmaller, _buttonInset
    CGFloat _offscreenX;            // derived, X position for offscreen
    CGFloat _onscreenX;             // derived, X position for onscreen
    
    CGFloat _animationDuration1;    // how long for selected button to move in/out of the nav header
    CGFloat _animationDuration2;    // how long to move selected button horizontally and fade title
    CGFloat _animationDurationMoveOffscreen;
}

@property (nonatomic) UIViewController *rootViewController;

@property (nonatomic) NSMutableArray *buttons;
@property (nonatomic) NSMutableArray *positionConstraints;
@property (nonatomic) NSMutableArray *sizeConstraints;

@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UIButton *closeButton;

@property (nonatomic) UIView *navHeader;
@property (nonatomic) NSLayoutConstraint *navHeaderFromTop;

@end

@implementation JAMenuOfCirclesViewController

- (id)initWithRootViewController:(UIViewController*)viewController
{
    self = [super init];
    if (self) {
        self.rootViewController = viewController;
        [self setupConstants];
    }
    return self;
}

- (void)awakeFromNib
{
    [self setupConstants];
}

- (void)setupConstants
{
    _navHeight = 50;
    _buttonVerticalGap = 25;
    _buttonSizeInitial = CGSizeMake(45, 45);
    _buttonSizeSmaller = CGSizeMake(30, 30);
    _buttonInset = 15;
    _buttonInsetSmaller = _buttonInset + 0.5*(_buttonSizeInitial.width - _buttonSizeSmaller.width);
    
    _firstButtonInsetY = _navHeight + 80;
    
    _animationDuration1 = 0.2;
    _animationDuration2 = 0.3;
    
    self.buttons             = [NSMutableArray array];
    self.positionConstraints = [NSMutableArray array];
    self.sizeConstraints     = [NSMutableArray array];
    self.viewControllers     = [NSMutableArray array];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Calculate derived values
    _topRight = CGPointMake(self.view.frame.size.width - _buttonInsetSmaller - 0.5*_buttonSizeSmaller.width, _navHeight / 2.0);
    _offscreenX = self.view.frame.size.width + 0.5*_buttonSizeInitial.width;
    _onscreenX  = self.view.frame.size.width - _buttonInset - 0.5*_buttonSizeInitial.width;
    
    // root view
    self.rootViewController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"root"];
    
    // nav header
    self.navHeader = [[UIView alloc] init];
    self.navHeader.backgroundColor = [UIColor darkGrayColor];
    self.navHeader.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.navHeader];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.navHeader attribute:NSLayoutAttributeWidth  relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.navHeader attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:_navHeight]];
    
    [self.navHeader centerHorizontallyInSuperview];
    self.navHeaderFromTop = [NSLayoutConstraint constraintWithItem:self.navHeader attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0];
    [self.view addConstraint:self.navHeaderFromTop];
    
    // close button
    self.closeButton = [[UIButton alloc] init];
    self.closeButton.hidden = YES;
    [self.closeButton setBackgroundImage:[UIImage imageNamed:@"closebutton"] forState:UIControlStateNormal];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.navHeader addSubview:self.closeButton];
    [self.closeButton centerVerticallyInSuperview];
    [self.closeButton compressSizeTo:_buttonSizeSmaller];
    [self.navHeader addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[close]-inset-|" options:0 metrics:@{@"inset": @(_buttonInsetSmaller)} views:@{@"close": self.closeButton}]];
    
    [self.closeButton addTarget:self action:@selector(goBack:) forControlEvents:UIControlEventTouchUpInside];
    
    // title label
    self.titleLabel = [[UILabel alloc] init];
    [self.titleLabel setTextColor:[UIColor whiteColor]];
    [self.titleLabel setFont:[UIFont boldSystemFontOfSize:20]];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.navHeader addSubview:self.titleLabel];
    [self.titleLabel centerInSuperview];
    [JALayout sizeView:self.titleLabel toSize:CGSizeMake(self.view.frame.size.width - 2*_buttonInsetSmaller, _navHeight)];  // width is larger than text to make masking animation easier
    
    [self.view layoutIfNeeded];
    
    // title mask
    CALayer *mask = [[CALayer alloc] init];
    mask.backgroundColor = [UIColor whiteColor].CGColor;    // color doesn't matter, alpha matters
    mask.anchorPoint = CGPointMake(0, 0);
    mask.bounds = self.titleLabel.bounds;
    mask.position = CGPointMake(self.titleLabel.frame.size.width, 0);
    self.titleLabel.layer.mask = mask;
    
    // configure menu options (factor this out later, just a demo for now)
    NSMutableArray *newOnes = [NSMutableArray array];
    for (NSString *name in @[@"vc1", @"vc2", @"vc3"]) {
        UIViewController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:name];
        [newOnes addObject:vc];
    }
    self.viewControllers = [newOnes copy];
}

- (void)setRootViewController:(UIViewController *)rootViewController
{
    _rootViewController = rootViewController;
    [self addChildViewController:rootViewController];
    [self.view addSubviewAndStretchToFill:rootViewController.view];
    [rootViewController didMoveToParentViewController:self];
}

- (void)setViewControllers:(NSArray *)viewControllers
{
    // remove all buttons
    [self.buttons makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.positionConstraints removeAllObjects];
    [self.sizeConstraints removeAllObjects];
    
    _viewControllers = viewControllers;
    CGPoint buttonSpot = CGPointMake(_topRight.x, _firstButtonInsetY + 0.5*_buttonSizeInitial.height);
    
    for (int i = 0; i < [viewControllers count]; i++) {
        UIButton *button = [[UIButton alloc] init];
        
        button.tag = i;
        [button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        // get a random picture for the button
        NSString *imageName;
        NSInteger randomNumber = arc4random() % 61;
        imageName = [NSString stringWithFormat:@"free-60-icons-%02d", randomNumber];
        [button setBackgroundImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
        
        JAPositionConstraint *positionConstraint = [JALayout positionView:button inView:self.view atPoint:buttonSpot];
        [self.positionConstraints addObject:positionConstraint];
        
        JASizeConstraint *sizeConstraint = [JALayout sizeView:button toSize:_buttonSizeInitial];
        [self.sizeConstraints addObject:sizeConstraint];
        
        [self.buttons addObject:button];
        
        buttonSpot.y += _buttonSizeInitial.height + _buttonVerticalGap;
    }
}

- (void)buttonPressed:(id)sender
{
    UIButton *button = sender;
    _selectedIndex = button.tag;
    
    self.titleLabel.text = [self.viewControllers[_selectedIndex] title];
    
    /* Step 1 - Animated buttons offscreen. Animate selected button to top right and shrink. Dim screen. */
    
    // animate button constraints
    for (int i = 0; i < [self.buttons count]; i++) {
        
        JAPositionConstraint *position = self.positionConstraints[i];
        JASizeConstraint         *size = self.sizeConstraints[i];
        
        // selected button
        if (i == _selectedIndex) {
            _prevButtonPosition = position.position;
            [position setY:0.5*_navHeight];     // move up
            [size setSize:_buttonSizeSmaller];  // shrink during movement
            
        // other buttons
        } else {
            position.x = _offscreenX;           // move offscreen
        }
    }
    
    // animate nav bar down
    self.navHeaderFromTop.constant = _navHeight;
    
    [UIView animateWithDuration:_animationDuration1 delay:0.0 options:UIViewAnimationOptionCurveEaseIn
    animations:^{
        // animate other button properties
        for (int i = 0; i < [self.buttons count]; i++) {
            
            UIButton *button = self.buttons[i];
            
            button.userInteractionEnabled = NO;
            
            // optional other stuff
        }
        
        [self.view layoutIfNeeded];
    }
    completion:^(BOOL finished) {
        
        /* Step 2 - Animate selected button to top left, cross fade into new view. Fade in close button. Reveal title */
        
        // container VC crap
        UIViewController *subVC = self.viewControllers[_selectedIndex];
        [self addChildViewController:subVC];
        [self.view insertSubviewAndStretchToFill:subVC.view aboveSubview:self.rootViewController.view];
        [subVC didMoveToParentViewController:self];
        subVC.view.alpha = 0.0;
        
        // move button to top left corner
        [(JAPositionConstraint*)self.positionConstraints[_selectedIndex] setX:_buttonInsetSmaller + _buttonSizeSmaller.width * 0.5];
        
        // reveal close button from under moving button
        self.closeButton.hidden = NO;
        
        // animate title mask, move left
        [self showTitle:YES];
        
        // animation block
        [UIView animateWithDuration:_animationDuration2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut
        animations:^{
            
            // fade in new view
            subVC.view.alpha = 1.0;
            
            [self.view layoutIfNeeded];
        }
        completion:nil];
    }];
}

- (void)showTitle:(BOOL)visible
{
    CGPoint visiblePosition = CGPointZero;
    CGPoint hiddenPosition = CGPointMake(self.titleLabel.bounds.size.width, 0);
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:(visible ? kCAMediaTimingFunctionEaseOut : kCAMediaTimingFunctionEaseIn)];
    
    animation.fromValue = [NSValue valueWithCGPoint:self.titleLabel.layer.mask.position];
    animation.toValue   = [NSValue valueWithCGPoint:(visible ? visiblePosition : hiddenPosition)];
    animation.duration = _animationDuration2;
    
    self.titleLabel.layer.mask.position = [animation.toValue CGPointValue];    // animation values do not persist
    [self.titleLabel.layer.mask addAnimation:animation forKey:@"position"];
}

- (void)goBack:(id)sender
{
    /* Step 1 */
    
    // Move button right
    JAPositionConstraint *position = self.positionConstraints[_selectedIndex];
    [position setPosition:_topRight];
    
    // animate title mask
    [self showTitle:NO];
    
    [UIView animateWithDuration:_animationDuration2 delay:0.0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         // cross fade views
                         [(UIViewController*)self.viewControllers[_selectedIndex] view].alpha = 0.0;
                         
                         [self.view layoutIfNeeded];
                         
                     } completion:^(BOOL finished) {
                         
                         /* Step 2 */
                         
                         // dissapear close button
                         self.closeButton.hidden = YES;
                         
                         // animate buttons
                         for (int i = 0; i < [self.buttons count]; i++) {
                             
                             JAPositionConstraint *position = self.positionConstraints[i];
                             JASizeConstraint         *size = self.sizeConstraints[i];
                             
                             // selected button
                             if (i == _selectedIndex) {
                                 [position setPosition:_prevButtonPosition];    // move back down
                                 [size setSize:_buttonSizeInitial];             // grow button during movement
                                
                             // other buttons
                             } else {
                                 position.x = _onscreenX;  // move onscreen
                             }
                         }
                         
                         // move header offscreen
                         self.navHeaderFromTop.constant = 0;
                         
                         [UIView animateWithDuration:_animationDuration1 delay:0.0 options:UIViewAnimationOptionCurveEaseOut
                                          animations:^{
                                              [self.view layoutIfNeeded];
                                          }
                                          completion:^(BOOL finished){
                                              
                                              // child VC cleanup
                                              UIViewController *childVC = self.viewControllers[_selectedIndex];
                                              [childVC willMoveToParentViewController:nil];
                                              [childVC.view removeFromSuperview];
                                              [childVC removeFromParentViewController];
                                              
                                              // renable buttons
                                              for (JAPositionConstraint *position in self.positionConstraints) {
                                                  UIButton *button = (UIButton*)position.view;
                                                  button.userInteractionEnabled = YES;
                                              }
                                          }];
                     }];
}

@end
