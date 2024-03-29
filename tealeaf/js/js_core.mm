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
 * along with the Game Closure SDK.	 If not, see <http://www.gnu.org/licenses/>.
 */

#import "js/js_core.h"
#import "js/jsMacros.h"
#include <stddef.h>
#include <stdio.h>
#include "core/log.h"
#include "core/core.h"
#include "core/timer.h"
#include "core/config.h"
#include "gen/js_animate_template.gen.h"
#include "gen/js_timestep_image_map_template.gen.h"
#include "gen/js_timestep_view_template.gen.h"
#import "core/platform/location_manager.h"
#import "js/jsBase.h"
#import "platform/PluginManager.h"

// JS Ready flag: Indicates that the JavaScript engine is running (see core/core_js.h)
bool js_ready = false;

static js_core *lastJS = nil;
static JSObject *global_obj = nil;
static NSDate *m_start_date = nil;


CEXPORT JSContext *get_js_context() {
	return lastJS.cx;
}

CEXPORT JSObject *get_global_object() {
	return lastJS.global;
}


/* The error reporter callback. */
static void reportError(JSContext *cx, const char *message, JSErrorReport *report) {
	NSLOG(@"{js} JavaScript error in %s:%d", report->filename ? report->filename : "<no filename>", (unsigned int) report->lineno);
	LOG("{js} Error: %s", message);

	JS_BeginRequest(cx);

	jsval exception;
	if (JS_GetPendingException(cx, &exception) && JSVAL_IS_OBJECT(exception)) {
		JSObject *exn = JSVAL_TO_OBJECT(exception);

		jsval stack;
		JS_GetProperty(cx, exn, "stack", &stack);

		JSString *s = JS_ValueToString(cx, stack);

		if (s) {
			JSTR_TO_CSTR_PERSIST(cx, s, cstr);

			LOG("{js} Traceback:\n%s\n\n", cstr);

			PERSIST_CSTR_RELEASE(cstr);
		}
	}

	JS_EndRequest(cx);
}

#define TIMER_DICT_KEY(timer) [[NSNumber numberWithInt:timer->timerId] stringValue]


static void js_global_finalize(JSFreeOp *fop, JSObject *obj) {
	// Do nothing
}

/* The class of the global object. */
JSClass global_class = {
	"global", JSCLASS_GLOBAL_FLAGS | JSCLASS_HAS_PRIVATE,
	JS_PropertyStub, JS_PropertyStub, JS_PropertyStub, JS_StrictPropertyStub,
	JS_EnumerateStub, JS_ResolveStub, JS_ConvertStub, js_global_finalize,
	JSCLASS_NO_OPTIONAL_MEMBERS
};

typedef struct js_timer_info_t {
	JSObject *callback;
	JSContext *cx;
	JSObject *global;
} js_timer_info;

void js_timer_unlink(core_timer *timer) {
	js_timer_info *js_data = (js_timer_info*)timer->js_data;
	JSContext *cx = js_data->cx;
	JS_BeginRequest(cx);
	js_object_wrapper_delete(&js_data->callback);
	JS_EndRequest(cx);
}

void js_timer_fire(core_timer *timer) {
	js_timer_info *js_data = (js_timer_info*)timer->js_data;
	JSContext *cx = js_data->cx;
	jsval ret;
	JS_BeginRequest(cx);
	JS_CallFunctionValue(cx, js_data->global, OBJECT_TO_JSVAL(js_data->callback), 0, NULL, &ret);
	JS_EndRequest(cx);
}

static void jsGCcb(JSRuntime *rt, JSGCStatus status) {
	switch (status) {
	case JSGC_BEGIN:
		if (m_start_date) {
			[m_start_date release];
		}
		m_start_date = [[NSDate date] retain];
		break;

	case JSGC_END:
		if (m_start_date != nil)
		{
			// Get time in milliseconds
			NSTimeInterval msInterval = fabs([m_start_date timeIntervalSinceNow] * 1000.0);
			m_start_date = nil;

			LOG("{js} GC took %lf ms", msInterval);
/*
			NSString *fileName = @"heap.dump";
			NSString *appBundle = [[[NSBundle mainBundle] pathForResource:@"resources" ofType:@"bundle"] retain];
			NSString *filePath = [NSString stringWithFormat:@"%@/%@", appBundle, fileName];

			FILE *fp = fopen([filePath UTF8String], "w");

			if (fp) {
				if (JS_DumpHeap(cx, fp, NULL, 0, NULL, 65535, NULL) == JS_TRUE) {
					LOG(@"Dumped heap to %@", filePath);
				} else {
					LOG(@"ERROR: Unable to dump heap!");
				}
				
				fclose(fp);
			} */
		}
		break;

	default: // JSGC_MARK_END, JSGC_FINALIZE_END
		LOG("{js} GC MARK/FINALIZE END");
		break;
	}
}


//// GLOBAL

static int startTimer(BOOL repeats, JSContext *cx, JSAG_OBJECT *callback, double interval) {
	js_timer_info *js_data = (js_timer_info *)malloc(sizeof(js_timer_info));

	js_data->cx = cx;
	js_data->global = global_obj;
	js_object_wrapper_init(&js_data->callback);
	js_object_wrapper_root(&js_data->callback, callback);
	
	core_timer *timer = core_get_timer((void*)js_data, interval, repeats);
	core_timer_schedule(timer);
	
	return timer->id;
}

JSAG_MEMBER_BEGIN(setTimeout, 1)
{
	JSAG_ARG_FUNCTION(callback);
	JSAG_ARG_DOUBLE_OPTIONAL(interval, 0);

	JSAG_RETURN_INT32(startTimer(NO, cx, callback, interval));
}
JSAG_MEMBER_END

JSAG_MEMBER_BEGIN(setInterval, 1)
{
	JSAG_ARG_FUNCTION(callback);
	JSAG_ARG_DOUBLE_OPTIONAL(interval, 0);

	JSAG_RETURN_INT32(startTimer(YES, cx, callback, interval));
}
JSAG_MEMBER_END

JSAG_MEMBER_BEGIN(clearTimeout, 1)
{
	JSAG_ARG_INT32(timerId);
	
	core_timer_clear(timerId);
}
JSAG_MEMBER_END

JSAG_MEMBER_BEGIN(clearInterval, 1)
{
	JSAG_ARG_INT32(timerId);

	core_timer_clear(timerId);
}
JSAG_MEMBER_END

JSAG_MEMBER_BEGIN(setLocation, 1)
{
	JSAG_ARG_NSTR(location);

	[jsBase setLocation:location];
}
JSAG_MEMBER_END

JSAG_OBJECT_START(GLOBAL)
JSAG_OBJECT_MEMBER(setTimeout)
JSAG_OBJECT_MEMBER(setInterval)
JSAG_OBJECT_MEMBER(clearTimeout)
JSAG_OBJECT_MEMBER(clearInterval)
JSAG_OBJECT_MEMBER(setLocation)
JSAG_OBJECT_END


//// NATIVE

JSAG_MEMBER_BEGIN_NOARGS(doneLoading)
{
	core_hide_preloader();

	LOG("{js} Game is done loading");
}
JSAG_MEMBER_END_NOARGS

JSAG_OBJECT_START(NATIVE)
JSAG_OBJECT_MEMBER(doneLoading)
JSAG_OBJECT_END


@implementation js_core

-(void) dealloc {
	self.extensions = nil;
	self.privateStore = nil;
	self.pluginManager = nil;
	self.config = nil;
	
	lastJS = nil;
	global_obj = nil;
	m_start_date = nil;

	[super dealloc];
}

-(void) shutdown {
	// Kill debug server immediately
	if (self.debugServer) {
		[self.debugServer close];
		[self.debugServer release];
		self.debugServer = nil;
		
		LoggerSetDebugger(nil);
	}

	JS_DestroyContext(self.cx);
	JS_DestroyRuntime(self.rt);
	JS_ShutDown();
}

- (id) initRuntime {
	self = [super init];
	lastJS = self;

	self.rt = JS_NewRuntime(26L * 1024L * 1024L, JS_USE_HELPER_THREADS);
	if (!self.rt) {
		LOG("{js} FATAL: Unable to create JS runtime");
		return NULL;
	}
	
	// Create a context
	self.cx = JS_NewContext(self.rt, 8192);
	if (!self.cx) {
		LOG("{js} FATAL: Unable to create JS context");
		return NULL;
	}

	JS_SetGCParameter(self.rt, JSGC_MODE, JSGC_MODE_INCREMENTAL);
	//JS_SetGCParameter(self.rt, JSGC_DYNAMIC_MARK_SLICE, 1);
	JS_SetGCParameter(self.rt, JSGC_SLICE_TIME_BUDGET, 20);
	JS_SetGCCallback(self.rt, &jsGCcb);
	
	JS_SetOptions(self.cx, JSOPTION_VAROBJFIX | JSOPTION_MOAR_XML);
	JS_SetVersion(self.cx, JSVERSION_LATEST);
	JS_SetErrorReporter(self.cx, reportError);
	
	// Create the global object
	self.global = JS_NewGlobalObject(self.cx, &global_class, NULL);
	global_obj = self.global;
	if (self.global == NULL) { return NULL; }

	// Populate the global object with the standard globals, like Object and Array
	if (!JS_InitStandardClasses(self.cx, self.global)) { return NULL; }
	
	JS_GC(self.rt);
	
	return self;
}

- (id) setConfig:(NSDictionary*)config pluginManager:(PluginManager*)pluginManager {
	self.config = config;
	self.pluginManager = pluginManager;

	LOG("{js} SpiderMonkey version: %s", JS_GetImplementationVersion());

	self.privateStore = [NSMutableDictionary dictionary];
	[self.privateStore setValue:self forKey:@"self"];
	JS_SetContextPrivate(self.cx, self.privateStore);

	self.native = JS_NewObject(self.cx, NULL, NULL, NULL);
	JSContext *cx = self.cx;
	jsval uuid = NSTR_TO_JSVAL(cx, [[UIDevice currentDevice] uniqueIdentifier]);
	JS_SetProperty(self.cx, self.native, "deviceUUID", &uuid);

	JSAG_OBJECT_ATTACH_EXISTING(self.cx, self.global, GLOBAL, self.global);
	JSAG_OBJECT_ATTACH_EXISTING(self.cx, self.global, NATIVE, self.native);

	jsval screen = OBJECT_TO_JSVAL(JS_NewObject(self.cx, NULL, NULL, NULL));

	int screenW = config_get_screen_width(), screenH = config_get_screen_height();
	jsval jscreenW = INT_TO_JSVAL(screenW), jscreenH = INT_TO_JSVAL(screenH);
	JS_SetProperty(self.cx, self.native, "screen", &screen);
	JS_SetProperty(self.cx, JSVAL_TO_OBJECT(screen), "width", &jscreenW);
	JS_SetProperty(self.cx, JSVAL_TO_OBJECT(screen), "height", &jscreenH);
	jsval global_val = OBJECT_TO_JSVAL(self.global);
	JS_SetProperty(self.cx, self.global, "window", &global_val);
	JS_SetProperty(self.cx, self.global, "screen", &screen);
	
	jsval gid = NSTR_TO_JSVAL(cx, [js_core getDeviceId]);
	jsval device = OBJECT_TO_JSVAL(JS_NewObject(self.cx, NULL, NULL, NULL));
	JS_SetProperty(self.cx, JSVAL_TO_OBJECT(device), "globalID", &gid);
	JS_SetProperty(self.cx, self.native, "device", &device);
	jsval tcpport = INT_TO_JSVAL([[self.config objectForKey:@"tcp_port"] intValue]);
	jsval tcphost = NSTR_TO_JSVAL(cx, [self.config objectForKey:@"tcp_host"]);
	JS_SetProperty(self.cx, self.native, "tcpHost", &tcphost);
	JS_SetProperty(self.cx, self.native, "tcpPort", &tcpport);

	// If remote loading is enabled,
	if ([[self.config objectForKey:@"remote_loading"] boolValue]) {
		self.debugServer = [[[DebugServer alloc] init:self] autorelease];
	}
	
	return self;
}

+(NSString*) getDeviceId {
	NSString* devid = [[UIDevice currentDevice] uniqueIdentifier];
	const char* bytes = [devid UTF8String];
	CFUUIDRef uuidref = CFUUIDCreateWithBytes(NULL, bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
	bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);
	CFStringRef uuidstr = CFUUIDCreateString(NULL, uuidref);
	NSString* devidbytes = [NSString stringWithFormat:@"%@", uuidstr];
	CFRelease(uuidref);
	CFRelease(uuidstr);
	return devidbytes;
}

-(void) addExtension:(id)extension {
	[self.extensions addObject:extension];
}

-(jsval) eval:(char *)source {
	return [self evalStr: [NSString stringWithUTF8String:source]];
}

-(jsval) evalStr:(NSString *)source {
	return [self evalStr:source withPath:@"eval"];
}

-(jsval) evalStr:(NSString *)source withPath:(NSString *)path {
	jsval rval = JSVAL_NULL;

	const NSUInteger unicode_length = [source length];
	const size_t length = unicode_length;
	const size_t buffer_bytes = (length + 1) * sizeof(unichar);
	unichar *buffer = (unichar*)malloc(buffer_bytes);

	[source getCharacters:buffer range:NSMakeRange(0, length)];

	NSString *uniqueName;

	if (self.debugServer) {
		// Store off the script
		uniqueName = [self.debugServer setScriptForPath:path source:source];
	} else {
		uniqueName = @"eval";
	}

	JS_BeginRequest(self.cx);

	if (JS_EvaluateUCScript(self.cx, self.global, buffer, unicode_length,
	[uniqueName cStringUsingEncoding:NSASCIIStringEncoding], 1, &rval) != JS_TRUE) {
		NSLOG(@"{js} Error while evaluating JavaScript from %@", path);
	}

	JS_EndRequest(self.cx);

	free(buffer);
	return rval;
}

-(void) dispatchEvent:(jsval *)arg count:(int)count {
	JS_BeginRequest(self.cx);

	jsval events, dispatch, dummy;
	if (js_ready) {
		JS_GetProperty(self.cx, self.native, "events", &events);
		if (!JSVAL_IS_VOID(events)) {
			JS_GetProperty(self.cx, JSVAL_TO_OBJECT(events), "dispatchEvent", &dispatch);
			if (!JSVAL_IS_VOID(dispatch)) {
				JS_CallFunctionName(self.cx, JSVAL_TO_OBJECT(events), "dispatchEvent", count, arg, &dummy);

				JS_EndRequest(self.cx);
				return;
			}
		}
	}

	JS_EndRequest(self.cx);

	LOG("{js} ERROR: Firing event failed");
}

-(void) dispatchEvent:(NSString *)evt {
	jsval str = NSTR_TO_JSVAL(self.cx, evt);
	[self dispatchEvent: &str count: 1];
}

-(void) performGC {
	LOG("{js} Full GC");

	JS_GC(self.rt);
}

-(void) performMaybeGC {
	LOG("{js} Maybe GC");
	
	JS_MaybeGC(self.cx);
}

+(js_core*) lastJS {
	return lastJS;
}

@end
