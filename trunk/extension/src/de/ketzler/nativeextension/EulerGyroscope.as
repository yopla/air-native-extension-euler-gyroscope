////////////////////////////////////////////////////////////////////////////////////////////////////////	
//	ADOBE SYSTEMS INCORPORATED																		  //
//	Copyright 2011 Adobe Systems Incorporated														  //
//	All Rights Reserved.																			  //
//																									  //
//	NOTICE:  Adobe permits you to use, modify, and distribute this file in accordance with the		  //
//	terms of the Adobe license agreement accompanying it.  If you have received this file from a	  //
//	source other than Adobe, then your use, modification, or distribution of it requires the prior	  //
//	written permission of Adobe.																	  //
////////////////////////////////////////////////////////////////////////////////////////////////////////

// Modified by Christoph Ketzler
// Modifications are published under the following License
/*
 Copyright (c) 2012, Christoph Ketzler
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met: 
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer. 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution. 
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
 
package de.ketzler.nativeextension {
	import flash.events.EventDispatcher;
	import flash.events.StatusEvent;
	import flash.events.TimerEvent;
	import flash.external.ExtensionContext;
	import flash.utils.Timer;

    // The application using the Gyroscope extension can create multiple instances of
    // Gyroscope. However, the instances all use a singleton ExtensionContext object.
    //
    // The singleton ExtensionContext object listens for StatusEvent events that
    // the native implementation dispatches. These events contain the device's
    // gyroscope x,y,z data.
    //
    // However, each Gyroscope instance has its own interval timer. When the timer
    // expires, the Gyroscope instance dispatches a GyroscopeEvent that contains
    // the current x,y,z data.
    
    public class EulerGyroscope extends EventDispatcher {  
	
		private static const EXTENSION_ID : String = "de.ketzler.eulergyroscope";
		private static const PREFIX : String = "KTZEulerGyro";
		
		
		private var interval:int = 100;
		private var intervalTimer:Timer = null;
		
		
		private static var _roll:Number = 0;
		private static var _pitch:Number = 0;
		private static var _yaw:Number = 0;
		
		private static var refCount:int = 0;
        
		private static var extCtx:ExtensionContext = null;
        
        private static var isInstantiated:Boolean = false;
        
		private static var checkedIfSupported:Boolean = false;
        
		private static var supported:Boolean = false;
        
        
		
		// Gyroscope constructor
        //
        
        public function EulerGyroscope(){
			
			if (!isInstantiated){
				extCtx = ExtensionContext.createExtensionContext(EXTENSION_ID, null);
				
				if (extCtx != null){
					extCtx.call(PREFIX+"Init"); 
					
					if (!extCtx.call(PREFIX+"Start", EulerGyroscopeIntervalValue.INTERVAL_FASTEST)) {  
						throw new Error("Error while Starting Gyroscope"); 
					} 
					else {
						extCtx.addEventListener(StatusEvent.STATUS, onStatus);
					}
				} 
				
				isInstantiated = true;
			}
			
			if (extCtx != null) {
				refCount++;
				intervalTimer = new Timer(interval);
				intervalTimer.addEventListener(TimerEvent.TIMER,onInterval); 
				intervalTimer.start();
			}
			else{
				throw new Error("Error while instantiating Gyroscope Extension");
			}
		}
	
        // isSupported()
        //
        // Use this static method to determine whether the device
        // has gyroscope support.
        
        public static function get isSupported():Boolean {
			
			var ctx:ExtensionContext = null;
			
			if (checkedIfSupported == false) {
				
				// This time is the first time that isSupported() is called. 
				checkedIfSupported = true;
				
				ctx = ExtensionContext.createExtensionContext(EXTENSION_ID,null);
				
				if (ctx != null) {
					
					ctx.call(PREFIX+"Init"); 
					
					supported = ctx.call(PREFIX+"Support") as Boolean;
					
					//trace("gyroscopeSupport Returned : " + supported); 
								
					ctx.dispose();
					ctx = null;
					return supported;
				}
				
				else{
					return false; 
				} 
				
			} 
			
			else {
				// Already checked if supported, so the value of supported is already set.
				return supported; 
			}
		}
		
		
        // isMuted()
        //
        // This method is for parity with the ActionScript class Accelerometer. However, it is not
        // yet implemented.
        
        public static function get isMuted():Boolean {
			
			return false;
		}
        
        
		
		// setRequestedUpdateInterval()
        //
		// Sets the rate in milliseconds at which this instance will receive gyroscope updates.
        
		public function setRequestedUpdateInterval( newInterval:int ):void {
			
			// Make sure the existing timer is not null. It shouldn't be.
			// Then stop the timer and start a new one with the new interval.
            
			if (intervalTimer != null) {
				
				intervalTimer.removeEventListener(TimerEvent.TIMER,onInterval);
				intervalTimer.stop();
				intervalTimer = null;
			}
			
			// Each instance of Gyroscope has its own interval timer.
			interval = newInterval;
			intervalTimer = new Timer(interval);
			intervalTimer.addEventListener(TimerEvent.TIMER, onInterval); 
			intervalTimer.start();
		}
		
        
        
		// dispose()
        //
        
        public function dispose():void {
			
			refCount --;
			
			// Make sure the refCount does not go negative -- the extension user could have an extra
			// call to dispose().
            
			if (refCount < 0) refCount = 0;
			
			if(refCount == 0) { 
			
				if (extCtx != null) {
					
					extCtx.call(PREFIX+"Stop");
					extCtx.removeEventListener(StatusEvent.STATUS,onStatus);
					extCtx.dispose();
					extCtx = null;
				}
			}
		}
		 
		
        
        // onStatus()
        // Event handler for the event that the native implementation dispatches.
        // The event contains the latest gyroscope x,y,z data.
        //
        
        private static function onStatus(e:StatusEvent):void {
			
			if (e.code == "CHANGE") {
				
				//trace(e.level);
				var vals:Array = e.level.split("&");
				//trace(vals);
				var roll:Number = Number(vals[0]);
				var pitch:Number = Number(vals[1]);
				var yaw:Number = Number(vals[2]);
				_roll = roll;
				_pitch = pitch;
				_yaw = yaw;
			}
		}
		
		
        // onInterval()
        // Event handler for the interval timer for a Gyroscope instance.
        //
        
        private function onInterval(e:TimerEvent):void {
			
			// For each Gyroscope instance, at the requested interval,
			// dispatch the gyroscope data.
			
 			if (extCtx != null) {
				dispatchEvent(new EulerGyroscopeEvent(EulerGyroscopeEvent.UPDATE, _roll, _pitch, _yaw));
			}
		}
	}
}