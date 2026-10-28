extends RefCounted
# One controller for the player's device, never one per AI. Time is monotonic.
var enabled:=true
var active:=false
var go_used:=false
var last_ms:=-1000000
var contact_ms:=-1000000
var was_contact:=false
# Tests inject a sink; production only uses supported phone platforms.
var sink:Callable
func begin_race() -> void:
 go_used=false;last_ms=-1000000;contact_ms=-1000000;was_contact=false;active=true
func suspend() -> void:
 # Godot has no handheld cancellation API: never queue/loop pulses (max 90 ms).
 active=false
func pulse(kind:String,duration:int,amplitude:float,now:int) -> bool:
 if not enabled or not active:return false
 if not sink.is_valid() and not (OS.has_feature("android") or OS.has_feature("ios")):return false
 if sink.is_valid():sink.call(kind,duration,amplitude)
 else:Input.vibrate_handheld(duration,amplitude)
 last_ms=now
 return true
func go(now:int) -> bool:
 if go_used:return false
 go_used=true
 return pulse("go",35,.40,now)
func collision(vehicle:float,road:float,contact:bool,now:int) -> bool:
 # Require separation, not merely a timer, so rubbing a wall never repeats.
 var fresh:bool=not was_contact and now-contact_ms>=180
 was_contact=contact
 if contact:contact_ms=now
 if not fresh or not contact or now-last_ms<300:return false
 var kind:="vehicle" if vehicle>=road else "road"
 var speed:=maxf(vehicle,road)
 if speed<2.5:return false
 var strong:bool=speed>=10
 var medium:bool=speed>=5
 var duration:int=(90 if strong else (65 if medium else 40)) if kind=="vehicle" else (65 if strong else (45 if medium else 25))
 var amplitude:float=(.90 if strong else (.65 if medium else .40)) if kind=="vehicle" else (.65 if strong else (.45 if medium else .25))
 return pulse(kind,duration,amplitude,now)
