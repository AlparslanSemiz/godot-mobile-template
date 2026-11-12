extends SceneTree
## Finishes the AdMob plugin's iOS export when run from the command line.
## The plugin links its Swift package (GoogleMobileAds + UMP, see builds/ios/admob_spm)
## into project.pbxproj in a deferred call, which never runs because a CLI export
## quits first. This runs the plugin's own patcher on the exported project.
## Usage: godot --headless --path . --script res://tools/ios_post_export.gd -- builds/ios/game.xcodeproj

const PbxprojService: GDScript = preload("res://addons/admob/internal/services/pbxproj_service.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("ios_post_export: pass the .xcodeproj path")
		quit(1)
		return
	var xcodeproj: String = ProjectSettings.globalize_path("res://" + args[0])
	var pbxproj: String = xcodeproj.path_join("project.pbxproj")
	var spm_package: String = xcodeproj.get_base_dir().path_join("admob_spm/Package.swift")
	if not FileAccess.file_exists(pbxproj) or not FileAccess.file_exists(spm_package):
		printerr("ios_post_export: missing %s or %s" % [pbxproj, spm_package])
		quit(1)
		return
	if FileAccess.get_file_as_string(pbxproj).contains("admob_spm"):
		print("ios_post_export: already linked")
	else:
		PbxprojService.call("patch", pbxproj)
	var linked: bool = FileAccess.get_file_as_string(pbxproj).contains("XCLocalSwiftPackageReference \"admob_spm\"")
	print("ios_post_export: admob_spm linked=%s" % linked)
	quit(0 if linked else 1)
