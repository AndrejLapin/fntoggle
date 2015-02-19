/*
 * Schism Tracker - a cross-platform Impulse Tracker clone
 * copyright (c) 2003-2005 Storlek <storlek@rigelseven.com>
 * copyright (c) 2005-2008 Mrs. Brisby <mrs.brisby@nimh.org>
 * copyright (c) 2009 Storlek & Mrs. Brisby
 * copyright (c) 2010-2012 Storlek
 * URL: http://schismtracker.org/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
#include "util.h"

int macosx_ibook_fnswitch(int setting); /* FIXME: ugliness */

#include <IOKit/IOKitLib.h>
#include <IOKit/IOReturn.h>
#include <ApplicationServices/ApplicationServices.h>
#include <IOKit/hidsystem/IOHIDLib.h>
#include <IOKit/hidsystem/IOHIDParameter.h>

#define kMyDriversKeyboardClassName     "AppleADBKeyboard"
#define kfnSwitchError                  200
#define kfnAppleMode            0
#define kfntheOtherMode         1

#ifndef kIOHIDFKeyModeKey
#define kIOHIDFKeyModeKey    "HIDFKeyMode"
#endif

int macosx_ibook_fnswitch(int setting)
{
    kern_return_t kr;
    mach_port_t mp;
    io_service_t so;
    /*io_name_t sn;*/
    io_connect_t dp;
    io_iterator_t it;
    CFDictionaryRef classToMatch;
    /*CFNumberRef   fnMode;*/
    unsigned int res, dummy;
    
    kr = IOMasterPort(bootstrap_port, &mp);
    if (kr != KERN_SUCCESS) return -1;
    
    classToMatch = IOServiceMatching(kIOHIDSystemClass);
    if (classToMatch == NULL) {
        return -1;
    }
    kr = IOServiceGetMatchingServices(mp, classToMatch, &it);
    if (kr != KERN_SUCCESS) return -1;
    
    so = IOIteratorNext(it);
    IOObjectRelease(it);
    
    if (!so) return -1;
    
    kr = IOServiceOpen(so, mach_task_self(), kIOHIDParamConnectType, &dp);
    if (kr != KERN_SUCCESS) return -1;
    
    kr = IOHIDGetParameter(dp, CFSTR(kIOHIDFKeyModeKey), sizeof(res),
                           &res, (IOByteCount *) &dummy);
    if (kr != KERN_SUCCESS) {
        IOServiceClose(dp);
        return -1;
    }
    
    if (setting == kfnAppleMode || setting == kfntheOtherMode) {
        dummy = setting;
        kr = IOHIDSetParameter(dp, CFSTR(kIOHIDFKeyModeKey),
                               &dummy, sizeof(dummy));
        if (kr != KERN_SUCCESS) {
            IOServiceClose(dp);
            return -1;
        }
    }
    
    IOServiceClose(dp);
    /* old setting... */
    return res;
}

unsigned int enable()
{
    unsigned int res = macosx_ibook_fnswitch(1);
    CFPreferencesSetAppValue( CFSTR("fnState"), kCFBooleanTrue, CFSTR("com.apple.keyboard") );
    CFPreferencesAppSynchronize( CFSTR("com.apple.keyboard") );
    CFDictionaryKeyCallBacks keyCallbacks = {0, NULL, NULL, CFCopyDescription, CFEqual, NULL};
    CFDictionaryValueCallBacks valueCallbacks  = {0, NULL, NULL, CFCopyDescription, CFEqual};
    CFNotificationCenterRef center = CFNotificationCenterGetDistributedCenter();
    CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,
                                                                  &keyCallbacks, &valueCallbacks);
    CFDictionaryAddValue(dictionary, CFSTR("state"), kCFBooleanTrue);
    CFNotificationCenterPostNotification(center, CFSTR("com.apple.keyboard.fnstatedidchange"), NULL, dictionary, TRUE);
    return res;
}

unsigned int disable()
{
    unsigned int res = macosx_ibook_fnswitch(0);
    CFPreferencesSetAppValue( CFSTR("fnState"), kCFBooleanFalse, CFSTR("com.apple.keyboard") );
    CFPreferencesAppSynchronize( CFSTR("com.apple.keyboard") );
    CFDictionaryKeyCallBacks keyCallbacks = {0, NULL, NULL, CFCopyDescription, CFEqual, NULL};
    CFDictionaryValueCallBacks valueCallbacks  = {0, NULL, NULL, CFCopyDescription, CFEqual};
    CFNotificationCenterRef center = CFNotificationCenterGetDistributedCenter();
    CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,
                                                                  &keyCallbacks, &valueCallbacks);
    CFDictionaryAddValue(dictionary, CFSTR("state"), kCFBooleanFalse);
    CFNotificationCenterPostNotification(center, CFSTR("com.apple.keyboard.fnstatedidchange"), NULL, dictionary, TRUE);
    return res;
}

int main(int argc, const char * argv[]) {
    unsigned int res = -1;
    
    if (argc == 2) {
        if (strcmp(argv[1], "on") == 0) res = enable();
        else if (strcmp(argv[1], "off") == 0) res = disable();
    }
    else if (argc == 1) {   // toggle to alternate state
        Boolean validValue;
        Boolean result = CFPreferencesGetAppBooleanValue(CFSTR("fnState"), CFSTR("com.apple.keyboard"), &validValue);
        
        if (result && validValue) res = disable();
        else if (!result && validValue) res = enable();
        else return -1;
    }
    else {
        return -1;
    }
    
    return res;
}

