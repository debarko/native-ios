//
//  jsFacebook.h
//  TeaLeafIOS
//
//  Created by Debarko on 19/04/13.
//  Copyright (c) 2013 Game Closure. All rights reserved.
//

#import "js/js_core.h"
#import <FacebookSDK/FacebookSDK.h>

@interface jsFacebook : NSObject

+ (void) addToRuntime:(js_core *)js;
+ (void) onDestroyRuntime;

@end
