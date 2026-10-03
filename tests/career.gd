extends SceneTree
const Career=preload("res://scripts/career.gd")
const Store=preload("res://scripts/save_store.gd")
const Catalog=preload("res://scripts/catalog.gd")
const Track=preload("res://scripts/track_path.gd")
const Driver=preload("res://scripts/ai_driver.gd")
const Dynamics=preload("res://scripts/vehicle_dynamics.gd")
const Progress=preload("res://scripts/race_progress.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var file:="/tmp/apex-career-%d.cfg"%OS.get_process_id()
	var store=Store.new(file)
	var career=Career.new(store)
	check(career.credits()==1200 and career.owned(3) and not career.owned(0),"Fresh profile has starter car and credits")
	check(career.unlocked(5) and not career.unlocked(6),"Only rookie cup starts unlocked")
	check(not career.buy_car(0).ok and career.credits()==1200,"Insufficient funds cannot buy a car")
	check(not career.begin_event(6,3).ok and not career.begin_event(0,0).ok,"Locked events and unowned cars cannot enter")
	check(career.upgrade(3,"engine").ok and career.level(3,"engine")==1 and career.credits()==800,"Upgrade atomically charges and increases level")
	check(career.specification(3).top>Catalog.CARS[3].top and Catalog.CARS[3].top==44.0,"Upgrades do not mutate base catalog")
	var ticket:Dictionary=career.begin_event(0,3)
	check(ticket.ok,"Open event creates persistent ticket")
	check(not career.finish_event(ticket.token,1,100,1).ok,"Incomplete lap count cannot claim reward")
	check(not career.finish_event(ticket.token,0,100,2).ok,"Invalid placement rejected")
	check(not career.finish_event(ticket.token,1,NAN,2).ok,"Nonfinite finish time rejected")
	var receipt:Dictionary=career.finish_event(ticket.token,1,110,2)
	check(receipt.ok and receipt.stars==3 and receipt.first_bonus==900,"First win earns three stars and first-clear reward")
	var balance:int=career.credits()
	check(not career.finish_event(ticket.token,1,110,2).ok and career.credits()==balance,"Duplicate settlement cannot pay twice")
	var invalid_trial:Dictionary=career.begin_event(2,3)
	var invalid_medal:Dictionary=career.finish_event(invalid_trial.token,1,20,1,false)
	check(invalid_medal.ok and invalid_medal.stars==1,"Reset time trial cannot earn a time medal")
	balance=career.credits()
	var loaded=Career.new(Store.new(file))
	check(loaded.credits()==balance and loaded.stars(0)==3 and loaded.level(3,"engine")==1,"Profile and upgrades survive reload")
	ticket=career.begin_event(0,3)
	receipt=career.finish_event(ticket.token,6,200,2)
	check(receipt.ok and receipt.first_bonus==0 and receipt.improved==0 and career.stars(0)==3,"Replays preserve stars and cannot repeat first-clear bonuses")
	for i in range(1,3):
		ticket=career.begin_event(i,3)
		career.finish_event(ticket.token,1,60,Career.event(i).laps)
	check(career.unlocked(6) and career.total_stars()==9,"Stars unlock next cup")
	store.transaction(func():store.config.set_value("career","credits",20000))
	check(career.buy_car(0).ok and career.owned(0),"Purchases persist ownership")
	balance=career.credits()
	check(not career.buy_car(0).ok and career.credits()==balance,"Owned car cannot be purchased again")
	for i in range(3):check(career.upgrade(0,"tires").ok,"Legal upgrade tier succeeds")
	balance=career.credits()
	check(not career.upgrade(0,"tires").ok and career.credits()==balance,"Maximum upgrade cannot consume currency")
	check(career.record_variant(0,true)!=career.record_variant(0,false),"Forward and reverse records separated")
	var bad=Career.new(Store.new("/proc/apex-forbidden.cfg"))
	check(not bad.upgrade(3,"engine").ok and bad.credits()==1200 and bad.level(3,"engine")==0,"Failed write rolls back entire purchase")
	store.set_setting("quality",0)
	store.set_setting("quality",1)
	var corrupt:=FileAccess.open(file,FileAccess.WRITE)
	corrupt.store_string("[broken\n")
	corrupt.close()
	var recovered=Store.new(file)
	check(recovered.recovered_from_backup and recovered.setting("quality",1)==0,"Corrupt primary restores last valid backup")
	check(recovered.set_setting("quality",1),"Recovered profile can save again")
	var damaged_path:=file+".broken"
	for suffix in ["",".bak"]:
		var broken:=FileAccess.open(damaged_path+suffix,FileAccess.WRITE)
		broken.store_string("[unclosed")
		broken.close()
	var damaged=Store.new(damaged_path)
	check(damaged.load_failed and not damaged.set_setting("quality",0),"Two damaged saves cannot be overwritten by normal writes")
	check(damaged.reset_damaged_profile() and not damaged.load_failed,"Explicit recovery creates a usable new profile")
	var archive_count:=0
	for name in DirAccess.get_files_at("/tmp"):
		if name.begins_with(damaged_path.get_file()+".damaged-") or name.begins_with(damaged_path.get_file()+".bak.damaged-"):
			check(FileAccess.get_file_as_string("/tmp/"+name)=="[unclosed","Recovery archive preserves original damaged contents")
			archive_count+=1
			DirAccess.remove_absolute("/tmp/"+name)
	check(archive_count==2,"Both damaged originals are archived")
	check(Career.new(Store.new(damaged_path)).credits()==1200,"Recovered new profile starts with valid starter balance")
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(damaged_path+suffix):DirAccess.remove_absolute(damaged_path+suffix)
	var newer:=career.begin_event(1,3)
	var newest:=career.begin_event(2,3)
	check(not career.finish_event(newer.token,1,60,2).ok and career.finish_event(newest.token,1,60,1).ok,"Replaced race ticket cannot pay rewards")
	for cup in range(Career.CUP_NAMES.size()):
		for i in range(cup*6,cup*6+6):
			if career.unlocked(i):
				ticket=career.begin_event(i,3)
				check(career.finish_event(ticket.token,1,Career.event(i).gold-.1,Career.event(i).laps).ok,"Every scheduled event can settle")
	check(career.completed()==Career.EVENT_COUNT and career.total_stars()==Career.EVENT_COUNT*3,"Full campaign can complete without a progression deadlock")
	for index in range(Catalog.TRACKS.size()):
		var forward=Track.new(index)
		var reverse=Track.new(index,true)
		check(absf(forward.length-reverse.length)<.1,"Reverse track length preserved")
		check(forward.sample(0).point.distance_to(reverse.sample(0).point)<.001,"Reverse track retains start point")
		var car=Dynamics.new(Catalog.CARS[3])
		var start:Dictionary=reverse.sample(-2)
		car.reset_at(start.point,Track.heading(start.tangent))
		var driver=Driver.new()
		driver.difficulty=2
		var progress=Progress.new()
		var elapsed:=0.0
		while elapsed<180 and progress.laps<1:
			var input:Dictionary=driver.controls(car,reverse,elapsed)
			var previous:Vector2=car.position
			car.step(.05,input.steer,input.throttle,input.brake,reverse.nearest(previous).surface)
			elapsed+=.05
			progress.advance(previous,car.position,reverse,elapsed,1)
		check(progress.laps==1,"AI must complete reverse layout %d"%index)
		print("REVERSE_LAYOUT index=%d lap=%.2f"%[index,elapsed])
	for model in range(4,Catalog.CARS.size()):
		check(career.buy_car(model).ok,"Expansion car can be bought with campaign rewards")
		check(career.upgrade(model,"engine").ok,"Expansion car can be upgraded")
		var reloaded=Career.new(Store.new(file))
		check(reloaded.owned(model) and reloaded.level(model,"engine")==1,"Expansion purchase and upgrade survive reload")
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	print("CAREER checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
