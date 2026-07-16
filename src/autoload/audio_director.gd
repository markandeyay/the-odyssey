extends Node
## Music beds, ambience, ducking (ARCHITECTURE §19). M1 skeleton: the API
## surface only. Playback arrives when WORLD provides audio assets. Music is
## rare by design (§16) — wind, fire, surf, and dripping carry the island.

func play_music(_stream: AudioStream, _fade_in: float = 2.0) -> void:
	pass


func stop_music(_fade_out: float = 2.0) -> void:
	pass


func play_ambience(_stream: AudioStream, _fade_in: float = 1.0) -> void:
	pass


func stop_ambience(_fade_out: float = 1.0) -> void:
	pass


func duck(_amount_db: float, _duration: float) -> void:
	pass
