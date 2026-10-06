extends RefCounted
const Catalog=preload("res://scripts/catalog.gd")
const SCHEMA:=1
const CUP_NAMES:=["新秀杯","海岸巡回赛","越野大师赛","APEX 冠军赛","新境巡回赛","全域挑战赛"]
const EVENT_COUNT:=36
const CUP_GATES:=[0,8,20,35,48,65]
const CUP_COLORS:=[Color("55d8c0"),Color("4eb5f1"),Color("f7ad61"),Color("ecc35a"),Color("8ab8d2"),Color("c5a1df")]
const CAR_PRICES:=[6200,3600,4800,0,5200,7400,8200,4600]
const PARTS:=["engine","tires","brakes"]
const PART_NAMES:=["动力套件","抓地套件","制动套件"]
const UPGRADE_PRICES:=[400,800,1400]
var store

func _init(save_store) -> void:
	store=save_store

static func event(index:int) -> Dictionary:
	if index<0 or index>=EVENT_COUNT:return {}
	var cup:=int(index/6)
	var round_index:=index%6
	var track:=round_index%3+(3 if cup>=4 else 0)
	var trial:=round_index==2 or round_index==4
	return {"id":index,"cup":cup,"round":round_index,"track":track,"reverse":round_index>=3,
		"name":(["码头冲刺","集市追逐","雪岭计时","港区回转","老城计时","雪岭大奖赛"] if cup>=4 else ["开幕冲刺","林间追逐","红岩计时","海湾回转","森林计时","收官大奖赛"])[round_index],
		"mode":"trial" if trial else "race","laps":1 if trial else (2 if cup==0 else 3),
		"difficulty":mini(cup,2),"ai_level":mini(cup,2),"reward":600+cup*300+round_index*60,
		"gold":float([70,71,75,74,71,74][track])*[1.15,1.05,1.0,.92,1.05,.98][cup]}

func number(section:String,key:String,fallback:int=0) -> int:
	var value=store.config.get_value(section,key,fallback)
	return maxi(0,int(value)) if value is int or value is float else fallback

func credits() -> int:
	return number("career","credits",1200)

func owned(index:int) -> bool:
	if index<0 or index>=Catalog.CARS.size():return false
	return index==3 or store.config.get_value("garage","owned_%d"%index,false)==true

func level(car:int,part:String) -> int:
	return mini(3,number("garage","%d_%s"%[car,part])) if part in PARTS else 0

func stars(index:int) -> int:
	return mini(3,number("events","stars_%d"%index))

func total_stars() -> int:
	var total:=0
	for i in range(EVENT_COUNT):total+=stars(i)
	return total

func completed() -> int:
	var total:=0
	for i in range(EVENT_COUNT):
		if stars(i)>0:total+=1
	return total

func unlocked(index:int) -> bool:
	return index>=0 and index<EVENT_COUNT and total_stars()>=CUP_GATES[int(index/6)]

func recommended_event() -> int:
	for i in range(EVENT_COUNT):
		if unlocked(i) and stars(i)==0:return i
	for i in range(EVENT_COUNT):
		if unlocked(i) and stars(i)<3:return i
	return EVENT_COUNT-1

func buy_car(index:int) -> Dictionary:
	if index<0 or index>=Catalog.CARS.size():return failure("车辆不存在")
	if owned(index):return failure("已拥有这辆车")
	var cost:int=CAR_PRICES[index]
	if credits()<cost:return failure("金币不足，参加赛事可以赚取奖励")
	var balance:=credits()-cost
	var ok:bool=store.transaction(func():
		store.config.set_value("career","credits",balance)
		store.config.set_value("garage","owned_%d"%index,true))
	return {"ok":true,"cost":cost} if ok else failure("存档写入失败，本次购买未扣款")

func upgrade(car:int,part:String) -> Dictionary:
	if not owned(car) or not part in PARTS:return failure("请先解锁车辆")
	var current:=level(car,part)
	if current>=3:return failure("已升至最高等级")
	var cost:int=UPGRADE_PRICES[current]
	if credits()<cost:return failure("金币不足，参加赛事可以赚取奖励")
	var balance:=credits()-cost
	var ok:bool=store.transaction(func():
		store.config.set_value("career","credits",balance)
		store.config.set_value("garage","%d_%s"%[car,part],current+1))
	return {"ok":true,"cost":cost} if ok else failure("存档写入失败，本次升级未扣款")

func specification(car:int) -> Dictionary:
	return tuned(Catalog.CARS[car],level(car,"engine"),level(car,"tires"),level(car,"brakes"))

static func tuned(base:Dictionary,engine:int,tires:int,brakes:int) -> Dictionary:
	var spec:=base.duplicate(true)
	spec.top*=1.0+.035*engine
	spec.accel*=1.0+.06*engine
	spec.grip*=1.0+.045*tires
	spec.radius*=1.0-.025*tires
	spec.brake*=1.0+.08*brakes
	return spec

func record_variant(car:int,reversed:bool) -> String:
	return "_%s_%d%d%d"%["reverse" if reversed else "forward",level(car,"engine"),level(car,"tires"),level(car,"brakes")]

func begin_event(index:int,car:int) -> Dictionary:
	if not unlocked(index):return failure("尚未解锁此杯赛")
	if not owned(car):return failure("请先解锁车辆")
	var serial:=number("career","serial")+1
	var token:="%d-%d-%d"%[serial,index,Time.get_ticks_usec()]
	var active:={"token":token,"event":index,"car":car}
	var ok:bool=store.transaction(func():
		store.config.set_value("career","schema",SCHEMA)
		store.config.set_value("career","serial",serial)
		store.config.set_value("career","active",active))
	return {"ok":true,"token":token,"event":event(index)} if ok else failure("无法保存赛事进度，请检查存储空间")

# Only the currently active race can settle; consumed tickets cannot grant rewards twice.
func finish_event(token:String,place:int,seconds:float,laps:int,valid_run:bool=true) -> Dictionary:
	var active=store.config.get_value("career","active",{})
	if not active is Dictionary or active.get("token","")!=token or token.is_empty():return failure("赛事已结算或不存在")
	var index:=int(active.get("event",-1))
	var definition:=event(index)
	if definition.is_empty() or not is_finite(seconds) or seconds<=0 or laps<int(definition.laps) or place<1 or place>6:
		return failure("比赛尚未完成")
	var earned:=3 if place==1 else (2 if place<=3 else 1)
	if definition.mode=="trial":earned=3 if seconds<=definition.gold else (2 if seconds<=definition.gold*1.22 else 1)
	if definition.mode=="trial" and not valid_run:earned=1
	var previous:=stars(index)
	var improvement:=maxi(0,earned-previous)
	var participation:float=int(definition.reward)*([1.0,.8,.65,.5,.4,.35][place-1] if definition.mode=="race" else .7)
	var first_bonus:=900 if previous==0 else 0
	var amount:=int(participation)+first_bonus+improvement*200
	var total:=credits()+amount
	var best=store.config.get_value("event_times_compact_v8","best_%d"%index,INF)
	var best_seconds:=float(best) if best is float or best is int else INF
	var receipt:={"ok":true,"event":index,"stars":earned,"improved":improvement,"reward":amount,"first_bonus":first_bonus,"balance":total}
	var ok:bool=store.transaction(func():
		store.config.set_value("career","credits",total)
		store.config.set_value("career","races",number("career","races")+1)
		store.config.set_value("career","active",{})
		store.config.set_value("career","last_receipt",receipt)
		store.config.set_value("events","stars_%d"%index,maxi(previous,earned))
		store.config.set_value("event_times_compact_v8","best_%d"%index,minf(best_seconds,seconds)))
	return receipt if ok else failure("奖励未能保存，请重试；金币尚未入账")

static func failure(message:String) -> Dictionary:
	return {"ok":false,"message":message}
