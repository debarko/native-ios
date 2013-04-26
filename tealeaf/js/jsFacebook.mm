//
//  jsFacebook.m
//  TeaLeafIOS
//
//  Created by Debarko on 19/04/13.
//  Copyright (c) 2013 Game Closure. All rights reserved.
//
/*
 //Examples: Concatenation:
 
 - (NSString*) concatenateString:(NSString*)stringA withString:(NSString*)stringB
 {
 NSString *finalString = [NSString stringWithFormat:@"%@%@", stringA,
 stringB];
 return finalString;
 }
 // The advantage of this method is that it is simple to put text between the
 // two strings (e.g. Put a "-" replace %@%@ by %@ - %@ and that will put a
 // dash between stringA and stringB
 //String Length:
 
 - (int) stringLength:(NSString*)string
 {
 return [string length];
 //Not sure for east-asian languages, but works fine usually
 }
 
 //Remove text from string:
 
 - (NSString*)remove:(NSString*)textToRemove fromString:(NSString*)input
 {
 return [input stringByReplacingOccurrencesOfString:textToRemove
 withString:@""];
 }
 
 //Uppercase / Lowercase / Titlecase:
 
 - (NSString*)uppercase:(NSString*)stringToUppercase
 {
 return [stringToUppercase upercaseString];
 }
 
 - (NSString*)lowercase:(NSString*)stringToLowercase
 {
 return [stringToUppercase lowercaseString];
 }
 
 //Find/Replace
 
 - (NSString*)findInString:(NSString*)string
 replaceWithString:(NSString*)stringToReplaceWith
 {
 return [input stringByReplacingOccurrencesOfString:string
 withString:stringToReplaceWith];
 }
 */

#import "jsFacebook.h"
#import "core/events.h"
#import "js/jsXHR.h"
#import "core/platform/xhr.h"
#import "platform/xhr.h"
#import "platform/log.h"

static js_core *m_core = nil;

JSAG_MEMBER_BEGIN(logger, 1)
{
    
	JSAG_ARG_NSTR(msg);
    NSLog(@"%@",msg);
}
JSAG_MEMBER_END

JSAG_MEMBER_BEGIN(inviteFriends, 1)
{
	JSAG_ARG_NSTR(msg);
    NSData* returnedData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *paramData;
    if(NSClassFromString(@"NSJSONSerialization"))
    {
        NSError *error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:returnedData options:0 error:&error];
        if(error) { /* JSON was malformed, act appropriately here */ }
        if([object isKindOfClass:[NSDictionary class]])
        {
            paramData = object;
        }
    }
    else
    {
        //iOS 4 Handler
    }
    NSMutableDictionary* params;
    
    params =   [NSMutableDictionary dictionaryWithObjectsAndKeys:[paramData valueForKey:@"data"], @"to",nil];
//  params =   [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
    [FBWebDialogs presentRequestsDialogModallyWithSession:nil
                                                  message:[NSString stringWithFormat:@"I just completed a milestone. Wanna challenge me? Come on to Sudoku Quest and lets fight."]
                                                    title:nil
                                               parameters:params
                                                  handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
                                                      if (error) {
                                                          // Case A: Error launching the dialog or sending request.
                                                          NSLog(@"Error sending request.");
                                                      } else {
                                                          if (result == FBWebDialogResultDialogNotCompleted) {
                                                              // Case B: User clicked the "x" icon
                                                              NSLog(@"User canceled request.");
                                                          } else {
                                                              NSLog(@"Request Sent.");
                                                          }
                                                      }}];
}
JSAG_MEMBER_END

JSAG_MEMBER_BEGIN(getName, 1)
{
	JSAG_ARG_NSTR(msg);
    NSDictionary *paramData;
    NSData* returnedData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    
    if(NSClassFromString(@"NSJSONSerialization"))
    {
        NSError *error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:returnedData options:0 error:&error];
        
        if(error) { /* JSON was malformed, act appropriately here */ }
        
        // the originating poster wants to deal with dictionaries;
        // assuming you do too then something like this is the first
        // validation step:
        if([object isKindOfClass:[NSDictionary class]])
        {
            paramData = object;
            /* proceed with results as you like; the assignment to
             an explicit NSDictionary * is artificial step to get
             compile-time checking from here on down (and better autocompletion
             when editing). You could have just made object an NSDictionary *
             in the first place but stylistically you might prefer to keep
             the question of type open until it's confirmed */
        }
        else
        {
            /* there's no guarantee that the outermost object in a JSON
             packet will be a dictionary; if we get here then it wasn't,
             so 'object' shouldn't be treated as an NSDictionary; probably
             you need to report a suitable error condition */
        }
    }
    else
    {
        // the user is using iOS 4; we'll need to use a third-party solution.
        // If you don't intend to support iOS 4 then get rid of this entire
        // conditional and just jump straight to
        // NSError *error = nil;
        // [NSJSONSerialization JSONObjectWithData:...
    }
    [FBRequestConnection startWithGraphPath:[paramData valueForKey:@"uid"] parameters:[NSDictionary dictionaryWithObject:@"name,first_name,last_name,picture" forKey:@"fields"] HTTPMethod:@"GET" completionHandler:^(FBRequestConnection *connection, id result, NSError *error)
     {
         if (!error) {
             NSString *uid=[NSString stringWithFormat:@"{\"name\":\"%@\",\"first_name\":\"%@\",\"last_name\":\"%@\",\"error\":\"FREE\"}",[result name],[result first_name],[result last_name]];
             JSContext *cx = m_core.cx;
             JS_BeginRequest(cx);
             JSObject* userPtr = JS_NewObject(cx,NULL,NULL,NULL);
             
             jsval temp = NSTR_TO_JSVAL(cx, uid);
             int myID = 786;
             jsval jsid, userPtr_val, jsname;
             jsid = INT_TO_JSVAL(myID);
             jsname = NSTR_TO_JSVAL(cx, [paramData valueForKey:@"handler"]);
             
             JS_SetProperty(cx, userPtr, "returnMessage", &temp);
             JS_SetProperty(cx, userPtr, "id", &jsid);
             JS_SetProperty(cx, userPtr, "name", &jsname);
             userPtr_val = OBJECT_TO_JSVAL(userPtr);
             
             [m_core dispatchEvent:&userPtr_val count:1];
             
             JS_EndRequest(cx);
         }
         else
         {
             JSAG_RETURN_NSTR(@"ERROR");
         }
     }];
}
JSAG_MEMBER_END

JSAG_MEMBER_BEGIN(login, 1)
{
	JSAG_ARG_NSTR(msg);
    NSData* returnedData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *paramData;
    if(NSClassFromString(@"NSJSONSerialization"))
    {
        NSError *error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:returnedData options:0 error:&error];
        if(error) { /* JSON was malformed, act appropriately here */ }
        if([object isKindOfClass:[NSDictionary class]])
        {
            paramData = object;
        }
    }
    else
    {
        //iOS 4 Handler
    }
    NSArray *permissions = [[NSArray alloc] initWithObjects: @"email", nil];
    NSArray* writePermissions = [[NSArray alloc] initWithObjects:@"publish_stream",nil];
    // Attempt to open the session. If the session is not open, show the user the Facebook login UX
    [FBSession openActiveSessionWithReadPermissions:permissions allowLoginUI:true completionHandler:^(FBSession *session, FBSessionState status, NSError *error)
     {
         // Did something go wrong during login? I.e. did the user cancel?
         if (status == FBSessionStateClosedLoginFailed || status == FBSessionStateCreatedOpening) {
             
             // If so, just send them round the loop again
             [[FBSession activeSession] closeAndClearTokenInformation];
             [FBSession setActiveSession:nil];
             FBSession* session = [[FBSession alloc] init];
             [FBSession setActiveSession: session];
         }
         [FBRequestConnection startWithGraphPath:@"me" parameters:[NSDictionary dictionaryWithObject:@"name,id" forKey:@"fields"] HTTPMethod:@"GET" completionHandler:^(FBRequestConnection *connection, id result, NSError *error)
          {
              if (!error) {
                  NSString *uid=[NSString stringWithFormat:@"{\"uid\":%@,\"name\":\"%@\",\"error\":\"FREE\"}",[result id],[result name]];
                  JSContext *cx = m_core.cx;
                  JS_BeginRequest(cx);
                  JSObject* userPtr = JS_NewObject(cx,NULL,NULL,NULL);
                  
                  jsval temp = NSTR_TO_JSVAL(cx, uid);
                  int myID = 786;
                  jsval jsid, userPtr_val, jsname;
                  jsid = INT_TO_JSVAL(myID);
                  jsname = NSTR_TO_JSVAL(cx, [paramData valueForKey:@"handler"]);
                  
                  JS_SetProperty(cx, userPtr, "returnMessage", &temp);
                  JS_SetProperty(cx, userPtr, "id", &jsid);
                  JS_SetProperty(cx, userPtr, "name", &jsname);
                  userPtr_val = OBJECT_TO_JSVAL(userPtr);
                  
                  [m_core dispatchEvent:&userPtr_val count:1];
                  
                  JS_EndRequest(cx);
                  
                  /*
                   
                   dispatch_async(dispatch_get_current_queue(), ^{
                   [[FBSession activeSession] reauthorizeWithPublishPermissions:writePermissions
                   defaultAudience:FBSessionDefaultAudienceEveryone
                   completionHandler:^(FBSession *session, NSError *error) {
                   // handle the flow here
                   }];
                   });
                   
                   
                   */
              }
              else
              {
                  JSAG_RETURN_NSTR(@"ERROR");
              }
          }];
     }];
}
JSAG_MEMBER_END


JSAG_MEMBER_BEGIN(ogCall, 1)
{
    JSAG_ARG_NSTR(msg);
    NSData* returnedData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *paramData;
    if(NSClassFromString(@"NSJSONSerialization"))
    {
        NSError *error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:returnedData options:0 error:&error];
        if(error) { /* JSON was malformed, act appropriately here */ }
        if([object isKindOfClass:[NSDictionary class]])
        {
            paramData = object;
        }
    }
    else
    {
        //iOS 4 Handler
    }
    FBRequest* newAction = [[FBRequest alloc]initForPostWithSession:[FBSession activeSession] graphPath:[NSString stringWithFormat:@"%@",[paramData valueForKey:@"url"]] graphObject:nil];
    
    FBRequestConnection* conn = [[FBRequestConnection alloc] init];
    
    [conn addRequest:newAction completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if(error) {
            NSLog(@"Sending OG Story Failed: %@", result[@"id"]);
            return;
        }
        
        NSLog(@"OG action ID: %@", result[@"id"]);
    }];
    [conn start];
}
JSAG_MEMBER_END


JSAG_MEMBER_BEGIN(getPic, 1)
{
    JSAG_ARG_NSTR(msg);
    NSData* returnedData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *paramData;
    if(NSClassFromString(@"NSJSONSerialization"))
    {
        NSError *error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:returnedData options:0 error:&error];
        if(error) { /* JSON was malformed, act appropriately here */ }
        if([object isKindOfClass:[NSDictionary class]])
        {
            paramData = object;
        }
    }
    else
    {
        //iOS 4 Handler
    }
    NSString* url=[NSString stringWithFormat:@"http://graph.facebook.com/%@/picture?width=%@&height=%@",[paramData valueForKey:@"uid"],[paramData valueForKey:@"width"],[paramData valueForKey:@"height"]];
    JSAG_RETURN_NSTR(url);
}
JSAG_MEMBER_END


JSAG_MEMBER_BEGIN(logout, 0)
{
    [FBSession.activeSession closeAndClearTokenInformation];
}
JSAG_MEMBER_END


JSAG_MEMBER_BEGIN(getFriends, 1)
{
    FBRequest* friendsRequest = [FBRequest requestForMyFriends];
    [friendsRequest startWithCompletionHandler: ^(FBRequestConnection *connection,
                                                  NSDictionary* result,
                                                  NSError *error) {
        NSArray* friends = [result objectForKey:@"data"];
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:friends options:0 error:&error];
        
        if (!jsonData) {
            NSLog(@"JSON error: %@", error);
        } else {
            NSString *JSONString = [[NSString alloc] initWithBytes:[jsonData bytes] length:[jsonData length] encoding:NSUTF8StringEncoding];
            JSAG_RETURN_NSTR(JSONString);
        }
        
    }];

}
JSAG_MEMBER_END

JSAG_MEMBER_BEGIN(getGameFriends, 1)
{
    JSAG_ARG_NSTR(msg);
    NSData* returnedData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *paramData;
    if(NSClassFromString(@"NSJSONSerialization"))
    {
        NSError *error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:returnedData options:0 error:&error];
        if(error) { /* JSON was malformed, act appropriately here */ }
        if([object isKindOfClass:[NSDictionary class]])
        {
            paramData = object;
        }
    }
    else
    {
        //iOS 4 Handler
    }
    NSString *fql = [NSString stringWithFormat:@"SELECT uid FROM user WHERE is_app_user = 1 AND uid IN (SELECT uid2 FROM friend WHERE uid1 = %@)",[paramData valueForKey:@"uid"]];
    
    // Set up the query parameter
    NSDictionary *queryParam = [NSDictionary dictionaryWithObjectsAndKeys:fql, @"q", nil];
    // Make the API request that uses FQL
    [FBRequestConnection startWithGraphPath:@"/fql" parameters:queryParam HTTPMethod:@"GET" completionHandler:^(FBRequestConnection *connection, id result, NSError *error)
    {
        if (error) {
            NSLog(@"Error: %@", [error localizedDescription]);
        } else {
            NSString *gameFriends=[NSString stringWithFormat:@"{\"uid\":%@,\"error\":\"FREE\"}",result];
            JSContext *cx = m_core.cx;
            JS_BeginRequest(cx);
            JSObject* userPtr = JS_NewObject(cx,NULL,NULL,NULL);
            
            jsval temp = NSTR_TO_JSVAL(cx, gameFriends);
            int myID = 786;
            jsval jsid, userPtr_val, jsname;
            jsid = INT_TO_JSVAL(myID);
            jsname = NSTR_TO_JSVAL(cx, [paramData valueForKey:@"handler"]);
            
            JS_SetProperty(cx, userPtr, "returnMessage", &temp);
            JS_SetProperty(cx, userPtr, "id", &jsid);
            JS_SetProperty(cx, userPtr, "name", &jsname);
            userPtr_val = OBJECT_TO_JSVAL(userPtr);
            
            [m_core dispatchEvent:&userPtr_val count:1];
            
            JS_EndRequest(cx);
        }
    }];
}
JSAG_MEMBER_END


JSAG_OBJECT_START(fbapi)
//The function below is just a logger for NATIVE Platform from the Javascript End
JSAG_OBJECT_MEMBER(logger)
//This function Logs in a User - Return 0 for new login, 1 for relogin
JSAG_OBJECT_MEMBER(login)
//This function gets basic user info based on UID parameter.
JSAG_OBJECT_MEMBER(getName)
//This function publishes invites to friends
JSAG_OBJECT_MEMBER(ogCall)
JSAG_OBJECT_MEMBER(getPic)
JSAG_OBJECT_MEMBER(inviteFriends)
JSAG_OBJECT_MEMBER(logout)
JSAG_OBJECT_MEMBER(getGameFriends)
JSAG_OBJECT_MEMBER(getFriends)
JSAG_OBJECT_END

@implementation jsFacebook

+ (void) addToRuntime:(js_core *)js {
    m_core = js;
	JSAG_OBJECT_ATTACH(js.cx, js.native, fbapi);
}

+ (void) onDestroyRuntime {
	
}

@end
