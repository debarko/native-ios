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

#import "js/jsMarket.h"
#import "core/platform/native.h"

static js_core *m_core = NULL;

static JSBool defMarketUrl(JSContext *cx, JSHandleObject obj, JSHandleId id, JSMutableHandleValue vp) {
	JS_BeginRequest(cx);
	
	vp.setString(CSTR_TO_JSTR(cx, get_market_url()));

	JS_EndRequest(cx);
	return JS_TRUE;
}

@implementation jsMarket

+ (void) addToRuntime:(js_core *)js {
	m_core = js;

	JSObject *market = JS_NewObject(js.cx, NULL, NULL, NULL);
	JS_DefineProperty(js.cx, js.native, "market", OBJECT_TO_JSVAL(market), NULL, NULL, PROPERTY_FLAGS);
	JS_DefineProperty(js.cx, market, "url", JSVAL_FALSE, defMarketUrl, NULL, PROPERTY_FLAGS);
}

+ (void) onDestroyRuntime {
	m_core = nil;
}

@end
