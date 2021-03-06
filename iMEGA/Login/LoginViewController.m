#import "LoginViewController.h"

#import "SAMKeychain.h"
#import "SVProgressHUD.h"

#import "Helper.h"
#import "MEGAMultiFactorAuthCheckRequestDelegate.h"
#import "MEGANavigationController.h"
#import "MEGALoginRequestDelegate.h"
#import "MEGALogger.h"
#import "MEGAReachabilityManager.h"
#import "MEGASdkManager.h"
#import "NSString+MNZCategory.h"

#import "CreateAccountViewController.h"
#import "TwoFactorAuthenticationViewController.h"
#import "PasswordView.h"

@interface LoginViewController () <UITextFieldDelegate, MEGARequestDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *logoImageView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *logoTopLayoutConstraint;

@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet PasswordView *passwordView;

@property (weak, nonatomic) IBOutlet UIButton *loginButton;

@property (weak, nonatomic) IBOutlet UIButton *createAccountButton;
@property (weak, nonatomic) IBOutlet UIButton *forgotPasswordButton;

@end

@implementation LoginViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (([[UIDevice currentDevice] iPhone4X])) {
        self.logoTopLayoutConstraint.constant = 24.f;
    }
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(logoTappedFiveTimes:)];
    tapGestureRecognizer.numberOfTapsRequired = 5;
    UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(logoPressedFiveSeconds:)];
    longPressGestureRecognizer.minimumPressDuration = 5.0f;
    self.logoImageView.gestureRecognizers = @[tapGestureRecognizer, longPressGestureRecognizer];
    
    [self.emailTextField setPlaceholder:AMLocalizedString(@"emailPlaceholder", @"Email")];
    self.passwordView.passwordTextField.delegate = self;
    self.passwordView.passwordTextField.tag = 1;
    self.passwordView.passwordTextField.textColor = UIColor.mnz_black333333;
    self.passwordView.passwordTextField.font = [UIFont mnz_SFUIRegularWithSize:17];

    [self.loginButton setTitle:AMLocalizedString(@"login", @"Login") forState:UIControlStateNormal];
    self.loginButton.backgroundColor = UIColor.mnz_grayEEEEEE;
    
    [self.createAccountButton setTitle:AMLocalizedString(@"createAccount", nil) forState:UIControlStateNormal];
    NSString *forgotPasswordString = AMLocalizedString(@"forgotPassword", @"An option to reset the password.");
    forgotPasswordString = [forgotPasswordString stringByReplacingOccurrencesOfString:@"?" withString:@""];
    forgotPasswordString = [forgotPasswordString stringByReplacingOccurrencesOfString:@"¿" withString:@""];
    [self.forgotPasswordButton setTitle:forgotPasswordString forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
    [self.navigationItem setTitle:AMLocalizedString(@"login", nil)];
    
    if (self.emailString) {
        self.emailTextField.text = self.emailString;
        self.emailString = nil;
        
        [self.passwordView.passwordTextField becomeFirstResponder];
    } else {
        self.emailTextField.placeholder = AMLocalizedString(@"emailPlaceholder", @"Hint text to suggest that the user has to write his email");
    }
    
    [[MEGALogger sharedLogger] enableChatlogs];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([[UIDevice currentDevice] iPhoneDevice]) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - IBActions

- (IBAction)tapLogin:(id)sender {
    if ([MEGASdkManager sharedMEGAChatSdk] == nil) {
        [MEGASdkManager createSharedMEGAChatSdk];
    }
    
    if ([[MEGASdkManager sharedMEGAChatSdk] initState] != MEGAChatInitWaitingNewSession) {
        MEGAChatInit chatInit = [[MEGASdkManager sharedMEGAChatSdk] initKarereWithSid:nil];
        if (chatInit != MEGAChatInitWaitingNewSession) {
            MEGALogError(@"Init Karere without sesion must return waiting for a new sesion");
            [[MEGASdkManager sharedMEGAChatSdk] logout];
        }
    }
    
    [self.emailTextField resignFirstResponder];
    [self.passwordView.passwordTextField resignFirstResponder];
    
    if ([self validateForm]) {
        if ([MEGAReachabilityManager isReachableHUDIfNot]) {
            MEGALoginRequestDelegate *loginRequestDelegate = [[MEGALoginRequestDelegate alloc] init];
            loginRequestDelegate.errorCompletion = ^(MEGAError *error) {
                if (error.type == MEGAErrorTypeApiEMFARequired) {
                    TwoFactorAuthenticationViewController *twoFactorAuthenticationVC = [[UIStoryboard storyboardWithName:@"TwoFactorAuthentication" bundle:nil] instantiateViewControllerWithIdentifier:@"TwoFactorAuthenticationViewControllerID"];
                    twoFactorAuthenticationVC.twoFAMode = TwoFactorAuthenticationLogin;
                    twoFactorAuthenticationVC.email = self.emailTextField.text;
                    twoFactorAuthenticationVC.password = self.passwordView.passwordTextField.text;
                    
                    [self.navigationController pushViewController:twoFactorAuthenticationVC animated:YES];
                }
            };
            [[MEGASdkManager sharedMEGASdk] loginWithEmail:self.emailTextField.text password:self.passwordView.passwordTextField.text delegate:loginRequestDelegate];
        }
    }
}

- (IBAction)forgotPasswordTouchUpInside:(UIButton *)sender {
    [Helper presentSafariViewControllerWithURL:[NSURL URLWithString:@"https://mega.nz/recovery"]];
}

#pragma mark - Private

- (void)logoTappedFiveTimes:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [Helper enableOrDisableLog];
    }
}

- (void)logoPressedFiveSeconds:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        [Helper changeApiURL];
    }
}

- (BOOL)validateForm {
    if (!self.emailTextField.text.mnz_isValidEmail) {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"emailInvalidFormat", @"Enter a valid email")];
        [self.emailTextField becomeFirstResponder];
        return NO;
    } else if (![self validatePassword:self.passwordView.passwordTextField.text]) {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"passwordInvalidFormat", @"Enter a valid password")];
        [self.passwordView.passwordTextField becomeFirstResponder];
        return NO;
    }
    return YES;
}

- (BOOL)validatePassword:(NSString *)password {
    if (password.length == 0) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)isEmptyAnyTextFieldForTag:(NSInteger )tag {
    BOOL isAnyTextFieldEmpty = NO;
    switch (tag) {
        case 0: {
            if ([self.passwordView.passwordTextField.text isEqualToString:@""]) {
                isAnyTextFieldEmpty = YES;
            }
            break;
        }
            
        case 1: {
            if ([self.emailTextField.text isEqualToString:@""]) {
                isAnyTextFieldEmpty = YES;
            }
            break;
        }
    }
    
    return isAnyTextFieldEmpty;
}

- (NSString *)timeFormatted:(NSUInteger)totalSeconds {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterNoStyle;
    dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    NSString *currentLanguageID = [[LocalizationSystem sharedLocalSystem] getLanguage];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:currentLanguageID];
    
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:totalSeconds];
    
    return [dateFormatter stringFromDate:date];
}

#pragma mark - UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

#pragma mark - UIViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"CreateAccountStoryboardSegueID"] && [sender isKindOfClass:[NSString class]]) {
        MEGANavigationController *createAccountNC = (MEGANavigationController *)segue.destinationViewController;
        CreateAccountViewController *createAccountVC = (CreateAccountViewController *)createAccountNC.childViewControllers.firstObject;
        [createAccountVC setEmailString:sender];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *text = [textField.text stringByReplacingCharactersInRange:range withString:string];
    BOOL shoulBeLoginButtonGray = NO;
    if ([text isEqualToString:@""] || (!self.emailTextField.text.mnz_isValidEmail)) {
        shoulBeLoginButtonGray = YES;
    } else {
        shoulBeLoginButtonGray = [self isEmptyAnyTextFieldForTag:textField.tag];
    }
    
    self.loginButton.backgroundColor = shoulBeLoginButtonGray ? UIColor.mnz_grayEEEEEE : UIColor.mnz_redMain;
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    self.loginButton.backgroundColor = UIColor.mnz_grayEEEEEE;
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    switch (textField.tag) {
        case 0:
            [self.passwordView.passwordTextField becomeFirstResponder];
            break;
            
        case 1:
            [self.passwordView.passwordTextField resignFirstResponder];
            [self tapLogin:self.loginButton];
            break;
            
        default:
            break;
    }
    
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField.tag == 1) {
        self.passwordView.rightImageView.hidden = NO;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.tag == 1) {
        self.passwordView.rightImageView.hidden = YES;
    }
}

@end
