/* @license
 * This file is part of the Game Closure SDK.
 *
 * The Game Closure SDK is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 
 * The Game Closure SDK is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 
 * You should have received a copy of the GNU General Public License
 * along with the Game Closure SDK.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <UIKit/UIKit.h>
#import "js_core.h"
#import <MessageUI/MFMessageComposeViewController.h>
#import <AddressBookUI/ABPeoplePickerNavigationController.h>

@interface TeaLeafViewController : UIViewController <MFMessageComposeViewControllerDelegate, UINavigationControllerDelegate, ABPeoplePickerNavigationControllerDelegate, UIActionSheetDelegate> {
@private
int callback;
UIAlertView *message;
}

@property (nonatomic, retain) UIImageView *loading_image_view;
@property (nonatomic, retain) UIAlertView *backAlertView;
- (TeaLeafViewController*) init;

- (void)pickContact: (int) cb;
- (void)sendSMSTo: (NSString*)number withMessage: (NSString*)message andCallback: (int) callback;
- (void)messageComposeViewController: (MFMessageComposeViewController*) controller didFinishWithResult: (MessageComposeResult) result;
- (void)alertView: (UIAlertView*) sheet clickedButtonAtIndex: (NSInteger) buttonIndex;

- (void)assignCallback: (int) cb;
- (void)runCallback: (char*) arg;
- (void)destroyDisplayLink;
@end

@interface UIAlertViewEx : UIAlertView {
@private
    int* callbacks;
	int length;
}
- (void) dispatch: (int) callback;
- (void) registerCallbacks: (int*) callbacks length: (int) length;
- (void) dealloc;

@end
