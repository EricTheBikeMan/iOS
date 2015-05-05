/**
 * @file DetailsNodeInfoViewController.m
 * @brief View controller that show details info about a node
 *
 * (c) 2013-2015 by Mega Limited, Auckland, New Zealand
 *
 * This file is part of the MEGA SDK - Client Access Engine.
 *
 * Applications using the MEGA API must present a valid application key
 * and comply with the the rules set forth in the Terms of Service.
 *
 * The MEGA SDK is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * @copyright Simplified (2-clause) BSD License.
 *
 * You should have received a copy of the license along with this
 * program.
 */

#import "DetailsNodeInfoViewController.h"
#import "SVProgressHUD.h"
#import "Helper.h"

#import "BrowserViewController.h"
#import "CloudDriveTableViewController.h"

@interface DetailsNodeInfoViewController () <UIAlertViewDelegate, UITextFieldDelegate, MEGADelegate> {
    UIAlertView *renameAlertView;
    UIAlertView *removeAlertView;
}

@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *modificationTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UILabel *saveLabel;
@property (weak, nonatomic) IBOutlet UILabel *speedLabel;
@property (weak, nonatomic) IBOutlet UIButton *downloadButton;


@end

@implementation DetailsNodeInfoViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadUI];
    [[MEGASdkManager sharedMEGASdk] addMEGADelegate:self];
    [[MEGASdkManager sharedMEGASdk] retryPendingConnections];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[MEGASdkManager sharedMEGASdk] removeMEGADelegate:self];
}

- (void)reloadUI {
    
    if ([self.node type] == MEGANodeTypeFile) {
        if ([self.node hasThumbnail]) {
            NSString *thumbnailFilePath = [Helper pathForNode:self.node searchPath:NSCachesDirectory directory:@"thumbs"];
            BOOL thumbnailExists = [[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath];
            if (!thumbnailExists) {
                [self.thumbnailImageView setImage:[Helper imageForNode:self.node]];
            } else {
                [self.thumbnailImageView setImage:[UIImage imageWithContentsOfFile:thumbnailFilePath]];
            }
        } else {
            [self.thumbnailImageView setImage:[Helper imageForNode:self.node]];
        }
    } else if ([self.node type] == MEGANodeTypeFolder) {
        [self.thumbnailImageView setImage:[Helper imageForNode:self.node]];
    }
    
    self.nameLabel.text = [self.node name];
    
    struct tm *timeinfo;
    char buffer[80];
    time_t rawtime;
    if ([self.node isFile]) {
        rawtime = [[self.node modificationTime] timeIntervalSince1970];
    } else {
        rawtime = [[self.node creationTime] timeIntervalSince1970];
    }
    timeinfo = localtime(&rawtime);
    
    strftime(buffer, 80, "%d/%m/%y %H:%M", timeinfo);
    
    self.modificationTimeLabel.text = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    
    if ([self.node isFile]) {
        self.sizeLabel.text = [NSByteCountFormatter stringFromByteCount:[[self.node size] longLongValue] countStyle:NSByteCountFormatterCountStyleMemory];
    } else {
        self.sizeLabel.text = [NSByteCountFormatter stringFromByteCount:[[[MEGASdkManager sharedMEGASdk] sizeForNode:self.node] longLongValue] countStyle:NSByteCountFormatterCountStyleMemory];
    }
    
    self.title = [self.node name];
    
    if ([[Helper downloadedNodes] objectForKey:self.node.base64Handle] != nil) {
        [self.downloadProgressView setHidden:YES];
        [self.downloadButton setImage:[UIImage imageNamed:@"savedFile"] forState:UIControlStateNormal];
        [self.saveLabel setHidden:NO];
        [self.saveLabel setText:NSLocalizedString(@"savedForOffline", @"Saved for offline")];
    }
}

#pragma mark - IBActions

- (IBAction)touchUpInsideDownload:(UIButton *)sender {
    if (![Helper isFreeSpaceEnoughToDownloadNode:self.node]) {
        return;
    }
    
    if ([self.node type] == MEGANodeTypeFile) {
        [Helper downloadNode:self.node folder:@"" folderLink:NO];
    } else if ([self.node type] == MEGANodeTypeFolder) {
        NSString *folderName = [[[self.node base64Handle] stringByAppendingString:@"_"] stringByAppendingString:[[MEGASdkManager sharedMEGASdk] nameToLocal:[self.node name]]];
        NSString *folderPath = [[Helper pathForOffline] stringByAppendingPathComponent:folderName];
        
        if ([Helper createOfflineFolder:folderName folderPath:folderPath]) {
            [Helper downloadNodesOnFolder:folderPath parentNode:self.node folderLink:NO];
            [self.navigationController popViewControllerAnimated:YES];
            CloudDriveTableViewController *cloudDriveVC = [self.storyboard instantiateViewControllerWithIdentifier:@"CloudDriveID"];
            [cloudDriveVC setParentNode:self.node];
            [self.navigationController pushViewController:cloudDriveVC animated:YES];
        }
    }
}

- (IBAction)touchUpInsideGenerateLink:(UIButton *)sender {
    [[MEGASdkManager sharedMEGASdk] exportNode:self.node];
}

- (IBAction)touchUpInsideMove:(id)sender {
    UINavigationController *mcnc = [self.storyboard instantiateViewControllerWithIdentifier:@"moveNodeNav"];
    [self presentViewController:mcnc animated:YES completion:nil];
    
    BrowserViewController *mcnvc = mcnc.viewControllers.firstObject;
    mcnvc.parentNode = [[MEGASdkManager sharedMEGASdk] rootNode];
    mcnvc.selectedNodesArray = [NSArray arrayWithObject:self.node];
    
}

- (IBAction)touchUpInsideRename:(UIButton *)sender {
    if (!renameAlertView) {
        renameAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"renameNodeTitle", @"Rename") message:NSLocalizedString(@"renameNodeMessage", @"Enter the new name") delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", @"Cancel") otherButtonTitles:NSLocalizedString(@"renameNodeButton", @"Rename"), nil];
    }
    
    [renameAlertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [renameAlertView setTag:0];
    
    UITextField *textField = [renameAlertView textFieldAtIndex:0];
    [textField setDelegate:self];
    [textField setText:[self.node name]];
    
    [renameAlertView show];
}

- (IBAction)touchUpInsideDelete:(UIButton *)sender {
    if (!removeAlertView) {
        removeAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"moveNodeToRubbishBinTitle", @"Remove node") message:NSLocalizedString(@"moveNodeToRubbishBinMessage", @"Are you sure?") delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", @"Cancel") otherButtonTitles:NSLocalizedString(@"ok", @"OK"), nil];
    }
    [removeAlertView setTag:1];
    [removeAlertView show];
}

#pragma mark - UIAlertDelegate

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView {
    BOOL shouldEnable;
    if ([alertView tag] == 0) {
        UITextField *textField = [alertView textFieldAtIndex:0];
        NSString *newName = [textField text];
        NSString *newNameExtension = [newName pathExtension];
        NSString *newNameWithoutExtension = [newName stringByDeletingPathExtension];
        
        NSString *nodeNameString = [self.node name];
        NSString *nodeNameExtension = [NSString stringWithFormat:@".%@", [nodeNameString pathExtension]];
        
        switch ([self.node type]) {
            case MEGANodeTypeFile: {
                if ([newName isEqualToString:@""] ||
                    [newName isEqualToString:nodeNameString] ||
                    [newName isEqualToString:nodeNameExtension] ||
                    ![[NSString stringWithFormat:@".%@", newNameExtension] isEqualToString:nodeNameExtension] || //Particular case, for example: (.jp == .jpg)
                    [newNameWithoutExtension isEqualToString:nodeNameExtension]) {
                    shouldEnable = NO;
                } else {
                    shouldEnable = YES;
                }
                break;
            }
                
            case MEGANodeTypeFolder: {
                if ([newName isEqualToString:@""] || [newName isEqualToString:nodeNameString]) {
                    shouldEnable = NO;
                } else {
                    shouldEnable = YES;
                }
                break;
            }
                
            default:
                shouldEnable = NO;
                break;
        }
        
    } else {
        shouldEnable = YES;
    }
    
    return shouldEnable;
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([alertView tag] == 0) {
        UITextField *textField = [alertView textFieldAtIndex:0];
        [textField setSelectedTextRange:nil];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([alertView tag] == 0) {
        if (buttonIndex == 1) {
            UITextField *alertViewTextField = [alertView textFieldAtIndex:0];
            [[MEGASdkManager sharedMEGASdk] renameNode:self.node newName:[alertViewTextField text]];
        }
    } else if ([alertView tag] == 1) {
        if (buttonIndex == 1) {
            [[MEGASdkManager sharedMEGASdk] moveNode:self.node newParent:[[MEGASdkManager sharedMEGASdk] rubbishNode]];
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    NSString *nodeName = [textField text];
    UITextPosition *beginning = textField.beginningOfDocument;
    UITextRange *textRange;
    
    switch ([self.node type]) {
        case MEGANodeTypeFile: {
            if ([[nodeName pathExtension] isEqualToString:@""] && [nodeName isEqualToString:[nodeName stringByDeletingPathExtension]]) { //File without extension
                UITextPosition *end = textField.endOfDocument;
                textRange = [textField textRangeFromPosition:beginning  toPosition:end];
            } else {
                NSRange filenameRange = [nodeName rangeOfString:@"." options:NSBackwardsSearch];
                UITextPosition *beforeExtension = [textField positionFromPosition:beginning offset:filenameRange.location];
                textRange = [textField textRangeFromPosition:beginning  toPosition:beforeExtension];
            }
            [textField setSelectedTextRange:textRange];
            break;
        }
            
        case MEGANodeTypeFolder: {
            UITextPosition *end = textField.endOfDocument;
            textRange = [textField textRangeFromPosition:beginning  toPosition:end];
            [textField setSelectedTextRange:textRange];
            break;
        }
            
        default:
            break;
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    BOOL shouldChangeCharacters = YES;
    switch ([self.node type]) {
        case MEGANodeTypeFile: {
            NSString *textFieldString = [textField text];
            NSString *newName = [textFieldString stringByReplacingCharactersInRange:range withString:string];
            NSString *newNameExtension = [newName pathExtension];
            NSString *newNameWithoutExtension = [newName stringByDeletingPathExtension];
            
            NSString *nodeNameString = [self.node name];
            NSString *nodeNameExtension = [NSString stringWithFormat:@".%@", [nodeNameString pathExtension]];
            
            NSRange nodeWithoutExtensionRange = [[textFieldString stringByDeletingPathExtension] rangeOfString:[textFieldString stringByDeletingPathExtension]];
            NSRange nodeExtensionStartRange = [textFieldString rangeOfString:@"." options:NSBackwardsSearch];
            
            if ((range.location > nodeExtensionStartRange.location) ||
                (range.length > nodeWithoutExtensionRange.length) ||
                ([newName isEqualToString:newNameExtension] && [newNameWithoutExtension isEqualToString:nodeNameExtension]) ||
                ((range.location == nodeExtensionStartRange.location) && [string isEqualToString:@""])) {
                
                UITextPosition *beginning = textField.beginningOfDocument;
                UITextPosition *beforeExtension = [textField positionFromPosition:beginning offset:nodeExtensionStartRange.location];
                [textField setSelectedTextRange:[textField textRangeFromPosition:beginning toPosition:beforeExtension]];
                shouldChangeCharacters = NO;
            } else if (range.location < nodeExtensionStartRange.location) {
                shouldChangeCharacters = YES;
            }
            break;
        }
            
        case MEGANodeTypeFolder:
            shouldChangeCharacters = YES;
            break;
            
        default:
            shouldChangeCharacters = NO;
            break;
    }
    
    return shouldChangeCharacters;
}

#pragma mark - MEGARequestDelegate

- (void)onRequestStart:(MEGASdk *)api request:(MEGARequest *)request {
    switch ([request type]) {
        case MEGARequestTypeExport:
            [SVProgressHUD showWithStatus:NSLocalizedString(@"generateLink", @"Generate link...")];
            break;
            
        default:
            break;
    }
}

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if ([error type]) {
        return;
    }
    
    switch ([request type]) {
            
        case MEGARequestTypeGetAttrFile: {
            if ([request nodeHandle] == [self.node handle]) {
                MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:[request nodeHandle]];
                NSString *thumbnailFilePath = [Helper pathForNode:node searchPath:NSCachesDirectory directory:@"thumbs"];
                BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath];
                if (fileExists) {
                    [self.thumbnailImageView setImage:[UIImage imageWithContentsOfFile:thumbnailFilePath]];
                }
            }
            
            break;
        }
        case MEGARequestTypeExport: {
            [SVProgressHUD dismiss];
            
            MEGANode *n = [[MEGASdkManager sharedMEGASdk] nodeForHandle:request.nodeHandle];
            
            NSString *name = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"fileName", nil), n.name];
            NSString *size = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"fileSize", nil), n.isFile ? [NSByteCountFormatter stringFromByteCount:[[n size] longLongValue]  countStyle:NSByteCountFormatterCountStyleMemory] : NSLocalizedString(@"folder", nil)];
            NSString *link = [request link];
            
            NSArray *itemsArray = [NSArray arrayWithObjects:name, size, link, nil];
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:itemsArray applicationActivities:nil];
            activityVC.excludedActivityTypes = @[UIActivityTypePrint, UIActivityTypeCopyToPasteboard, UIActivityTypeAssignToContact, UIActivityTypeSaveToCameraRoll];
            [self presentViewController:activityVC animated:YES completion:nil];
            break;
        }
            
        default:
            break;
    }
}

- (void)onRequestUpdate:(MEGASdk *)api request:(MEGARequest *)request {
}

- (void)onRequestTemporaryError:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
}

#pragma mark - MEGAGlobalDelegate

- (void)onUsersUpdate:(MEGASdk *)api userList:(MEGAUserList *)userList{
}

- (void)onReloadNeeded:(MEGASdk *)api {
}

- (void)onNodesUpdate:(MEGASdk *)api nodeList:(MEGANodeList *)nodeList {
    self.node = [nodeList nodeAtIndex:0];
    [self reloadUI];
}

#pragma mark - MEGATransferDelegate

- (void)onTransferStart:(MEGASdk *)api transfer:(MEGATransfer *)transfer {
    if (transfer.type == MEGATransferTypeDownload) {
        NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
        NSNumber *transferTag = [[Helper downloadingNodes] objectForKey:base64Handle];
        if (([transferTag integerValue] == transfer.tag) && ([self.node.base64Handle isEqualToString:base64Handle])) {
            [self.downloadProgressView setHidden:NO];
            [self.downloadProgressView setProgress:0];
            [self.speedLabel setText:NSLocalizedString(@"queued", @"Queued")];
        }
    }
}

- (void)onTransferUpdate:(MEGASdk *)api transfer:(MEGATransfer *)transfer {
    if (transfer.type == MEGATransferTypeDownload) {
        NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
        NSNumber *transferTag = [[Helper downloadingNodes] objectForKey:base64Handle];
        if (([transferTag integerValue] == transfer.tag) && ([self.node.base64Handle isEqualToString:base64Handle])) {
            float progress = [[transfer transferredBytes] floatValue] / [[transfer totalBytes] floatValue];
            [self.downloadProgressView setProgress:progress];
            
            NSString *speed = [NSString stringWithFormat:@"%@/s", [NSByteCountFormatter stringFromByteCount:[[transfer speed] longLongValue]  countStyle:NSByteCountFormatterCountStyleMemory]];
            if ([speed isEqualToString:@"Zero KB/s"]) {
                speed = @"";
            }
            [self.speedLabel setText:speed];
        }
    }
}

- (void)onTransferFinish:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error {
    if ([error type]) {
        return;
    }
    
    if (transfer.type == MEGATransferTypeDownload) {
        NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
        if (([[Helper downloadedNodes] objectForKey:base64Handle] != nil) && ([self.node.base64Handle isEqualToString:base64Handle])) {
            [self.speedLabel setText:@""];
            
            [self.downloadProgressView setHidden:YES];
            [self.downloadProgressView setProgress:1];
            [self.saveLabel setHidden:NO];
            [self.downloadButton setImage:[UIImage imageNamed:@"savedFile"] forState:UIControlStateNormal];
            [self.saveLabel setText:NSLocalizedString(@"savedForOffline", @"Saved for offline")];
        }
    }
}

-(void)onTransferTemporaryError:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error {
}

@end
