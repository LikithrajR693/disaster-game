extends Node

# Campaign Manager for READY OR NOT: THE LAST 10 MINUTES
# Tracks campaign state, mission scoring, NDMA knowledge evaluations, settings, and reports.

signal mission_completed_signal(mission_id: int, report: Dictionary)
signal settings_changed

var mission_id: int = 0
var completed: Array[bool] = [false, false, false]
var unlocked: Array[bool] = [true, false, false] # Unlocks sequentially
var reports: Dictionary = {}

# Settings State
var sound_enabled: bool = true:
	set(val):
		sound_enabled = val
		SoundManager.sound_enabled = val
		settings_changed.emit()
var sfx_volume: float = 0.8: # 0.0 to 1.0
	set(val):
		sfx_volume = clampf(val, 0.0, 1.0)
		SoundManager.set_master_volume(sfx_volume)
		settings_changed.emit()
var screen_shake_enabled: bool = true: # Full or Reduced
	set(val):
		screen_shake_enabled = val
		settings_changed.emit()

var tactical_scan_active: bool = false
var modal_active: bool = false

const MISSION_METADATA: Array[Dictionary] = [
	{
		"id": 0,
		"act": "ACT 1",
		"title": "THE GROUND REMEMBERS",
		"disaster": "RICHTER 6.8 EARTHQUAKE",
		"location": "Aaranya Vidyalaya & Main Avenue",
		"subtitle": "Sudden ground rupture in Aaranya Town. Protect immediately with Drop-Cover-Hold, then assess structural hazards.",
		"target_safe_zone": "Town Ground (Open Sky Assembly Area)",
		"time_limit": 600,
		"required_residents": 2,
		"required_hazards": 3,
		"color": Color("#E8C66A")
	},
	{
		"id": 1,
		"act": "ACT 2",
		"title": "THE RISING LINE",
		"disaster": "FLASH FLOOD & LIVE WIRES",
		"location": "Health Clinic & Low-Lying Roads",
		"subtitle": "Canal breach and flash flood warning. Avoid submerged roads and guide vulnerable residents to high ground.",
		"target_safe_zone": "Elevated Community Hall Shelter (Plinth Level +2.5m)",
		"time_limit": 600,
		"required_residents": 2,
		"required_hazards": 3,
		"color": Color("#4BA3E3")
	},
	{
		"id": 2,
		"act": "ACT 3",
		"title": "THE LAST EXIT",
		"disaster": "RESIDENTIAL TOWER INFERNO",
		"location": "Ward 4 Residential Complex",
		"subtitle": "Fire outbreak in Aaranya Residential Tower. Sound the alarm, avoid elevators & smoke, evacuate via stairs.",
		"target_safe_zone": "External Fire Assembly Perimeter (50m clear zone)",
		"time_limit": 600,
		"required_residents": 2,
		"required_hazards": 3,
		"color": Color("#E0533C")
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset_campaign() -> void:
	mission_id = 0
	completed = [false, false, false]
	unlocked = [true, false, false]
	reports.clear()

func unlock_next_mission(current_id: int) -> void:
	if current_id + 1 < unlocked.size():
		unlocked[current_id + 1] = true

func record_report(id: int, report: Dictionary) -> void:
	reports[id] = report
	if report.get("passed", false):
		completed[id] = true
		unlock_next_mission(id)
	mission_completed_signal.emit(id, report)

func get_campaign_summary() -> Dictionary:
	var total_hazards := 0
	var total_residents := 0
	var total_score := 0
	var missions_cleared := 0
	
	for i in range(3):
		if reports.has(i):
			var rep: Dictionary = reports[i]
			if rep.get("passed", false):
				missions_cleared += 1
			total_hazards += rep.get("hazards", 0)
			total_residents += rep.get("residents", 0)
			total_score += rep.get("score", 0)
			
	var grade := "INCOMPLETE"
	if missions_cleared == 3:
		if total_score >= 2700:
			grade = "S — MASTER EMERGENCY COORDINATOR (NDMA COMMENDED)"
		elif total_score >= 2100:
			grade = "A — CERTIFIED DISASTER RESPONDER"
		elif total_score >= 1500:
			grade = "B — QUALIFIED COMMUNITY VOLUNTEER"
		else:
			grade = "C — BASIC AWARENESS CERTIFIED"
			
	return {
		"missions_cleared": missions_cleared,
		"total_hazards": total_hazards,
		"total_residents": total_residents,
		"total_score": total_score,
		"grade": grade,
		"all_cleared": (missions_cleared == 3)
	}
